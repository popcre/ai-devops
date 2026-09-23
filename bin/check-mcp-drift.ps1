<#
.SYNOPSIS
  Fail when an installed Claude MCP server set differs from declared membership.

.DESCRIPTION
  Declared membership is read from the literal lists in setup-machine.ps1
  ($ClaudeDesktopMcpNames, $ClaudeCodeMcpNames), so there is no second copy.
  Installed sets come from every Claude Desktop config copy that exists and the
  global mcpServers in ~/.claude.json. Exit 0 when every set matches, 1 on drift.
  Read-only. See #703 for the drift this catches.
#>
[CmdletBinding()]
param(
  [string]$SetupScript = (Join-Path $PSScriptRoot "setup-machine.ps1"),
  [string[]]$DesktopConfigPaths = @(
    (Join-Path $env:LOCALAPPDATA "Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\claude_desktop_config.json"),
    (Join-Path $env:APPDATA "Claude\claude_desktop_config.json")),
  [string]$ClaudeCodeConfigPath = (Join-Path $env:USERPROFILE ".claude.json")
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Get-DeclaredNames([string]$Variable) {
  $text = Get-Content -Raw -LiteralPath $SetupScript
  $m = [regex]::Match($text, '(?m)^\$' + $Variable + '\s*=\s*@\(([^)]*)\)')
  if (-not $m.Success) { throw "Could not find `$$Variable in $SetupScript" }
  return @([regex]::Matches($m.Groups[1].Value, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object)
}

function Get-InstalledNames([string]$Path) {
  $cfg = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -AsHashtable
  if (-not $cfg.ContainsKey("mcpServers") -or $null -eq $cfg["mcpServers"]) { return @() }
  return @($cfg["mcpServers"].Keys | Sort-Object)
}

$drift = 0
function Compare-Set([string]$Label, [string[]]$Declared, [string[]]$Installed) {
  $extra = @($Installed | Where-Object { $Declared -notcontains $_ })
  $missing = @($Declared | Where-Object { $Installed -notcontains $_ })
  if ($extra.Count -or $missing.Count) {
    $script:drift++
    Write-Host "DRIFT $Label"
    if ($extra.Count) { Write-Host "  installed but not declared: $($extra -join ', ')" }
    if ($missing.Count) { Write-Host "  declared but not installed: $($missing -join ', ')" }
  } else {
    Write-Host "ok    $Label ($($Installed -join ', '))"
  }
}

$desktopDeclared = Get-DeclaredNames "ClaudeDesktopMcpNames"
$codeDeclared = Get-DeclaredNames "ClaudeCodeMcpNames"

$seen = 0
foreach ($path in $DesktopConfigPaths) {
  if (Test-Path -LiteralPath $path) {
    $seen++
    Compare-Set "Claude Desktop: $path" $desktopDeclared (Get-InstalledNames $path)
  }
}
if ($seen -eq 0) { Write-Host "skip  Claude Desktop: no config file found" }
if (Test-Path -LiteralPath $ClaudeCodeConfigPath) {
  Compare-Set "Claude Code: $ClaudeCodeConfigPath" $codeDeclared (Get-InstalledNames $ClaudeCodeConfigPath)
} else {
  Write-Host "skip  Claude Code: $ClaudeCodeConfigPath not found"
}

if ($drift) { Write-Host "FAIL: $drift installed MCP set(s) differ from declared membership"; exit 1 }
Write-Host "PASS: installed MCP sets match declared membership"
exit 0
