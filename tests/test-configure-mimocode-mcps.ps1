$ErrorActionPreference = "Stop"
$passed = 0
$failed = 0

function Assert-True([bool]$Condition, [string]$Message) {
  if ($Condition) { Write-Host "  ok   $Message"; $script:passed++ }
  else { Write-Host "  FAIL $Message"; $script:failed++ }
}

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$scriptPath = Join-Path $repoRoot "bin\configure-mimocode-mcps.ps1"
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("mimocode-mcps-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $testRoot | Out-Null

$onepassword = [ordered]@{
  type = 'local'
  command = @('cmd', '/c', 'C:\Users\u\.config\ai-devops\mcp-launch.cmd', 'cmd', '/c', 'onepassword-mcp.cmd')
  enabled = $true
}

try {
  # -- 1. Fresh write into a nonexistent config ------------------------------
  $configPath = Join-Path $testRoot "fresh\mimocode.jsonc"
  & $scriptPath -Servers ([ordered]@{ '1password' = $onepassword }) -ConfigPath $configPath | Out-Null
  $cfg = Get-Content -Raw -LiteralPath $configPath | ConvertFrom-Json -AsHashtable
  Assert-True (Test-Path -LiteralPath $configPath) "fresh config created"
  Assert-True ($cfg['mcp'].ContainsKey('1password')) "1password written under mcp"
  Assert-True ($cfg['mcp']['1password']['command'] -is [System.Collections.IList]) "command is an array (MiMo schema)"
  Assert-True ($cfg['mcp']['1password']['command'][0] -eq 'cmd') "command argv preserved"
  Assert-True ($cfg['mcp']['1password']['timeout'] -eq 120000) "explicit default timeout stamped"
  Assert-True ($cfg['mcp']['1password']['type'] -eq 'local') "type local stamped"
  Assert-True (-not $cfg['mcp']['1password'].ContainsKey('timeoutMs')) "no ZCode timeoutMs key emitted"

  # -- 2. Foreign server preserved, managed updated, other keys untouched ----
  $configPath2 = Join-Path $testRoot "existing\mimocode.jsonc"
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $configPath2) | Out-Null
  @'
{
  "model": "xiaomi/mimo-v2.5",
  "permission": { "bash": { "*": "ask" } },
  "mcp": {
    "my-own-server": { "type": "local", "command": ["my-exe", "--x"], "timeout": 5000 },
    "1password": { "type": "local", "command": ["STALE"], "timeout": 1000 }
  }
}
'@ | Set-Content -LiteralPath $configPath2 -Encoding utf8
  & $scriptPath -Servers ([ordered]@{ '1password' = $onepassword }) -ConfigPath $configPath2 | Out-Null
  $cfg2 = Get-Content -Raw -LiteralPath $configPath2 | ConvertFrom-Json -AsHashtable
  Assert-True ($cfg2['mcp'].ContainsKey('my-own-server')) "foreign user server preserved"
  Assert-True ($cfg2['mcp']['1password']['command'][0] -eq 'cmd') "stale managed entry rewritten"
  Assert-True ($cfg2['model'] -eq 'xiaomi/mimo-v2.5') "model key preserved"
  Assert-True ($cfg2['permission']['bash']['*'] -eq 'ask') "permission block preserved"
  $backup = Get-ChildItem -LiteralPath (Split-Path -Parent $configPath2) -Filter "mimocode.jsonc.aidevops.*.bak" | Select-Object -First 1
  Assert-True ($null -ne $backup) "timestamped backup created before the changed write"

  # -- 3. Idempotence --------------------------------------------------------
  $before = Get-Content -Raw -LiteralPath $configPath2
  & $scriptPath -Servers ([ordered]@{ '1password' = $onepassword }) -ConfigPath $configPath2 | Out-Null
  Assert-True ((Get-Content -Raw -LiteralPath $configPath2) -ceq $before) "second run is a byte-identical no-op"

  # -- 4. Retired managed entry removed, foreign kept ------------------------
  $configPath4 = Join-Path $testRoot "retire\mimocode.jsonc"
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $configPath4) | Out-Null
  @'
{ "mcp": {
    "1password": { "type": "local", "command": ["cmd"], "timeout": 1000 },
    "legacy": { "type": "local", "command": ["x"], "timeout": 1000 },
    "my-own-server": { "type": "local", "command": ["my-exe"], "timeout": 1000 } } }
