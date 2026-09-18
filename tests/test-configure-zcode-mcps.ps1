$ErrorActionPreference = "Stop"
$passed = 0
$failed = 0

function Assert-True([bool]$Condition, [string]$Message) {
  if ($Condition) { Write-Host "  ok   $Message"; $script:passed++ }
  else { Write-Host "  FAIL $Message"; $script:failed++ }
}

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$scriptPath = Join-Path $repoRoot "bin\configure-zcode-mcps.ps1"
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("zcode-mcps-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $testRoot | Out-Null

$onepassword = [ordered]@{
  command = 'cmd'
  args = @('/c', 'C:\Users\u\.config\ai-devops\mcp-launch.cmd', 'cmd', '/c', 'npx', '-y', 'onepassword-mcp')
}
$codexcli = [ordered]@{
  command = 'C:\Users\u\.codex\bin\codex.exe'
  args = @('mcp-server')
  env = [ordered]@{ MCP_TOOL_TIMEOUT = '3600000' }
  timeoutMs = 3600000
}

try {
  # -- 1. Fresh write into a nonexistent config (ZCode ships without one) ----
  $configPath = Join-Path $testRoot "fresh\config.json"
  & $scriptPath -Servers ([ordered]@{ '1password' = $onepassword }) -ConfigPath $configPath | Out-Null
  $cfg = Get-Content -Raw -LiteralPath $configPath | ConvertFrom-Json -AsHashtable
  Assert-True (Test-Path -LiteralPath $configPath) "fresh config created"
  Assert-True ($cfg['mcp']['servers'].ContainsKey('1password')) "1password written under mcp.servers"
  Assert-True ($cfg['mcp']['servers']['1password']['command'] -is [string]) "command is a string (strict schema)"
  Assert-True ($cfg['mcp']['servers']['1password']['timeoutMs'] -eq 120000) "explicit default timeoutMs stamped"
  Assert-True (-not $cfg['mcp']['servers']['1password'].ContainsKey('startup_timeout_sec')) "no foreign (TOML-era) keys emitted"

  # -- 2. Foreign server preserved, existing managed entry updated, hooks
  #       block untouched ----------------------------------------------------
  $configPath2 = Join-Path $testRoot "existing\config.json"
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $configPath2) | Out-Null
  @'
{
  "plugins": { "enabledPlugins": { "computer-use@zcode-plugins-official": true } },
  "hooks": { "enabled": true, "events": { "Stop": [ { "hooks": [ { "type": "command", "command": "bash user-hook", "timeoutMs": 30000 } ] } ] } },
  "mcp": { "servers": {
    "my-own-server": { "command": "my-exe", "args": ["--x"], "timeoutMs": 5000 },
    "1password": { "command": "STALE", "args": ["/c"], "timeoutMs": 1000 }
  } }
}
'@ | Set-Content -LiteralPath $configPath2 -Encoding utf8
  & $scriptPath -Servers ([ordered]@{ '1password' = $onepassword }) -ConfigPath $configPath2 | Out-Null
  $cfg2 = Get-Content -Raw -LiteralPath $configPath2 | ConvertFrom-Json -AsHashtable
  Assert-True ($cfg2['mcp']['servers'].ContainsKey('my-own-server')) "foreign user server preserved"
  Assert-True ($cfg2['mcp']['servers']['1password']['command'] -eq 'cmd') "stale managed entry rewritten"
  Assert-True ($cfg2['plugins']['enabledPlugins'].ContainsKey('computer-use@zcode-plugins-official')) "plugins block preserved"
  Assert-True ($cfg2['hooks']['enabled'] -eq $true) "existing hooks block preserved untouched"
  $backup = Get-ChildItem -LiteralPath (Split-Path -Parent $configPath2) -Filter "config.json.aidevops.*.bak" | Select-Object -First 1
  Assert-True ($null -ne $backup) "timestamped backup created before the changed write"

  # -- 3. Idempotence: a second identical run changes nothing -----------------
  $before = Get-Content -Raw -LiteralPath $configPath2
  & $scriptPath -Servers ([ordered]@{ '1password' = $onepassword }) -ConfigPath $configPath2 | Out-Null
  Assert-True ((Get-Content -Raw -LiteralPath $configPath2) -ceq $before) "second run is a byte-identical no-op"

  # -- 4. Retired managed entry removed, foreign kept -------------------------
  $configPath4 = Join-Path $testRoot "retire\config.json"
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $configPath4) | Out-Null
  @'
{ "mcp": { "servers": {
    "1password": { "command": "cmd", "args": [], "timeoutMs": 1000 },
    "codex-cli": { "command": "codex", "args": ["mcp-server"], "timeoutMs": 1000 },
    "my-own-server": { "command": "my-exe", "args": [], "timeoutMs": 1000 } } } }
'@ | Set-Content -LiteralPath $configPath4 -Encoding utf8
  & $scriptPath -Servers ([ordered]@{ '1password' = $onepassword }) -ManagedNames @('1password','codex-cli') -ConfigPath $configPath4 | Out-Null
  $cfg4 = Get-Content -Raw -LiteralPath $configPath4 | ConvertFrom-Json -AsHashtable
  Assert-True (-not $cfg4['mcp']['servers'].ContainsKey('codex-cli')) "retired managed entry removed"
  Assert-True ($cfg4['mcp']['servers'].ContainsKey('my-own-server')) "foreign server survives retirement sweep"
  Assert-True ($cfg4['mcp']['servers'].ContainsKey('1password')) "selected managed entry kept"

  # -- 5. Unknown key refused by construction ---------------------------------
  $threw = $false
  try {
    & $scriptPath -Servers ([ordered]@{ bad = [ordered]@{ command = 'x'; startup_timeout_sec = 20 } }) `
        -ConfigPath (Join-Path $testRoot "never\config.json") | Out-Null
  } catch { $threw = $true }
  Assert-True $threw "unknown MCP key (startup_timeout_sec) refused before any write"
  Assert-True (-not (Test-Path -LiteralPath (Join-Path $testRoot "never"))) "refusal wrote no file"

  # -- 6. Array command refused (Claude/OpenCode shape must not leak in) ------
  $threw2 = $false
  try {
    & $scriptPath -Servers ([ordered]@{ bad = [ordered]@{ command = @('cmd','/c') } }) `
        -ConfigPath (Join-Path $testRoot "never2\config.json") | Out-Null
  } catch { $threw2 = $true }
  Assert-True $threw2 "array-valued command refused (ZCode requires a string)"

  # -- 7. env + explicit timeoutMs pass through canonically -------------------
  $configPath7 = Join-Path $testRoot "env\config.json"
  & $scriptPath -Servers ([ordered]@{ 'codex-cli' = $codexcli }) -ConfigPath $configPath7 | Out-Null
  $cfg7 = Get-Content -Raw -LiteralPath $configPath7 | ConvertFrom-Json -AsHashtable
  Assert-True ($cfg7['mcp']['servers']['codex-cli']['env']['MCP_TOOL_TIMEOUT'] -eq '3600000') "env map written canonically"
  Assert-True ($cfg7['mcp']['servers']['codex-cli']['timeoutMs'] -eq 3600000) "explicit timeoutMs honored over default"
}
finally {
  Remove-Item -Recurse -Force $testRoot -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "$passed passed, $failed failed"
exit $(if ($failed -eq 0) { 0 } else { 1 })
