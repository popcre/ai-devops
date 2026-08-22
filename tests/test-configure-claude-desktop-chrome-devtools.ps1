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
$scriptPath = Join-Path $repoRoot "bin\configure-claude-desktop-chrome-devtools.ps1"
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("claude-chrome-mcp-" + [guid]::NewGuid().ToString("N"))
$configPath = Join-Path $testRoot "claude_desktop_config.json"
New-Item -ItemType Directory -Force -Path $testRoot | Out-Null

try {
  @'
{
  "theme": "dark",
  "mcpServers": {
    "keep-me": { "command": "keep-command", "args": ["keep"] },
    "chrome-devtools": { "command": "old-command", "args": ["old"] }
  }
}
'@ | Set-Content -LiteralPath $configPath -Encoding utf8

  & $scriptPath -ConfigPath $configPath | Out-Null
  & $scriptPath -ConfigPath $configPath | Out-Null
  $config = Get-Content -Raw -LiteralPath $configPath | ConvertFrom-Json -AsHashtable

  Assert-True ($config["theme"] -eq "dark") "preserves unrelated Claude settings"
  Assert-True ($config["mcpServers"].ContainsKey("keep-me")) "preserves other MCP servers"
  Assert-True ($config["mcpServers"]["chrome-devtools"]["args"] -contains "chrome-devtools-mcp@1.7.0") "configures the pinned Chrome DevTools package"
  Assert-True ($config["mcpServers"].Keys.Where({ $_ -eq "chrome-devtools" }).Count -eq 1) "keeps one Chrome DevTools entry"
  Assert-True ((Test-Path -LiteralPath "$configPath.aidevops.bak")) "creates a recoverable backup"
} finally {
  $resolvedTestRoot = [System.IO.Path]::GetFullPath($testRoot)
  $resolvedTemp = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
  if ($resolvedTestRoot.StartsWith($resolvedTemp, [System.StringComparison]::OrdinalIgnoreCase) -and
      (Split-Path -Leaf $resolvedTestRoot).StartsWith("claude-chrome-mcp-")) {
    Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force -ErrorAction SilentlyContinue
  } else {
    throw "Refusing to remove unexpected test path: $resolvedTestRoot"
  }
}

Write-Host ""
Write-Host "$passed passed, $failed failed"
if ($failed -gt 0) { exit 1 }
