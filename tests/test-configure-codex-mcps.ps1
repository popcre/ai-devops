$ErrorActionPreference = "Stop"
$passed = 0
$failed = 0

function Assert-True([bool]$Condition, [string]$Message) {
  if ($Condition) { Write-Host "  ok   $Message"; $script:passed++ }
  else { Write-Host "  FAIL $Message"; $script:failed++ }
}

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$scriptPath = Join-Path $repoRoot "bin\configure-codex-mcps.ps1"
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-mcps-" + [guid]::NewGuid().ToString("N"))
$configPath = Join-Path $testRoot "config.toml"
New-Item -ItemType Directory -Force -Path $testRoot | Out-Null

$names = @('ag-grid','playwright','codex-cli','synology-monitor','devops-mcp','vercel','railway','trigger','recall-ai','1password','supabase','chrome-devtools')
$servers = [ordered]@{}
foreach ($name in $names) {
  $servers[$name] = [ordered]@{ command = 'cmd'; args = @('/c', 'npx', '-y', "package-$name") }
}
$servers['vercel'] = [ordered]@{ url = 'https://mcp.vercel.com'; startup_timeout_sec = 20 }
$servers['railway'] = [ordered]@{ url = 'https://mcp.railway.com'; startup_timeout_sec = 20 }
$servers['codex-cli']['env'] = [ordered]@{ MCP_TOOL_TIMEOUT = '3600000' }
$servers['codex-cli']['tool_timeout_sec'] = 3600

try {
  @'
model_reasoning_effort = "low"

[mcp_servers.keep-me]
command = "keep-command"

[mcp_servers."1password"]
command = "old-command"
args = ["old"]

[mcp_servers."1password".env]
OP_SERVICE_ACCOUNT_TOKEN = "SHOULD_NOT_SURVIVE"

[mcp_servers."1password".tools.item_get]
approval_mode = "approve"

[mcp_servers.trigger.tools.run]
approval_mode = "approve"

[mcp_servers.chrome-devtools]
command = "old-chrome"

[desktop]
notifications = true
'@ | Set-Content -LiteralPath $configPath -Encoding utf8

  & $scriptPath -Servers $servers -ConfigPath $configPath | Out-Null
  $first = Get-Content -Raw -LiteralPath $configPath
  & $scriptPath -Servers $servers -ConfigPath $configPath | Out-Null
  $second = Get-Content -Raw -LiteralPath $configPath

  foreach ($name in $names) {
    $pattern = ('\[mcp_servers\."{0}"\]' -f [regex]::Escape($name))
    Assert-True (([regex]::Matches($second, $pattern)).Count -eq 1) "one $name block"
  }
  Assert-True ($first -eq $second) "second run is byte-identical"
  Assert-True ($second.Contains('[mcp_servers.keep-me]')) "preserves unrelated MCP servers"
  Assert-True ($second.Contains('[mcp_servers."1password".tools.item_get]')) "preserves tool approval guards"
  Assert-True ($second.IndexOf('[mcp_servers."trigger"]') -lt $second.IndexOf('[mcp_servers.trigger.tools.run]')) "writes a missing parent before its tool guards"
  Assert-True ($second.Contains('[desktop]')) "preserves machine-local Codex settings"
  Assert-True (-not $second.Contains('SHOULD_NOT_SURVIVE')) "removes stale plaintext env values"
  Assert-True ($second.Contains("url = 'https://mcp.vercel.com'")) "uses native Vercel transport"
  Assert-True ($second.Contains("url = 'https://mcp.railway.com'")) "uses native Railway transport"
  Assert-True ($second.Contains('tool_timeout_sec = 3600')) "allows long codex-cli calls"
  Assert-True ((Get-ChildItem $testRoot -Filter 'config.toml.aidevops-*.bak').Count -eq 1) "creates one recoverable backup only when changed"
} finally {
  $resolvedTestRoot = [System.IO.Path]::GetFullPath($testRoot)
  $resolvedTemp = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
  if ($resolvedTestRoot.StartsWith($resolvedTemp, [System.StringComparison]::OrdinalIgnoreCase) -and
      (Split-Path -Leaf $resolvedTestRoot).StartsWith("codex-mcps-")) {
    Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force -ErrorAction SilentlyContinue
  } else {
    throw "Refusing to remove unexpected test path: $resolvedTestRoot"
  }
}

Write-Host ""
Write-Host "$passed passed, $failed failed"
if ($failed -gt 0) { exit 1 }
