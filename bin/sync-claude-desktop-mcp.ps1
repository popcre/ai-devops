<#
.SYNOPSIS
  Make Claude Desktop's MCP server list match declared membership.

.DESCRIPTION
  Reads the desired state written by setup-machine.ps1 (a JSON file with
  "servers" = name -> definition and "managed" = every catalog name) and applies
  it to claude_desktop_config.json: managed names outside "servers" are removed,
  declared servers are written, and names the catalog does not know are left in
  place and reported.

  Why this is its own script (#703): a running Claude Desktop keeps the whole
  file in memory and writes it back when it saves a preference. Setup pruned the
  file on 2026-09-04 and 2026-09-18, and within minutes the app restored the old
  ten-server list each time. So nothing is written while the app is running.
  With -WaitForDesktopExit the script waits for the app to quit and then applies;
  without it, it exits 3 ("deferred") and writes nothing.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$ConfigPath,
  [Parameter(Mandatory)][string]$DesiredPath,
  [switch]$WaitForDesktopExit,
  [int]$WaitTimeoutMinutes = 4320,
  # Tests only: "running" or "stopped" instead of looking at real processes.
  [ValidateSet("", "running", "stopped")][string]$DesktopStateOverride = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "windows-json-file.ps1")

function Test-ClaudeDesktopRunning {
  if ($DesktopStateOverride) { return ($DesktopStateOverride -eq "running") }
  # The desktop app is Claude.exe from the Store package (WindowsApps\Claude_*)
  # or the standard install (AnthropicClaude). claude.exe under claude-code is
  # the CLI and does not own this file.
  $apps = @(Get-Process -Name claude -ErrorAction SilentlyContinue | Where-Object {
    $p = $null; try { $p = $_.Path } catch {}
    $p -and ($p -like "*\WindowsApps\Claude_*" -or $p -like "*\AnthropicClaude\*")
  })
  return ($apps.Count -gt 0)
}

$desired = Get-Content -Raw -LiteralPath $DesiredPath | ConvertFrom-Json -AsHashtable
$servers = $desired["servers"]
$managed = @($desired["managed"])

if (Test-ClaudeDesktopRunning) {
  if (-not $WaitForDesktopExit) {
    Write-Host "[DEFERRED] Claude Desktop is running; it would overwrite this change. Nothing written."
    exit 3
  }
  Write-Host "Waiting for Claude Desktop to quit before updating $ConfigPath ..."
  $deadline = (Get-Date).AddMinutes($WaitTimeoutMinutes)
  while (Test-ClaudeDesktopRunning) {
    if ((Get-Date) -gt $deadline) { Write-Host "[FAIL] Claude Desktop still running after $WaitTimeoutMinutes minutes; nothing written."; exit 1 }
    Start-Sleep -Seconds 15
  }
}

$script:removed = @()
$script:unmanaged = @()
$result = Update-AiDevOpsJsonFileAtomic -Path $ConfigPath -Depth 12 -Update {
  param($cfg)
  if (-not $cfg.ContainsKey("mcpServers")) { $cfg["mcpServers"] = @{} }
  foreach ($name in @($cfg["mcpServers"].Keys)) {
    if ($managed -contains $name) {
      if (-not $servers.ContainsKey($name)) { $null = $cfg["mcpServers"].Remove($name); $script:removed += $name }
    } elseif ($name -eq "vercel") {
      # Retired from Claude; see setup-machine.ps1 (browser re-auth loop).
      $null = $cfg["mcpServers"].Remove($name); $script:removed += $name
    } elseif (-not $servers.ContainsKey($name)) {
      $script:unmanaged += $name
    }
  }
  foreach ($name in $servers.Keys) { $cfg["mcpServers"][$name] = $servers[$name] }
  return $cfg
}

Write-Host "ok Claude Desktop MCP set: $((@($servers.Keys) | Sort-Object) -join ', ')"
if ($script:removed) { Write-Host "ok removed undeclared: $((@($script:removed) | Sort-Object) -join ', ')" }
foreach ($name in $script:unmanaged) { Write-Host "[WARN] left unmanaged server in place (not in the catalog): $name" }
if ($result.Backup) {
  Write-Host "ok protected prior JSON: $($result.Backup)"
  Write-Host "   recovery: Copy-Item -LiteralPath '$($result.Backup)' -Destination '$ConfigPath' -Force"
}
exit 0
