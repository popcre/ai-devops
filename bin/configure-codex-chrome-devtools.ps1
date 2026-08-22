<#
.SYNOPSIS
  Add Chrome DevTools MCP to Codex without replacing machine-local settings.

.DESCRIPTION
  Codex stores machine-specific paths, plugins, trust entries, and preferences
  in ~/.codex/config.toml. This script rewrites or appends only the
  [mcp_servers.chrome-devtools] table and preserves everything else. It keeps a
  one-time backup and is safe to run repeatedly.
#>
[CmdletBinding()]
param(
  [string]$ConfigPath = (Join-Path $env:USERPROFILE ".codex\config.toml")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ConfigPath)) {
  Write-Host "[skip] No Codex config at $ConfigPath - Codex not installed here." -ForegroundColor Yellow
  return
}

$systemRoot = if ($env:SystemRoot) { $env:SystemRoot } else { "C:\Windows" }
$programFiles = if ($env:ProgramFiles) { $env:ProgramFiles } else { "C:\Program Files" }
$newBlock = @(
  '[mcp_servers.chrome-devtools]'
  'command = "cmd"'
  'args = ["/c", "npx", "-y", "chrome-devtools-mcp@1.7.0"]'
  ("env = {{ SystemRoot = '{0}', PROGRAMFILES = '{1}' }}" -f $systemRoot, $programFiles)
  'startup_timeout_sec = 20'
)

$lines = Get-Content -LiteralPath $ConfigPath
$segments = New-Object System.Collections.Generic.List[object]
$current = [ordered]@{ Header = $null; Body = (New-Object System.Collections.Generic.List[string]) }
foreach ($line in $lines) {
  if ($line -match '^\s*\[') {
    $segments.Add([pscustomobject]$current) | Out-Null
    $current = [ordered]@{ Header = $line.Trim(); Body = (New-Object System.Collections.Generic.List[string]) }
  } else {
    $current.Body.Add($line)
  }
}
$segments.Add([pscustomobject]$current) | Out-Null

$out = New-Object System.Collections.Generic.List[string]
$sawMain = $false
foreach ($segment in $segments) {
  if ($null -eq $segment.Header) {
    foreach ($bodyLine in $segment.Body) { $out.Add($bodyLine) | Out-Null }
    continue
  }
  if ($segment.Header -eq '[mcp_servers.chrome-devtools]') {
    $sawMain = $true
    foreach ($newLine in $newBlock) { $out.Add($newLine) | Out-Null }
    $out.Add('') | Out-Null
    continue
  }
  $out.Add($segment.Header) | Out-Null
  foreach ($bodyLine in $segment.Body) { $out.Add($bodyLine) | Out-Null }
}

if (-not $sawMain) {
  $out.Add('') | Out-Null
  foreach ($newLine in $newBlock) { $out.Add($newLine) | Out-Null }
  $out.Add('') | Out-Null
}

$backup = "$ConfigPath.aidevops.bak"
if (-not (Test-Path -LiteralPath $backup)) {
  Copy-Item -LiteralPath $ConfigPath -Destination $backup -Force
}
$text = ($out -join "`n") -replace "(`n){3,}", "`n`n"
Set-Content -LiteralPath $ConfigPath -Value $text -Encoding utf8

Write-Host "ok Codex Chrome DevTools MCP configured (existing Codex settings preserved)" -ForegroundColor Green
