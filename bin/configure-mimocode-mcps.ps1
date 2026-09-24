<#
.SYNOPSIS
  Reconcile the repo-owned MCP server set into MiMoCode's user config
  (~/.config/mimocode/mimocode.jsonc, key mcp).

.DESCRIPTION
  MiMoCode's MCP schema (live-qualified 2026-09-23 on edge-dev against
  ~/.config/mimocode/mimocode.jsonc) uses:
    type     : "local" | "remote"
    command  : ARRAY of argv strings (NOT a string + args like ZCode)
    env      : optional map
    enabled  : optional bool
    timeout  : optional int milliseconds (NOT ZCode's timeoutMs)
  Remote servers use type/url/headers instead of command.

  Managed names that are no longer selected are removed; foreign user entries
  and every other config key (instructions, permission, plugin, provider,
  skills, ...) are preserved untouched. Writes atomically with a timestamped
  .aidevops.<stamp>.bak backup, is idempotent (byte-identical re-runs write
  nothing), and is safe to re-run.

  Also ensures the `instructions` list references the seeded
  ~/.config/mimocode/AGENTS.md when that file exists (never deletes a user
  entry; only appends a missing one).

  JSONC NOTE: the atomic writer parses and emits pure JSON. `//` comments in
  an existing mimocode.jsonc are NOT preserved. A backup is taken first.

  Called by bin/setup-machine.ps1; testable standalone via -Servers/-ManagedNames.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [System.Collections.IDictionary]$Servers,
  # Every name this toolkit may manage in the mcp map. Selected names are
  # (re)written; managed names NOT selected are removed; anything else stays.
  [string[]]$ManagedNames = @($Servers.Keys),
  [string]$ConfigPath = (Join-Path $env:USERPROFILE ".config\mimocode\mimocode.jsonc"),
  [string]$InstructionsPath = (Join-Path $env:USERPROFILE ".config\mimocode\AGENTS.md"),
  [int]$DefaultTimeoutMs = 120000
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot 'windows-json-file.ps1')

# Canonical MiMoCode local/remote MCP keys only (schema facts: live
# mimocode.jsonc + mimocode-docs config.md, qualified 2026-09-23).
$canonicalLocalKeys = @('type', 'command', 'env', 'enabled', 'timeout')
$canonicalRemoteKeys = @('type', 'url', 'headers', 'enabled', 'timeout', 'oauth')

function ConvertTo-MimoMcpEntry([string]$Name, [System.Collections.IDictionary]$Server) {
  if (-not $Server.Contains('type')) { throw "Server '$Name' has no type (local|remote)." }
  $kind = [string]$Server['type']
  $allowed = if ($kind -eq 'remote') { $canonicalRemoteKeys } else { $canonicalLocalKeys }
  foreach ($unknown in $Server.Keys) {
    if ($allowed -notcontains [string]$unknown) {
      throw ("Server '$Name' carries key '$unknown', which is not in MiMoCode's canonical MCP " +
             "schema for type '$kind'. Transform the entry at the call site instead.")
    }
  }

  $entry = [ordered]@{}
  $entry['type'] = $kind

  if ($kind -eq 'local') {
    if (-not $Server.Contains('command')) { throw "Server '$Name' has no command." }
    $cmd = $Server['command']
    if ($cmd -is [string]) {
      $entry['command'] = @([string]$cmd)
    } elseif ($cmd -is [System.Collections.IEnumerable]) {
      $entry['command'] = @($cmd | ForEach-Object { [string]$_ })
    } else {
      throw ("Server '$Name': MiMoCode's MCP 'command' must be a string or an array of strings.")
    }
  } elseif ($kind -eq 'remote') {
    if (-not $Server.Contains('url')) { throw "Server '$Name' (remote) has no url." }
    $entry['url'] = [string]$Server['url']
    if ($Server.Contains('headers')) {
      $h = [ordered]@{}
      foreach ($k in $Server['headers'].Keys) { $h[[string]$k] = [string]$Server['headers'][$k] }
      $entry['headers'] = $h
    }
  } else {
    throw "Server '$Name': unknown type '$kind' (accepted: local, remote)."
  }

  if ($Server.Contains('env')) {
    $envMap = [ordered]@{}
    foreach ($k in $Server['env'].Keys) { $envMap[[string]$k] = [string]$Server['env'][$k] }
    $entry['env'] = $envMap
  }
  if ($Server.Contains('enabled')) { $entry['enabled'] = [bool]$Server['enabled'] }
  # Explicit on every entry: the 1Password launcher cold start needs headroom.
  $entry['timeout'] = if ($Server.Contains('timeout')) { [int]$Server['timeout'] } else { $DefaultTimeoutMs }
  return $entry
}

$result = Update-AiDevOpsJsonFileAtomic -Path $ConfigPath -Depth 12 -Update {
  param($config)
  if (-not $config.ContainsKey('mcp')) { $config['mcp'] = @{} }
  if (-not $config['mcp'] -is [System.Collections.IDictionary]) {
    throw "config 'mcp' key exists but is not an object; refusing to touch it."
  }
  # Retire managed names that are no longer selected. Foreign names are never
  # removed, whatever their shape.
  foreach ($name in $ManagedNames) {
    if (-not $Servers.Contains($name)) { $null = $config['mcp'].Remove($name) }
  }
  foreach ($name in $Servers.Keys) {
    $config['mcp'][[string]$name] = ConvertTo-MimoMcpEntry ([string]$name) $Servers[$name]
  }

  # Ensure the seeded globals file is referenced when it exists. Append-only.
  if ((Test-Path -LiteralPath $InstructionsPath) -and $InstructionsPath) {
    if (-not $config.ContainsKey('instructions')) { $config['instructions'] = @() }
    $list = @($config['instructions'])
    if ($list -notcontains $InstructionsPath) {
      $list += $InstructionsPath
      $config['instructions'] = $list
    }
  }
  return $config
}

if ($result.Changed) {
  Write-Host "ok MiMoCode MCP servers configured: $($Servers.Keys -join ', ')" -ForegroundColor Green
  if ($result.Backup) {
    Write-Host "   protected prior config: $($result.Backup)"
    Write-Host "   recovery: Copy-Item -LiteralPath '$($result.Backup)' -Destination '$ConfigPath' -Force"
  }
} else {
  Write-Host "ok MiMoCode MCP server set already current: $($Servers.Keys -join ', ')" -ForegroundColor Green
}
