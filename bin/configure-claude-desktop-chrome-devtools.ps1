<#
.SYNOPSIS
  Add Chrome DevTools MCP to Claude Desktop without replacing other extensions.

.DESCRIPTION
  Finds the Store/MSIX or standard Claude Desktop config, creates a recoverable
  backup, and merges only the chrome-devtools MCP entry. Existing MCP servers
  and unrelated Claude settings are preserved.
#>
[CmdletBinding()]
param(
  [string]$ConfigPath = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
  $msix = Join-Path $env:LOCALAPPDATA "Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\claude_desktop_config.json"
  $standard = Join-Path $env:APPDATA "Claude\claude_desktop_config.json"
  if (Test-Path -LiteralPath (Split-Path -Parent $msix)) {
    $ConfigPath = $msix
  } elseif (Test-Path -LiteralPath (Split-Path -Parent $standard)) {
    $ConfigPath = $standard
  } else {
    throw "Claude Desktop config folder not found. Start Claude Desktop once, then rerun."
  }
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $ConfigPath) | Out-Null
$config = @{}
if (Test-Path -LiteralPath $ConfigPath) {
  try {
    $config = Get-Content -Raw -LiteralPath $ConfigPath | ConvertFrom-Json -AsHashtable
  } catch {
    throw "Claude Desktop config is not valid JSON; leaving it unchanged: $ConfigPath"
  }
  Copy-Item -LiteralPath $ConfigPath -Destination "$ConfigPath.aidevops.bak" -Force
}
if (-not $config.ContainsKey("mcpServers")) { $config["mcpServers"] = @{} }
$config["mcpServers"]["chrome-devtools"] = @{
  command = "cmd"
  args = @("/c", "npx", "-y", "chrome-devtools-mcp@1.7.0")
}
($config | ConvertTo-Json -Depth 12) | Set-Content -LiteralPath $ConfigPath -Encoding utf8

Write-Host "ok Claude Desktop Chrome DevTools MCP configured (backup: $ConfigPath.aidevops.bak)" -ForegroundColor Green
Write-Host "Fully quit and reopen Claude Desktop before testing the connection."
