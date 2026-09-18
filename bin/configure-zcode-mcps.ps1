<#
.SYNOPSIS
  Reconcile the repo-owned MCP server set into ZCode's user config
  (~/.zcode/cli/config.json, key mcp.servers).

.DESCRIPTION
  ZCode's MCP schema is STRICT: one unknown key inside a server entry silently
  drops the whole server, and config-file servers get no ${...} expansion, so
  every entry is CONSTRUCTED here from an allowlist of canonical keys — never
  copied wholesale from another client's shape (command must be a string, not
  an array). Managed names that are no longer selected are removed; foreign
  user entries and every other config key (hooks, plugins, skills) are
  preserved untouched. Writes atomically with a timestamped .aidevops.<stamp>.bak
  backup, is idempotent (byte-identical re-runs write nothing), and is safe to
  re-run. This writer never touches the hooks block — hook registration has its
  own installer.

  Called by bin/setup-machine.ps1; testable standalone via -Servers/-ManagedNames.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [System.Collections.IDictionary]$Servers,
  # Every name this toolkit may manage in this file. Selected names are
  # (re)written; managed names NOT selected are removed; anything else stays.
  [string[]]$ManagedNames = @($Servers.Keys),
  [string]$ConfigPath = (Join-Path $env:USERPROFILE ".zcode\cli\config.json"),
  [int]$DefaultTimeoutMs = 120000
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot 'windows-json-file.ps1')

# Canonical ZCode stdio-server keys only (schema facts: zcode-guide plugin,
# qualified 2026-09-17 — see tests/verification/zcode-windows-2026-09-17/).
$canonicalKeys = @('command', 'args', 'cwd', 'env', 'enabled', 'timeoutMs')

function ConvertTo-ZCodeMcpEntry([string]$Name, [System.Collections.IDictionary]$Server) {
  $entry = [ordered]@{}
  foreach ($unknown in $Server.Keys) {
    if ($canonicalKeys -notcontains [string]$unknown) {
      throw ("Server '$Name' carries key '$unknown', which is not in ZCode's canonical MCP " +
             "schema. One unknown key silently drops the whole server, so the writer refuses " +
             "to emit it. Transform the entry at the call site instead.")
    }
  }
  if (-not $Server.Contains('command')) { throw "Server '$Name' has no command." }
  if ($Server['command'] -isnot [string]) {
    throw ("Server '$Name': ZCode's MCP 'command' must be a STRING (an exe), not an array. " +
           "Wrap launcher arguments in 'args' with a cmd /c prefix if needed.")
  }
  $entry['command'] = [string]$Server['command']
  if ($Server.Contains('args')) {
    $entry['args'] = @($Server['args'] | ForEach-Object { [string]$_ })
  }
  foreach ($key in @('cwd')) {
    if ($Server.Contains($key)) { $entry[$key] = [string]$Server[$key] }
  }
  if ($Server.Contains('env')) {
    $envMap = [ordered]@{}
    foreach ($k in $Server['env'].Keys) { $envMap[[string]$k] = [string]$Server['env'][$k] }
    $entry['env'] = $envMap
  }
  if ($Server.Contains('enabled')) { $entry['enabled'] = [bool]$Server['enabled'] }
  # Explicit on every entry: ZCode's 30000 ms default is too low for the
  # 1Password-launcher cold start.
  $entry['timeoutMs'] = if ($Server.Contains('timeoutMs')) { [int]$Server['timeoutMs'] } else { $DefaultTimeoutMs }
  return $entry
}

$result = Update-AiDevOpsJsonFileAtomic -Path $ConfigPath -Depth 12 -Update {
  param($config)
  if (-not $config.ContainsKey('mcp')) { $config['mcp'] = @{} }
  if (-not $config['mcp'] -is [System.Collections.IDictionary]) {
    throw "config 'mcp' key exists but is not an object; refusing to touch it."
  }
  if (-not $config['mcp'].ContainsKey('servers')) { $config['mcp']['servers'] = @{} }
  if (-not $config['mcp']['servers'] -is [System.Collections.IDictionary]) {
    throw "config 'mcp.servers' exists but is not an object; refusing to touch it."
  }
  # Retire managed names that are no longer selected. Foreign names are never
  # removed, whatever their shape.
  foreach ($name in $ManagedNames) {
    if (-not $Servers.Contains($name)) { $null = $config['mcp']['servers'].Remove($name) }
  }
  foreach ($name in $Servers.Keys) {
    $config['mcp']['servers'][[string]$name] = ConvertTo-ZcodeMcpEntry ([string]$name) $Servers[$name]
  }
  return $config
}

if ($result.Changed) {
  Write-Host "ok ZCode MCP servers configured: $($Servers.Keys -join ', ')" -ForegroundColor Green
  if ($result.Backup) {
    Write-Host "   protected prior config: $($result.Backup)"
    Write-Host "   recovery: Copy-Item -LiteralPath '$($result.Backup)' -Destination '$ConfigPath' -Force"
  }
} else {
  Write-Host "ok ZCode MCP server set already current: $($Servers.Keys -join ', ')" -ForegroundColor Green
}
