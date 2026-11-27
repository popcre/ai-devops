<#
.SYNOPSIS
  Deliver project-scoped MCP servers into each owning repository (#705, #2916).

.DESCRIPTION
  For every (repository key -> root) pair (including multi-repo non-git parent
  folders like dflow_plm), make the project's scoped server names available to
  sessions opened in that root, without touching anything the repository itself
  tracks:

  - Claude Code (.mcp.json): written only when absent or UNTRACKED. Managed
    catalog names outside the project's scope are removed; foreign entries are
    preserved; a timestamped backup is kept. When the repository TRACKS its own
    .mcp.json, the file is never modified; any scoped name it lacks is written
    as a Claude Code project entry in ~/.claude.json.
  - Codex (.codex/config.toml): written only when absent, or untracked and
    carrying the ai-devops marker. Arrays and tables serialize to valid TOML.
  - Antigravity (.agents/plugins/ai-devops-project-mcp/): managed workspace
    plugin with plugin.json + mcp_config.json + .ai-devops-managed marker.
  - ZCode (.zcode/config.json): strict stdio schema (mcp.servers) with
    sibling .zcode/.ai-devops-mcp-managed marker.
  - MiMoCode (.mimocode/mimocode.json): local stdio schema (mcp) with
    sibling .mimocode/.ai-devops-mcp-managed marker.

  Called by setup-machine.ps1 step 7b. Read-mostly; writes are atomic and
  backed up. -DryRun prints the plan without writing.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][System.Collections.IDictionary]$Scope,
  [Parameter(Mandatory)][System.Collections.IDictionary]$Roots,
  [Parameter(Mandatory)][System.Collections.IDictionary]$Catalog,
  [Parameter(Mandatory)][string]$ClaudeCodeConfig,
  [System.Collections.IDictionary]$CodexServers = @{},
  # Removed from the catalog but still to be deleted wherever an earlier run wrote them.
  [string[]]$RetiredNames = @(),
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Test-ManagedName([string]$Name) {
  return ($Catalog.Contains($Name) -or $RetiredNames -contains $Name)
}

function Backup-Path([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  $stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssfffZ")
  $backup = "$Path.aidevops.$stamp.bak"
  Copy-Item -LiteralPath $Path -Destination $backup -Force
  return $backup
}

function Write-Utf8NoBom([string]$Path, [string]$Text) {
  $dir = Split-Path -Parent $Path
  if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $tmp = Join-Path $dir (".aidevops-" + [guid]::NewGuid().ToString("N") + ".tmp")
  [IO.File]::WriteAllText($tmp, $Text, (New-Object System.Text.UTF8Encoding($false)))
  Move-Item -LiteralPath $tmp -Destination $Path -Force
}

function Write-JsonAtomic([string]$Path, $Value) {
  $json = ($Value | ConvertTo-Json -Depth 12) -replace "`r`n", "`n"
  if (-not $json.EndsWith("`n")) { $json += "`n" }
  Write-Utf8NoBom $Path $json
}

function Test-IsGitRoot([string]$Root) {
  return (Test-Path -LiteralPath (Join-Path $Root ".git"))
}

function Test-GitPathTracked([string]$Root, [string]$RelPath) {
  if (-not (Test-IsGitRoot $Root)) { return $false }
  git -C $Root ls-files --error-unmatch $RelPath 2>$null | Out-Null
  return ($LASTEXITCODE -eq 0)
}

function Test-McpJsonTracked([string]$Root) {
  return (Test-GitPathTracked $Root ".mcp.json")
}

function Add-GitLocalExclude([string]$Root, [string[]]$Patterns) {
  if (-not (Test-IsGitRoot $Root)) { return }
  $common = git -C $Root rev-parse --path-format=absolute --git-common-dir 2>$null
  if (-not $common) { return }
  $exclude = Join-Path $common "info\exclude"
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $exclude) | Out-Null
  $existing = if (Test-Path -LiteralPath $exclude) { @(Get-Content -LiteralPath $exclude) } else { @() }
  foreach ($pat in $Patterns) {
    $rel = $pat.Trim('/')
    git -C $Root check-ignore -q $rel 2>$null
    if ($LASTEXITCODE -eq 0) { continue }
    if ($existing -notcontains $pat) {
      Add-Content -LiteralPath $exclude -Value $pat
      $existing += $pat
    }
  }
}

