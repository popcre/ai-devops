<#
.SYNOPSIS
  Deliver project-scoped MCP servers into each owning repository (#705).

.DESCRIPTION
  For every (repository key -> root) pair, make the project's scoped server
  names available to sessions opened in that root, without touching anything
  the repository itself tracks:

  - .mcp.json is written only when it is absent or UNTRACKED. Managed catalog
    names outside the project's scope are removed; entries the catalog does
    not know (foreign) are preserved; a timestamped backup is kept.
  - When the repository TRACKS its own .mcp.json, the file is never modified.
    Names it already carries are left to the file; any scoped name it lacks is
    written as a Claude Code project entry in ~/.claude.json
    (projects[<path>].mcpServers), and stale managed names in that entry are
    pruned. Nothing else in ~/.claude.json is touched.

  - Codex: scoped names that also appear in -CodexServers are written to the
    root's .codex/config.toml (Codex loads it in trusted projects). The file is
    written only when absent, or untracked and carrying the ai-devops marker; a
    tracked or hand-written file is never touched. It is added to the clone's
    local info/exclude so it never shows as an untracked change.

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

function Write-JsonAtomic([string]$Path, $Value) {
  $dir = Split-Path -Parent $Path
  $tmp = Join-Path $dir (".aidevops-" + [guid]::NewGuid().ToString("N") + ".tmp")
  $Value | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $tmp -Encoding utf8
  Move-Item -LiteralPath $tmp -Destination $Path -Force
}

function Test-McpJsonTracked([string]$Root) {
  git -C $Root ls-files --error-unmatch .mcp.json 2>$null | Out-Null
  return ($LASTEXITCODE -eq 0)
}

function Read-JsonHashtable([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  return (Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -AsHashtable)
}

$CodexMarker = "# Managed by ai-devops bin/write-project-mcp.ps1 (#705). Rewritten by setup-machine.ps1."

function ConvertTo-TomlValue($Value) {
  if ($Value -is [int] -or $Value -is [long]) { return [string]$Value }
  if ($Value -is [bool]) { return $(if ($Value) { "true" } else { "false" }) }
  $text = [string]$Value
  if ($text.Contains("'")) { throw "Cannot write a TOML literal containing a single quote." }
  return "'$text'"
}

function Write-CodexProjectConfig([string]$Root, [string[]]$Names) {
  $dir = Join-Path $Root ".codex"
  $path = Join-Path $dir "config.toml"
  git -C $Root ls-files --error-unmatch .codex/config.toml 2>$null | Out-Null
  if ($LASTEXITCODE -eq 0) { Write-Host "  skip $Root .codex/config.toml is tracked; left untouched"; return }
  if ((Test-Path -LiteralPath $path) -and
      -not ((Get-Content -Raw -LiteralPath $path) -like "$CodexMarker*")) {
    Write-Host "  skip $Root .codex/config.toml is hand-written; left untouched"; return
  }
  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add($CodexMarker)
  foreach ($name in $Names) {
    $lines.Add("")
    $lines.Add(('[mcp_servers."{0}"]' -f $name))
    foreach ($k in $CodexServers[$name].Keys) {
      $lines.Add(("{0} = {1}" -f $k, (ConvertTo-TomlValue $CodexServers[$name][$k])))
    }
  }
  $text = ($lines -join "`n") + "`n"
  if ((Test-Path -LiteralPath $path) -and (Get-Content -Raw -LiteralPath $path) -eq $text) {
    Write-Host "  ok   $Root .codex/config.toml already carries $($Names -join ', ')"
  } elseif ($DryRun) {
    Write-Host "  plan $Root .codex/config.toml: $($Names -join ',')"; return
  } else {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $tmp = Join-Path $dir (".aidevops-" + [guid]::NewGuid().ToString("N") + ".tmp")
    [IO.File]::WriteAllText($tmp, $text, (New-Object System.Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $tmp -Destination $path -Force
    Write-Host "  ok   $Root .codex/config.toml: $($Names -join ', ')"
  }
  git -C $Root check-ignore -q .codex/config.toml 2>$null
  if ($LASTEXITCODE -ne 0) {
    $common = git -C $Root rev-parse --path-format=absolute --git-common-dir 2>$null
    if ($common) {
      $exclude = Join-Path $common "info\exclude"
      New-Item -ItemType Directory -Force -Path (Split-Path -Parent $exclude) | Out-Null
      Add-Content -LiteralPath $exclude -Value "/.codex/config.toml"
    }
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
      if ($DryRun) {
        Write-Host "  plan $rootPath .mcp.json (untracked): +$($added -join ',') -$($dropped -join ',')"
        continue
      }
      $backup = Backup-Path $mcpJson
      Write-JsonAtomic $mcpJson @{ mcpServers = $newServers }
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
