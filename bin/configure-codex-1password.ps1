<#
.SYNOPSIS
  Route Codex's 1Password MCP through the shared ai-devops caching launcher.

.DESCRIPTION
  Codex reads its own ~/.codex/config.toml, which setup-machine.ps1 does NOT
  otherwise manage. Left alone, its [mcp_servers."1password"] block spawns the
  MCP server with a DIRECT `npx` command and an inline plaintext service-account
  token — which means:
    1. The token sits in cleartext in config.toml (a file secret), and
    2. Codex's 1Password server is OUTSIDE the shared single-flight refresh +
       15-minute DPAPI cache that mcp-secret-launch.ps1 gives every other
       surface, so it authenticates the service account independently and can
       contribute to the per-hour rate-limit "storm" that locked the account.

  This script rewrites ONLY the 1password block to launch through
  mcp-launch.cmd (same path Claude Desktop and Claude Code use), so Codex shares
  the one cache and carries NO token in the config. It:
    - Rewrites [mcp_servers."1password"] command/args to go via the launcher.
    - DELETES [mcp_servers."1password".env] entirely (removes the plaintext token).
    - PRESERVES every [mcp_servers."1password".tools.*] approval guard.
    - Leaves all other Codex servers and top-level config untouched.

  Idempotent: running it again produces the same clean block.

.NOTES
  Called by bin/setup-machine.ps1 so the fix persists to every machine that runs
  the bootstrap. Safe to run standalone.
#>
[CmdletBinding()]
param(
  # The stdio MCP launcher (…\.config\ai-devops\mcp-launch.cmd). Defaulted from $HOME.
  [string]$Launcher = (Join-Path $HOME ".config\ai-devops\mcp-launch.cmd"),
  # Codex config file.
  [string]$ConfigPath = (Join-Path $HOME ".codex\config.toml")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ConfigPath)) {
  Write-Host "[skip] No Codex config at $ConfigPath — Codex not installed here." -ForegroundColor Yellow
  return
}
if (-not (Test-Path -LiteralPath $Launcher)) {
  throw "Launcher not found: $Launcher (run setup-machine.ps1 first so the caching launcher exists)."
}

# The clean, token-free 1password block. Single-quoted TOML literal strings so the
# Windows backslashes in the launcher path need no escaping. Mirrors exactly how
# Claude Desktop/Code invoke it: cmd /c <launcher> cmd /c npx -y @u2giants/1password-mcp.
$newBlock = @(
  '[mcp_servers."1password"]'
  'command = "cmd"'
  ("args = ['/c', '{0}', 'cmd', '/c', 'npx', '-y', '@u2giants/1password-mcp']" -f $Launcher)
)

$lines = Get-Content -LiteralPath $ConfigPath

# Segment the file by TOML table headers, preserving any top-of-file preamble.
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

# Rebuild. Drop the .env subtable; rewrite the main block; keep everything else
# (including .tools.* approval guards) verbatim and in order.
$out = New-Object System.Collections.Generic.List[string]
$sawMain = $false
foreach ($seg in $segments) {
  $h = $seg.Header
  if ($null -eq $h) {
    # top-of-file preamble
    foreach ($b in $seg.Body) { $out.Add($b) | Out-Null }
    continue
  }
  if ($h -eq '[mcp_servers."1password".env]') {
    continue  # remove plaintext token table entirely
  }
  if ($h -eq '[mcp_servers."1password"]') {
    $sawMain = $true
    foreach ($nb in $newBlock) { $out.Add($nb) | Out-Null }
    $out.Add('') | Out-Null
    continue
  }
  $out.Add($h) | Out-Null
  foreach ($b in $seg.Body) { $out.Add($b) | Out-Null }
}

# If Codex had no 1password block at all, append a fresh one plus the standard
# approval guards on the sensitive tools.
if (-not $sawMain) {
  $out.Add('') | Out-Null
  foreach ($nb in $newBlock) { $out.Add($nb) | Out-Null }
  $out.Add('') | Out-Null
  foreach ($tool in @('item_lookup','password_read','item_get','op_run')) {
    $out.Add(('[mcp_servers."1password".tools.{0}]' -f $tool)) | Out-Null
    $out.Add('approval_mode = "approve"') | Out-Null
    $out.Add('') | Out-Null
  }
}

# Back up once, then write.
$backup = "$ConfigPath.aidevops.bak"
if (-not (Test-Path -LiteralPath $backup)) { Copy-Item -LiteralPath $ConfigPath $backup -Force }
# Collapse any accidental multiple blank lines to at most one.
$text = ($out -join "`n") -replace "(`n){3,}", "`n`n"
Set-Content -LiteralPath $ConfigPath -Value $text -Encoding utf8

Write-Host "ok Codex 1password MCP routed through $Launcher (plaintext token removed; tools guards preserved)" -ForegroundColor Green
