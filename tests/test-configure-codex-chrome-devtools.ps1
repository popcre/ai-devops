$ErrorActionPreference = "Stop"
$passed = 0
$failed = 0

function Assert-True([bool]$Condition, [string]$Message) {
  if ($Condition) {
    Write-Host "  ok   $Message"
    $script:passed++
  } else {
    Write-Host "  FAIL $Message"
    $script:failed++
  }
}

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$scriptPath = Join-Path $repoRoot "bin\configure-codex-chrome-devtools.ps1"
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-chrome-mcp-" + [guid]::NewGuid().ToString("N"))
$configPath = Join-Path $testRoot "config.toml"
New-Item -ItemType Directory -Force -Path $testRoot | Out-Null

try {
  @'
model_reasoning_effort = "medium"

[mcp_servers.keep-me]
command = "keep-command"

[mcp_servers.chrome-devtools]
command = "old-command"
args = ["old"]

[mcp_servers.chrome-devtools.tools.screenshot]
approval_mode = "approve"

[desktop]
notifications = true
'@ | Set-Content -LiteralPath $configPath -Encoding utf8

  & $scriptPath -ConfigPath $configPath | Out-Null
  & $scriptPath -ConfigPath $configPath | Out-Null

  $content = Get-Content -Raw -LiteralPath $configPath
  Assert-True (([regex]::Matches($content, '\[mcp_servers\.chrome-devtools\]')).Count -eq 1) "one Chrome DevTools block after repeated runs"
  Assert-True ($content.Contains('chrome-devtools-mcp@latest')) "uses the current Chrome DevTools MCP package"
  Assert-True ($content.Contains('startup_timeout_ms = 20000')) "allows Chrome enough startup time on Windows"
  Assert-True ($content.Contains('[mcp_servers.keep-me]')) "preserves unrelated MCP servers"
  Assert-True ($content.Contains('[mcp_servers.chrome-devtools.tools.screenshot]')) "preserves tool approval guards"
  Assert-True ($content.Contains('[desktop]')) "preserves machine-local Codex settings"
  Assert-True ((Test-Path -LiteralPath "$configPath.aidevops.bak")) "creates a recoverable backup"
} finally {
  $resolvedTestRoot = [System.IO.Path]::GetFullPath($testRoot)
  $resolvedTemp = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
  if ($resolvedTestRoot.StartsWith($resolvedTemp, [System.StringComparison]::OrdinalIgnoreCase) -and
      (Split-Path -Leaf $resolvedTestRoot).StartsWith("codex-chrome-mcp-")) {
    Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force -ErrorAction SilentlyContinue
  } else {
    throw "Refusing to remove unexpected test path: $resolvedTestRoot"
  }
}

Write-Host ""
Write-Host "$passed passed, $failed failed"
if ($failed -gt 0) { exit 1 }
