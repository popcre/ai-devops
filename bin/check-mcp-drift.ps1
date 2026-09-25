<#
.SYNOPSIS
  Fail when an installed Claude MCP server set differs from declared membership.

.DESCRIPTION
  Declared membership is read from the literal lists in setup-machine.ps1
  ($ClaudeDesktopMcpNames, $ClaudeCodeMcpNames), so there is no second copy.
  Project-scoped servers (#705, $McpProjectScope in the same file) are
  always subtracted from those lists, and each clone/worktree root of an
  owning repository is then checked for delivery: an
  untracked .mcp.json must carry exactly the scoped catalog names (foreign
  entries are not ours and are ignored), and a repository that tracks its own
  .mcp.json must cover the scoped names through that file plus its Claude Code
  project entry in ~/.claude.json, with no stale managed leftovers in the
  entry. Exit 0 when every set matches, 1 on drift. Read-only. See #703 for
  the drift this catches and #705 for the scoping.
#>
[CmdletBinding()]
param(
  [string]$SetupScript = (Join-Path $PSScriptRoot "setup-machine.ps1"),
  [string[]]$DesktopConfigPaths = @(
    (Join-Path $env:LOCALAPPDATA "Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\claude_desktop_config.json"),
    (Join-Path $env:APPDATA "Claude\claude_desktop_config.json")),
  [string]$ClaudeCodeConfigPath = (Join-Path $env:USERPROFILE ".claude.json"),
  # Skip per-project validation (parse-only checks, fixture machine layouts).
  [switch]$SkipProjectScope
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Get-DeclaredNames([string]$Variable) {
  $text = Get-Content -Raw -LiteralPath $SetupScript
  $m = [regex]::Match($text, '(?m)^\$' + $Variable + '\s*=\s*@\(([^)]*)\)')
  if (-not $m.Success) { throw "Could not find `$$Variable in $SetupScript" }
  return @([regex]::Matches($m.Groups[1].Value, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object)
}

function Get-ProjectScope([string]$Variable) {
  # Parses the literal $McpProjectScope = [ordered]@{ "key" = @("a","b") ... }
  # block. An absent block (pre-#705 fixture setup texts) returns an empty map.
  $text = Get-Content -Raw -LiteralPath $SetupScript
  $m = [regex]::Match($text, '(?ms)^\$' + $Variable + '\s*=\s*\[ordered\]@\{(.*?)^\}')
  $scope = [ordered]@{}
  if (-not $m.Success) { return $scope }
  foreach ($line in ($m.Groups[1].Value -split "`n")) {
    $e = [regex]::Match($line, '^\s*"([a-zA-Z0-9][a-zA-Z0-9_-]*)"\s*=\s*@\(([^)]*)\)')
    if (-not $e.Success) { continue }
    $names = @([regex]::Matches($e.Groups[2].Value, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
    if ($names.Count -gt 0) { $scope[$e.Groups[1].Value] = $names }
  }
  return $scope
}

function Get-CatalogNames {
  # Every server defined by $McpServerCatalog["name"] = @{ ... } in the setup
  # text: the managed set, which untracked project .mcp.json files answer to.
  $text = Get-Content -Raw -LiteralPath $SetupScript
  return @([regex]::Matches($text, '\$McpServerCatalog\["([a-z0-9-]+)"\]') |
    ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
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
$scope = Get-ProjectScope "McpProjectScope"

# --- resolve which scoped projects are cloned here (same rule as setup) ------
$projectRoots = @{}
if (-not $SkipProjectScope -and $scope.Count -gt 0) {
  . (Join-Path $PSScriptRoot "repo-identity.ps1")
  foreach ($key in $scope.Keys) {
    $roots = @(Get-AiDevOpsCloneRoots -Key $key)
    if ($roots.Count -gt 0) {
      $projectRoots[$key] = $roots
    } else {
      Write-Host "skip  project '$key' not cloned here; its servers load nowhere: $($scope[$key] -join ', ')"
    }
  }
}
# Scoped servers are never global, cloned here or not (same rule as setup).
$scopedAll = @($scope.Values | ForEach-Object { $_ } | Sort-Object -Unique)
if ($scopedAll.Count -gt 0) {
  Write-Host "info  project-scoped (subtracted from globals): $($scopedAll -join ', ')"
}
$desktopDeclared = @($desktopDeclared | Where-Object { $scopedAll -notcontains $_ })
$codeDeclared = @($codeDeclared | Where-Object { $scopedAll -notcontains $_ })

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

# --- per-project delivery (#705) ---------------------------------------------
if (-not $SkipProjectScope -and $scope.Count -gt 0) {
  $catalogNames = Get-CatalogNames
  $codeJson = $null
  if (Test-Path -LiteralPath $ClaudeCodeConfigPath) {
    $codeJson = Get-Content -Raw -LiteralPath $ClaudeCodeConfigPath | ConvertFrom-Json -AsHashtable
  }
  foreach ($key in $projectRoots.Keys) {
    $desired = @($scope[$key])
    foreach ($root in @($projectRoots[$key])) {
      $rootPath = [IO.Path]::GetFullPath($root)
      $mcpJson = Join-Path $rootPath ".mcp.json"
      $fileNames = @()
      if (Test-Path -LiteralPath $mcpJson) { $fileNames = @(Get-InstalledNames $mcpJson) }
      git -C $rootPath ls-files --error-unmatch .mcp.json 2>$null | Out-Null
      $tracked = ($LASTEXITCODE -eq 0)
      $label = "project $key root $rootPath"
      if (-not $tracked) {
        # Our file: its managed names must be exactly the scoped set; foreign
        # entries are not ours and are ignored (the writer preserves them).
        $managed = @($fileNames | Where-Object { $catalogNames -contains $_ })
        Compare-Set "$label (untracked .mcp.json, managed names)" $desired $managed
      } else {
        $entryNames = @()
        # Claude Code reads only the forward-slash project key (C:/repos/x).
        $entryKey = $rootPath.Replace([string][char]92, '/')
        if ($codeJson -and $codeJson.ContainsKey("projects") -and $codeJson["projects"] -and
            $codeJson["projects"].ContainsKey($entryKey) -and $codeJson["projects"][$entryKey] -and
            $codeJson["projects"][$entryKey].ContainsKey("mcpServers") -and $codeJson["projects"][$entryKey]["mcpServers"]) {
          $entryNames = @($codeJson["projects"][$entryKey]["mcpServers"].Keys)
        }
        $delivered = @(@($fileNames) + @($entryNames) | Sort-Object -Unique)
        $missing = @($desired | Where-Object { $delivered -notcontains $_ })
        $stale = @($entryNames | Where-Object {
          $catalogNames -contains $_ -and $desired -notcontains $_ -and $fileNames -notcontains $_ })
        if ($missing.Count -or $stale.Count) {
          $drift++
          Write-Host "DRIFT $label (tracked .mcp.json + project entry)"
          if ($missing.Count) { Write-Host "  scoped but not delivered: $($missing -join ', ')" }
          if ($stale.Count) { Write-Host "  stale managed names in the project entry: $($stale -join ', ')" }
        } else {
          Write-Host "ok    $label (delivers $($desired -join ', '))"
        }
      }
    }
  }
}

if ($drift) { Write-Host "FAIL: $drift installed MCP set(s) differ from declared membership"; exit 1 }
Write-Host "PASS: installed MCP sets match declared membership"
exit 0