'@ | Set-Content -LiteralPath $configPath4 -Encoding utf8
  & $scriptPath -Servers ([ordered]@{ '1password' = $onepassword }) -ManagedNames @('1password','legacy') -ConfigPath $configPath4 | Out-Null
  $cfg4 = Get-Content -Raw -LiteralPath $configPath4 | ConvertFrom-Json -AsHashtable
  Assert-True (-not $cfg4['mcp'].ContainsKey('legacy')) "retired managed entry removed"
  Assert-True ($cfg4['mcp'].ContainsKey('my-own-server')) "foreign server survives retirement sweep"
  Assert-True ($cfg4['mcp'].ContainsKey('1password')) "selected managed entry kept"

  # -- 5. Unknown key refused ------------------------------------------------
  $threw = $false
  try {
    & $scriptPath -Servers ([ordered]@{ '1password' = [ordered]@{ type='local'; command=@('cmd'); timeoutMs=1 } }) -ConfigPath (Join-Path $testRoot "bad\mimocode.jsonc") | Out-Null
  } catch { $threw = $true }
  Assert-True $threw "unknown key timeoutMs (ZCode shape) refused"

  # -- 6. String command accepted and normalized to array --------------------
  $configPath6 = Join-Path $testRoot "stringcmd\mimocode.jsonc"
  & $scriptPath -Servers ([ordered]@{ '1password' = [ordered]@{ type='local'; command='cmd' } }) -ConfigPath $configPath6 | Out-Null
  $cfg6 = Get-Content -Raw -LiteralPath $configPath6 | ConvertFrom-Json -AsHashtable
  Assert-True ($cfg6['mcp']['1password']['command'] -is [System.Collections.IList]) "string command normalized to array"
  Assert-True (@($cfg6['mcp']['1password']['command']).Count -eq 1) "normalized array has one element"

  # -- 7. instructions ensure (append-only) ----------------------------------
  $instructions = Join-Path $testRoot "AGENTS.md"
  Set-Content -LiteralPath $instructions -Value "globals"
  $configPath7 = Join-Path $testRoot "instr\mimocode.jsonc"
  & $scriptPath -Servers ([ordered]@{ '1password' = $onepassword }) -ConfigPath $configPath7 -InstructionsPath $instructions | Out-Null
  $cfg7 = Get-Content -Raw -LiteralPath $configPath7 | ConvertFrom-Json -AsHashtable
  Assert-True (@($cfg7['instructions']) -contains $instructions) "instructions references seeded AGENTS.md"
  & $scriptPath -Servers ([ordered]@{ '1password' = $onepassword }) -ConfigPath $configPath7 -InstructionsPath $instructions | Out-Null
  $cfg7b = Get-Content -Raw -LiteralPath $configPath7 | ConvertFrom-Json -AsHashtable
  Assert-True ((@($cfg7b['instructions']).Count) -eq 1) "instructions not duplicated on re-run"

  # -- 8. remote type accepted -----------------------------------------------
  $configPath8 = Join-Path $testRoot "remote\mimocode.jsonc"
  & $scriptPath -Servers ([ordered]@{ rail = [ordered]@{ type='remote'; url='https://mcp.railway.com' } }) -ConfigPath $configPath8 -InstructionsPath '' | Out-Null
  $cfg8 = Get-Content -Raw -LiteralPath $configPath8 | ConvertFrom-Json -AsHashtable
  Assert-True ($cfg8['mcp']['rail']['type'] -eq 'remote') "remote type written"
  Assert-True ($cfg8['mcp']['rail']['url'] -eq 'https://mcp.railway.com') "remote url written"
}
finally {
  if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}

Write-Host ""
Write-Host "$passed passed, $failed failed"
if ($failed -gt 0) { exit 1 }
exit 0
