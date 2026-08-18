<#
.SYNOPSIS
  Reconcile the complete repo-owned MCP server set into Codex config.toml.

.DESCRIPTION
  Rewrites only the main table for each supplied MCP server, removes stale
  per-server env subtables, preserves tool approval guards and unrelated Codex
  settings, and appends missing servers. Creates a timestamped backup before a
  changed file is written. Safe to run repeatedly.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [System.Collections.IDictionary]$Servers,
  [string]$ConfigPath = (Join-Path $env:USERPROFILE ".codex\config.toml")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ConfigPath)) {
  Write-Host "[skip] No Codex config at $ConfigPath - Codex not installed here." -ForegroundColor Yellow
  return
}

function ConvertTo-TomlLiteral([string]$Value) {
  if ($Value.Contains("'")) { throw "Cannot safely write a TOML literal containing a single quote." }
  return "'$Value'"
}

function ConvertTo-TomlArray($Values) {
  $items = @($Values | ForEach-Object { ConvertTo-TomlLiteral -Value ([string]$_) })
  return '[' + ($items -join ', ') + ']'
}

function Get-McpHeaderName([string]$Header) {
  $match = [regex]::Match($Header, '^\[mcp_servers\.(?:"([^"]+)"|([A-Za-z0-9_-]+))\]$')
  if (-not $match.Success) { return $null }
  if ($match.Groups[1].Success) { return $match.Groups[1].Value }
  return $match.Groups[2].Value
}

function Get-McpSubtableName([string]$Header) {
  $match = [regex]::Match($Header, '^\[mcp_servers\.(?:"([^"]+)"|([A-Za-z0-9_-]+))\..+\]$')
  if (-not $match.Success) { return $null }
  if ($match.Groups[1].Success) { return $match.Groups[1].Value }
  return $match.Groups[2].Value
}

function Test-McpEnvHeader([string]$Header, [string]$Name) {
  $quoted = ('[mcp_servers."{0}".env]' -f $Name)
  $bare = ('[mcp_servers.{0}.env]' -f $Name)
  return ($Header -eq $quoted -or $Header -eq $bare)
}

function New-McpBlock([string]$Name, [System.Collections.IDictionary]$Server) {
  $block = New-Object System.Collections.Generic.List[string]
  $block.Add(('[mcp_servers."{0}"]' -f $Name)) | Out-Null
  foreach ($key in @('command','url','bearer_token_env_var','cwd')) {
    if ($Server.Contains($key)) {
      $block.Add(('{0} = {1}' -f $key, (ConvertTo-TomlLiteral -Value ([string]$Server[$key])))) | Out-Null
    }
  }
  if ($Server.Contains('args')) {
    $block.Add(('args = {0}' -f (ConvertTo-TomlArray $Server['args']))) | Out-Null
  }
  if ($Server.Contains('env')) {
    $pairs = @()
    foreach ($envKey in $Server['env'].Keys) {
      $pairs += ('{0} = {1}' -f $envKey, (ConvertTo-TomlLiteral -Value ([string]$Server['env'][$envKey])))
    }
    $block.Add(('env = {{ {0} }}' -f ($pairs -join ', '))) | Out-Null
  }
  foreach ($key in @('startup_timeout_sec','tool_timeout_sec')) {
    if ($Server.Contains($key)) { $block.Add(('{0} = {1}' -f $key, [int]$Server[$key])) | Out-Null }
  }
  foreach ($key in @('enabled','required')) {
    if ($Server.Contains($key)) {
      $value = if ([bool]$Server[$key]) { 'true' } else { 'false' }
      $block.Add(('{0} = {1}' -f $key, $value)) | Out-Null
    }
  }
  return $block
}

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
$written = @{}
foreach ($segment in $segments) {
  if ($null -eq $segment.Header) {
    foreach ($bodyLine in $segment.Body) { $out.Add($bodyLine) | Out-Null }
    continue
  }

  $managedName = Get-McpHeaderName $segment.Header
  if ($managedName -and $Servers.Contains($managedName)) {
    if (-not $written.ContainsKey($managedName)) {
      foreach ($newLine in (New-McpBlock $managedName $Servers[$managedName])) { $out.Add($newLine) | Out-Null }
      $out.Add('') | Out-Null
      $written[$managedName] = $true
    }
    continue
  }

  # TOML requires a parent table before its child tables. If approval guards
  # survived but the main server block is missing, insert the main block here.
  $subtableName = Get-McpSubtableName $segment.Header
  if ($subtableName -and $Servers.Contains($subtableName) -and
      -not $written.ContainsKey($subtableName)) {
    foreach ($newLine in (New-McpBlock $subtableName $Servers[$subtableName])) { $out.Add($newLine) | Out-Null }
    $out.Add('') | Out-Null
    $written[$subtableName] = $true
  }

  $dropEnv = $false
  foreach ($name in $Servers.Keys) {
    if (Test-McpEnvHeader $segment.Header ([string]$name)) { $dropEnv = $true; break }
  }
  if ($dropEnv) { continue }

  $out.Add($segment.Header) | Out-Null
  foreach ($bodyLine in $segment.Body) { $out.Add($bodyLine) | Out-Null }
}

foreach ($name in $Servers.Keys) {
  if ($written.ContainsKey([string]$name)) { continue }
  $out.Add('') | Out-Null
  foreach ($newLine in (New-McpBlock ([string]$name) $Servers[$name])) { $out.Add($newLine) | Out-Null }
  $out.Add('') | Out-Null
}

$newText = (($out -join "`n") -replace "(`n){3,}", "`n`n").TrimEnd() + "`n"
$oldText = Get-Content -Raw -LiteralPath $ConfigPath
if ($oldText -eq $newText) {
  Write-Host "ok Codex MCP server set already current: $($Servers.Keys -join ', ')" -ForegroundColor Green
  return
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backup = "$ConfigPath.aidevops-$stamp.bak"
Copy-Item -LiteralPath $ConfigPath -Destination $backup -Force
Set-Content -LiteralPath $ConfigPath -Value $newText -Encoding utf8 -NoNewline
Write-Host "ok Codex MCP server set configured: $($Servers.Keys -join ', ')" -ForegroundColor Green
Write-Host "   backup: $backup"
