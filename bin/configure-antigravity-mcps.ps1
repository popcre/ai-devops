<#
.SYNOPSIS
  Reconcile the repo-owned MCP server set into Google Antigravity's global MCP
  config (~/.gemini/config/mcp_config.json, key mcpServers).

.DESCRIPTION
  Antigravity's MCP schema (qualified 2026-11-21 from agy-customizations
  mcp_servers.md) uses:
    Local (Stdio):
      command  : string executable path or command name (required)
      args     : optional array of argument strings
      env      : optional map of environment variables
    Remote (Streamable HTTP):
      url      : string HTTP(S) endpoint URL (required)
      headers  : optional map of HTTP headers

  Managed names that are no longer selected are removed; foreign user entries
  and any other top-level keys are preserved untouched. Writes atomically with
  a timestamped .aidevops.<stamp>.bak backup, is idempotent (byte-identical
  re-runs write nothing), and is safe to re-run.

  Called by bin/setup-machine.ps1; testable standalone via -Servers/-ManagedNames.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [System.Collections.IDictionary]$Servers,
  # Every name this toolkit may manage in the mcpServers map. Selected names are
  # (re)written; managed names NOT selected are removed; anything else stays.
  [string[]]$ManagedNames = @($Servers.Keys),
  [string]$ConfigPath = (Join-Path $env:USERPROFILE ".gemini\config\mcp_config.json")
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot 'windows-json-file.ps1')

$canonicalLocalKeys  = @('command', 'args', 'env')
$canonicalRemoteKeys = @('url', 'headers')

function ConvertTo-AntigravityMcpEntry([string]$Name, [System.Collections.IDictionary]$Server) {
  $isRemote = $Server.Contains('url')
  $isLocal  = $Server.Contains('command')

  if ($isRemote -and $isLocal) {
    throw "Server '$Name' specifies both 'command' and 'url'; choose one transport."
  }
  if (-not $isRemote -and -not $isLocal) {
    throw "Server '$Name' must specify either 'command' (stdio) or 'url' (Streamable HTTP)."
  }

  $allowed = if ($isRemote) { $canonicalRemoteKeys } else { $canonicalLocalKeys }
  foreach ($unknown in $Server.Keys) {
    if ($allowed -notcontains [string]$unknown) {
      throw ("Server '$Name' carries key '$unknown', which is not in Antigravity's canonical MCP " +
             "schema. Transform the entry at the call site instead.")
    }
  }

  $entry = [ordered]@{}
  if ($isLocal) {
    $cmd = $Server['command']
    if (-not ($cmd -is [string]) -or [string]::IsNullOrWhiteSpace($cmd)) {
      throw "Server '$Name': Antigravity MCP 'command' must be a non-empty string."
    }
    $entry['command'] = [string]$cmd
    if ($Server.Contains('args')) {
      $rawArgs = $Server['args']
      if ($rawArgs -is [string]) {
        $entry['args'] = @([string]$rawArgs)
      } elseif ($rawArgs -is [System.Collections.IEnumerable]) {
        $entry['args'] = @($rawArgs | ForEach-Object { [string]$_ })
      } else {
        throw "Server '$Name': Antigravity MCP 'args' must be an array of strings."
      }
    }
    if ($Server.Contains('env')) {
      $envMap = [ordered]@{}
      foreach ($k in $Server['env'].Keys) { $envMap[[string]$k] = [string]$Server['env'][$k] }
      $entry['env'] = $envMap
    }
  } else {
    $url = $Server['url']
    if (-not ($url -is [string]) -or [string]::IsNullOrWhiteSpace($url)) {
      throw "Server '$Name': Antigravity MCP 'url' must be a non-empty string."
    }
    $entry['url'] = [string]$url
    if ($Server.Contains('headers')) {
      $h = [ordered]@{}
      foreach ($k in $Server['headers'].Keys) { $h[[string]$k] = [string]$Server['headers'][$k] }
      $entry['headers'] = $h
    }
  }
  return $entry
}

$result = Update-AiDevOpsJsonFileAtomic -Path $ConfigPath -Depth 12 -Update {
  param($config)
  if (-not $config.ContainsKey('mcpServers')) { $config['mcpServers'] = @{} }
  if (-not ($config['mcpServers'] -is [System.Collections.IDictionary])) {
    throw "config 'mcpServers' key exists but is not an object; refusing to touch it."
  }
  foreach ($name in $ManagedNames) {
    if (-not $Servers.Contains($name)) { $null = $config['mcpServers'].Remove($name) }
  }
  foreach ($name in $Servers.Keys) {
    $config['mcpServers'][[string]$name] = ConvertTo-AntigravityMcpEntry ([string]$name) $Servers[$name]
  }
}

if ($result.Changed) {
  $names = ($Servers.Keys | Sort-Object) -join ', '
  if (-not $names) { $names = '(none)' }
  Write-Host "Updated Antigravity MCP config ($ConfigPath): $names"
} else {
  Write-Host "Antigravity MCP config already up to date ($ConfigPath)."
}