function Read-JsonHashtable([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  return (Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -AsHashtable)
}

$CodexMarker = "# Managed by ai-devops bin/write-project-mcp.ps1 (#705). Rewritten by setup-machine.ps1."
$ManagedMarkerText = "Managed by ai-devops bin/write-project-mcp.ps1 (#2916). Rewritten by setup-machine.ps1.`n"

function ConvertTo-TomlValue($Value) {
  if ($Value -is [int] -or $Value -is [long]) { return [string]$Value }
  if ($Value -is [bool]) { return $(if ($Value) { "true" } else { "false" }) }
  if ($Value -is [string]) {
    $text = [string]$Value
    if (-not $text.Contains("'")) { return "'$text'" }
    return ($text | ConvertTo-Json -Compress)
  }
  if ($Value -is [System.Collections.IDictionary]) {
    $pairs = New-Object System.Collections.Generic.List[string]
    foreach ($k in ($Value.Keys | Sort-Object)) {
      $keyName = [string]$k
      $keyToml = if ($keyName -match '^[A-Za-z0-9_-]+$') { $keyName } else { $keyName | ConvertTo-Json -Compress }
      $pairs.Add(("{0} = {1}" -f $keyToml, (ConvertTo-TomlValue $Value[$k])))
    }
    return ("{{ {0} }}" -f ($pairs -join ", "))
  }
  if ($Value -is [System.Collections.IEnumerable]) {
    $items = New-Object System.Collections.Generic.List[string]
    foreach ($item in $Value) { $items.Add((ConvertTo-TomlValue $item)) }
    return ("[{0}]" -f ($items -join ", "))
  }
  $fallback = [string]$Value
  if (-not $fallback.Contains("'")) { return "'$fallback'" }
  return ($fallback | ConvertTo-Json -Compress)
}

function Write-CodexProjectConfig([string]$Root, [string[]]$Names) {
  $dir = Join-Path $Root ".codex"
  $path = Join-Path $dir "config.toml"
  if (Test-GitPathTracked $Root ".codex/config.toml") {
    Write-Host "  skip $Root .codex/config.toml is tracked; left untouched"; return
  }
  if ((Test-Path -LiteralPath $path) -and
      -not ((Get-Content -Raw -LiteralPath $path) -like "$CodexMarker*")) {
    Write-Host "  skip $Root .codex/config.toml is hand-written; left untouched"; return
  }
  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add($CodexMarker)
  $keyOrder = @('command', 'url', 'bearer_token_env_var', 'cwd', 'args', 'env', 'startup_timeout_sec', 'tool_timeout_sec', 'enabled', 'required')
  foreach ($name in $Names) {
    $lines.Add("")
    $lines.Add(('[mcp_servers."{0}"]' -f $name))
    $srv = $CodexServers[$name]
    $orderedKeys = New-Object System.Collections.Generic.List[string]
    foreach ($k in $keyOrder) {
      if ($srv.Contains($k)) { $orderedKeys.Add($k) }
    }
    foreach ($k in ($srv.Keys | Sort-Object)) {
      if ($keyOrder -notcontains [string]$k) { $orderedKeys.Add([string]$k) }
    }
    foreach ($k in $orderedKeys) {
      $lines.Add(("{0} = {1}" -f $k, (ConvertTo-TomlValue $srv[$k])))
    }
  }
  $text = ($lines -join "`n") + "`n"
  $existingText = if (Test-Path -LiteralPath $path) { (Get-Content -Raw -LiteralPath $path) -replace "`r`n", "`n" } else { $null }
  if ($existingText -eq $text) {
    Write-Host "  ok   $Root .codex/config.toml already carries $($Names -join ', ')"
  } elseif ($DryRun) {
    Write-Host "  plan $Root .codex/config.toml: $($Names -join ',')"; return
  } else {
    Write-Utf8NoBom $path $text
    Write-Host "  ok   $Root .codex/config.toml: $($Names -join ', ')"
  }
  if (-not $DryRun) {
    Add-GitLocalExclude $Root @("/.codex/config.toml")
  }
}

function Write-AntigravityProjectPlugin([string]$Root, [string[]]$Names) {
  $pluginDir = Join-Path $Root ".agents\plugins\ai-devops-project-mcp"
  $pluginJsonPath = Join-Path $pluginDir "plugin.json"
  $mcpJsonPath = Join-Path $pluginDir "mcp_config.json"
  $markerPath = Join-Path $pluginDir ".ai-devops-managed"
  if ((Test-GitPathTracked $Root ".agents/plugins/ai-devops-project-mcp/plugin.json") -or
      (Test-GitPathTracked $Root ".agents/plugins/ai-devops-project-mcp/mcp_config.json")) {
    Write-Host "  skip $Root .agents/plugins/ai-devops-project-mcp is tracked; left untouched"; return
  }
  if ((Test-Path -LiteralPath $pluginDir) -and -not (Test-Path -LiteralPath $markerPath)) {
    Write-Host "  skip $Root .agents/plugins/ai-devops-project-mcp is hand-written; left untouched"; return
  }
  $servers = [ordered]@{}
  foreach ($name in $Names) {
    if (-not $Catalog.Contains($name)) { continue }
    $src = $Catalog[$name]
    if ($src.Contains("url")) {
      $entry = [ordered]@{ url = [string]$src["url"] }
      if ($src.Contains("headers") -and $src["headers"]) {
        $h = [ordered]@{}
        foreach ($k in ($src["headers"].Keys | Sort-Object)) { $h[[string]$k] = [string]$src["headers"][$k] }
        $entry["headers"] = $h
      }
      $servers[$name] = $entry
    } elseif ($src.Contains("command")) {
      $entry = [ordered]@{ command = [string]$src["command"] }
      if ($src.Contains("args") -and $src["args"]) {
        $entry["args"] = @($src["args"] | ForEach-Object { [string]$_ })
      }
      if ($src.Contains("env") -and $src["env"]) {
        $envMap = [ordered]@{}
        foreach ($k in ($src["env"].Keys | Sort-Object)) { $envMap[[string]$k] = [string]$src["env"][$k] }
        $entry["env"] = $envMap
      }
      $servers[$name] = $entry
    }
  }
  if ($servers.Count -eq 0) { return }
  $pluginPayload = [ordered]@{ name = "ai-devops-project-mcp"; version = "1.0.0" }
  $mcpPayload = [ordered]@{ mcpServers = $servers }
  $pluginText = (($pluginPayload | ConvertTo-Json -Depth 6) -replace "`r`n", "`n").TrimEnd() + "`n"
  $mcpText = (($mcpPayload | ConvertTo-Json -Depth 12) -replace "`r`n", "`n").TrimEnd() + "`n"
  $curPlugin = if (Test-Path -LiteralPath $pluginJsonPath) { (Get-Content -Raw -LiteralPath $pluginJsonPath) -replace "`r`n", "`n" } else { $null }
  $curMcp = if (Test-Path -LiteralPath $mcpJsonPath) { (Get-Content -Raw -LiteralPath $mcpJsonPath) -replace "`r`n", "`n" } else { $null }
  if ($curPlugin -eq $pluginText -and $curMcp -eq $mcpText -and (Test-Path -LiteralPath $markerPath)) {
    Write-Host "  ok   $Root .agents/plugins/ai-devops-project-mcp already carries $($servers.Keys -join ', ')"
  } elseif ($DryRun) {
    Write-Host "  plan $Root .agents/plugins/ai-devops-project-mcp: $($servers.Keys -join ',')"; return
  } else {
    Write-Utf8NoBom $pluginJsonPath $pluginText
    Write-Utf8NoBom $mcpJsonPath $mcpText
    Write-Utf8NoBom $markerPath $ManagedMarkerText
    Write-Host "  ok   $Root .agents/plugins/ai-devops-project-mcp: $($servers.Keys -join ', ')"
  }
  if (-not $DryRun) {
    Add-GitLocalExclude $Root @("/.agents/plugins/ai-devops-project-mcp/")
  }
}

function Write-ZCodeProjectConfig([string]$Root, [string[]]$Names) {
  $dir = Join-Path $Root ".zcode"
  $path = Join-Path $dir "config.json"
  $markerPath = Join-Path $dir ".ai-devops-mcp-managed"
  if (Test-GitPathTracked $Root ".zcode/config.json") {
    Write-Host "  skip $Root .zcode/config.json is tracked; left untouched"; return
  }
  if ((Test-Path -LiteralPath $path) -and -not (Test-Path -LiteralPath $markerPath)) {
    Write-Host "  skip $Root .zcode/config.json is hand-written; left untouched"; return
  }
  $servers = [ordered]@{}
  foreach ($name in $Names) {
    if (-not $Catalog.Contains($name)) { continue }
    $src = $Catalog[$name]
    if (-not $src.Contains("command")) { continue }
    $entry = [ordered]@{ command = [string]$src["command"] }
    if ($src.Contains("args") -and $src["args"]) {
      $entry["args"] = @($src["args"] | ForEach-Object { [string]$_ })
    }
    if ($src.Contains("cwd")) { $entry["cwd"] = [string]$src["cwd"] }
    if ($src.Contains("env") -and $src["env"]) {
      $envMap = [ordered]@{}
      foreach ($k in ($src["env"].Keys | Sort-Object)) { $envMap[[string]$k] = [string]$src["env"][$k] }
      $entry["env"] = $envMap
    }
    $entry["timeoutMs"] = 120000
    $servers[$name] = $entry
  }
  if ($servers.Count -eq 0) { return }
  $payload = [ordered]@{ mcp = [ordered]@{ servers = $servers } }
  $text = (($payload | ConvertTo-Json -Depth 12) -replace "`r`n", "`n").TrimEnd() + "`n"
  $cur = if (Test-Path -LiteralPath $path) { (Get-Content -Raw -LiteralPath $path) -replace "`r`n", "`n" } else { $null }
  if ($cur -eq $text -and (Test-Path -LiteralPath $markerPath)) {
    Write-Host "  ok   $Root .zcode/config.json already carries $($servers.Keys -join ', ')"
  } elseif ($DryRun) {
    Write-Host "  plan $Root .zcode/config.json: $($servers.Keys -join ',')"; return
  } else {
    Write-Utf8NoBom $path $text
    Write-Utf8NoBom $markerPath $ManagedMarkerText
    Write-Host "  ok   $Root .zcode/config.json: $($servers.Keys -join ', ')"
  }
  if (-not $DryRun) {
    Add-GitLocalExclude $Root @("/.zcode/config.json", "/.zcode/.ai-devops-mcp-managed")
  }
}

function Write-MimoProjectConfig([string]$Root, [string[]]$Names) {
  $dir = Join-Path $Root ".mimocode"
  $path = Join-Path $dir "mimocode.json"
  $markerPath = Join-Path $dir ".ai-devops-mcp-managed"
  if (Test-GitPathTracked $Root ".mimocode/mimocode.json") {
    Write-Host "  skip $Root .mimocode/mimocode.json is tracked; left untouched"; return
  }
  if ((Test-Path -LiteralPath $path) -and -not (Test-Path -LiteralPath $markerPath)) {
    Write-Host "  skip $Root .mimocode/mimocode.json is hand-written; left untouched"; return
  }
  $servers = [ordered]@{}
  foreach ($name in $Names) {
    if (-not $Catalog.Contains($name)) { continue }
    $src = $Catalog[$name]
    if (-not $src.Contains("command")) { continue }
    $argv = New-Object System.Collections.Generic.List[string]
    $argv.Add([string]$src["command"])
    if ($src.Contains("args") -and $src["args"]) {
      foreach ($a in @($src["args"])) { $argv.Add([string]$a) }
    }
    $entry = [ordered]@{
      type = "local"
      command = $argv.ToArray()
    }
    if ($src.Contains("env") -and $src["env"]) {
      $envMap = [ordered]@{}
      foreach ($k in ($src["env"].Keys | Sort-Object)) { $envMap[[string]$k] = [string]$src["env"][$k] }
      $entry["env"] = $envMap
    }
    $entry["enabled"] = $true
    $entry["timeout"] = 120000
    $servers[$name] = $entry
  }
  if ($servers.Count -eq 0) { return }
  $payload = [ordered]@{
    '$schema' = "https://mimo.xiaomi.com/mimocode/config.json"
    mcp = $servers
  }
  $text = (($payload | ConvertTo-Json -Depth 12) -replace "`r`n", "`n").TrimEnd() + "`n"
  $cur = if (Test-Path -LiteralPath $path) { (Get-Content -Raw -LiteralPath $path) -replace "`r`n", "`n" } else { $null }
  if ($cur -eq $text -and (Test-Path -LiteralPath $markerPath)) {
    Write-Host "  ok   $Root .mimocode/mimocode.json already carries $($servers.Keys -join ', ')"
  } elseif ($DryRun) {
    Write-Host "  plan $Root .mimocode/mimocode.json: $($servers.Keys -join ',')"; return
  } else {
    Write-Utf8NoBom $path $text
    Write-Utf8NoBom $markerPath $ManagedMarkerText
    Write-Host "  ok   $Root .mimocode/mimocode.json: $($servers.Keys -join ', ')"
  }
  if (-not $DryRun) {
    Add-GitLocalExclude $Root @("/.mimocode/mimocode.json", "/.mimocode/.ai-devops-mcp-managed")
  }
}

# --- ~/.claude.json project entries (loaded once, saved once if changed) -----
$codeConfig = Read-JsonHashtable $ClaudeCodeConfig
if ($null -eq $codeConfig) { $codeConfig = @{} }
if (-not $codeConfig.ContainsKey("projects") -or $null -eq $codeConfig["projects"]) {
  $codeConfig["projects"] = @{}
}
$codeDirty = $false

foreach ($key in $Scope.Keys) {
  $desired = @($Scope[$key])
  # NOT $roots: PowerShell variables are case-insensitive, so that would
  # clobber the type-constrained $Roots parameter on the first iteration.
  # A scope key the caller left out of $Roots (project not cloned here) is
  # skipped: @($null).Count is 1 in PowerShell, so indexing alone would
  # iterate once with a null root and die at GetFullPath (#705 live run).
  $rootList = @()
  if ($Roots.Contains($key)) { $rootList = @($Roots[$key] | Where-Object { $_ }) }
  if ($rootList.Count -eq 0) { continue }
  foreach ($root in $rootList) {
    $rootPath = [IO.Path]::GetFullPath($root)
    $codexNames = @($desired | Where-Object { $CodexServers.Contains($_) })
    if ($codexNames.Count -gt 0) { Write-CodexProjectConfig $rootPath $codexNames }
    Write-AntigravityProjectPlugin $rootPath $desired
    Write-ZCodeProjectConfig $rootPath $desired
    Write-MimoProjectConfig $rootPath $desired
    $mcpJson = Join-Path $rootPath ".mcp.json"
    $tracked = Test-McpJsonTracked $rootPath
    $fileNames = @()
    if (Test-Path -LiteralPath $mcpJson) {
      $fileJson = Read-JsonHashtable $mcpJson
      if ($fileJson -and $fileJson.ContainsKey("mcpServers") -and $fileJson["mcpServers"]) {
        $fileNames = @($fileJson["mcpServers"].Keys)
      }
    }

    if (-not $tracked) {
      # Our file to manage: desired names from the catalog, foreign preserved,
      # managed-but-out-of-scope removed.
      $newServers = [ordered]@{}
      if (Test-Path -LiteralPath $mcpJson) {
        foreach ($name in $fileNames) {
          if (-not (Test-ManagedName $name)) { $newServers[$name] = $fileJson["mcpServers"][$name] }
        }
      }
      foreach ($name in $desired) { $newServers[$name] = $Catalog[$name] }
      $dropped = @($fileNames | Where-Object { (Test-ManagedName $_) -and $desired -notcontains $_ })
      $added   = @($desired | Where-Object { $fileNames -notcontains $_ })
      $newJsonText = ((@{ mcpServers = $newServers } | ConvertTo-Json -Depth 12) -replace "`r`n", "`n").TrimEnd() + "`n"
      $curJsonText = if (Test-Path -LiteralPath $mcpJson) { (Get-Content -Raw -LiteralPath $mcpJson) -replace "`r`n", "`n" } else { $null }
      if ($curJsonText -eq $newJsonText) {
        Write-Host "  ok   $rootPath .mcp.json (untracked) already carries $($desired -join ', ')"
        continue
      }
      if ($DryRun) {
        Write-Host "  plan $rootPath .mcp.json (untracked): +$($added -join ',') -$($dropped -join ',')"
        continue
      }
      $backup = Backup-Path $mcpJson
      Write-Utf8NoBom $mcpJson $newJsonText
      Write-Host "  ok   $rootPath .mcp.json (untracked): +$($added -join ', ') -$($dropped -join ', ')"
      if ($backup) { Write-Host "       prior file kept at $(Split-Path -Leaf $backup)" }
    } else {
      # The repository tracks its own .mcp.json: never modify it. Deliver only
      # the names it lacks through the Claude Code project entry.
      $missing = @($desired | Where-Object { $fileNames -notcontains $_ })
      # Claude Code keys projects by the FORWARD-slash path (C:/repos/oracle);
      # a backslash key is never read. Earlier runs wrote backslash keys, so
      # managed names are migrated out of that legacy entry (live proof,
      # 2026-09-24: vercel under the backslash key for C:/repos/oracle never appeared).
      $entryKey = $rootPath.Replace([string][char]92, '/')
      if ($entryKey -cne $rootPath -and $codeConfig["projects"].ContainsKey($rootPath)) {
        $legacy = $codeConfig["projects"][$rootPath]
        if ($legacy -and $legacy.ContainsKey("mcpServers") -and $legacy["mcpServers"]) {
          $legacyManaged = @($legacy["mcpServers"].Keys | Where-Object { Test-ManagedName $_ })
          if ($legacyManaged.Count -gt 0 -and -not $DryRun) {
            foreach ($name in $legacyManaged) { $null = $legacy["mcpServers"].Remove($name) }
            if ($legacy["mcpServers"].Count -eq 0) { $null = $legacy.Remove("mcpServers") }
            if ($legacy.Count -eq 0) { $null = $codeConfig["projects"].Remove($rootPath) }
            $codeDirty = $true
            Write-Host "  ok   $rootPath legacy backslash project entry: -$($legacyManaged -join ', ')"
          }
        }
      }
      $entry = $null
      if ($codeConfig["projects"].ContainsKey($entryKey) -and $codeConfig["projects"][$entryKey]) {
        $entry = $codeConfig["projects"][$entryKey]
      }
      $entryNames = @()
      if ($entry -and $entry.ContainsKey("mcpServers") -and $entry["mcpServers"]) {
        $entryNames = @($entry["mcpServers"].Keys)
      }
      # Stale = managed names we previously delivered that are no longer scoped
      # for this root and are not provided by the tracked file either.
      $stale = @($entryNames | Where-Object {
        (Test-ManagedName $_) -and $desired -notcontains $_ -and $fileNames -notcontains $_ })
      if ($missing.Count -eq 0 -and $stale.Count -eq 0) {
        Write-Host "  ok   ${rootPath}: tracked .mcp.json already carries $($desired -join ', ')"
        continue
      }
      if ($DryRun) {
        Write-Host "  plan $rootPath project entry: +$($missing -join ',') -$($stale -join ',')"
        continue
      }
      if (-not $entry) {
        $entry = @{}
        $codeConfig["projects"][$entryKey] = $entry
      }
      if (-not $entry.ContainsKey("mcpServers") -or $null -eq $entry["mcpServers"]) {
        $entry["mcpServers"] = @{}
      }
      foreach ($name in $stale) { $null = $entry["mcpServers"].Remove($name) }
      foreach ($name in $missing) { $entry["mcpServers"][$name] = $Catalog[$name] }
      if ($entry["mcpServers"].Count -eq 0) { $null = $entry.Remove("mcpServers") }
      $codeDirty = $true
      Write-Host "  ok   $rootPath project entry: +$($missing -join ', ') -$($stale -join ', ')"
    }
  }
}

if ($codeDirty -and -not $DryRun) {
  $backup = Backup-Path $ClaudeCodeConfig
  Write-JsonAtomic $ClaudeCodeConfig $codeConfig
  if ($backup) { Write-Host "  ok   prior $ClaudeCodeConfig kept at $(Split-Path -Leaf $backup)" }
}
