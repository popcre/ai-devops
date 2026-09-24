# write-project-mcp.ps1 (#705): scoped servers land per owning repository -
# untracked .mcp.json files are managed (foreign preserved, stale managed
# pruned), tracked .mcp.json files are never touched and missing names go to
# the Claude Code project entry instead.

$ErrorActionPreference = "Stop"
$passed = 0
$failed = 0

function Assert-True([bool]$Condition, [string]$Message) {
  if ($Condition) { Write-Host "  ok   $Message"; $script:passed++ }
  else { Write-Host "  FAIL $Message"; $script:failed++ }
}

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$writer = Join-Path $repoRoot "bin\write-project-mcp.ps1"
$shell = (Get-Process -Id $PID).Path
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("write-project-mcp-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $testRoot | Out-Null

function Write-Json([string]$Path, $Value) {
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $Value | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding utf8
}

function Read-Json([string]$Path) {
  return (Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -AsHashtable)
}

$catalog = @{
  "trigger"   = @{ command = "catA"; args = @("t") }
  "recall-ai" = @{ command = "catA"; args = @("r") }
  "railway"   = @{ command = "catA"; args = @("rw") }
  "oldserver" = @{ command = "catA"; args = @("o") }
}
$claudeJson = Join-Path $testRoot "claude.json"

try {
  # ---- A: absent untracked .mcp.json is created from the catalog ----------
  $rootA = Join-Path $testRoot "alpha"
  New-Item -ItemType Directory -Force -Path $rootA | Out-Null
  git -C $rootA init -q 2>$null

  # ---- B: untracked .mcp.json with foreign + stale managed entries --------
  $rootB = Join-Path $testRoot "beta"
  New-Item -ItemType Directory -Force -Path $rootB | Out-Null
  git -C $rootB init -q 2>$null
  Write-Json (Join-Path $rootB ".mcp.json") @{
    mcpServers = @{
      "hand-added" = @{ command = "foreign" }
      "oldserver"  = @{ command = "stale" }
      "trigger"    = @{ command = "wrong-def" }
    }
  }

  # ---- C: tracked .mcp.json is never modified; missing names go to the ----
  #         Claude Code project entry, stale entry names are pruned.
  $rootC = Join-Path $testRoot "gamma"
  New-Item -ItemType Directory -Force -Path $rootC | Out-Null
  git -C $rootC init -q 2>$null
  Write-Json (Join-Path $rootC ".mcp.json") @{
    mcpServers = @{ "trigger" = @{ command = "repo-owned" } }
  }
  git -C $rootC add .mcp.json 2>$null
  $bytesBefore = [IO.File]::ReadAllBytes((Join-Path $rootC ".mcp.json"))
  $rootCfull = [IO.Path]::GetFullPath($rootC)
  # Claude Code reads only the forward-slash project key; the backslash key is
  # the legacy form earlier runs wrote, and its managed names must migrate out.
  $rootCkey = $rootCfull.Replace([string][char]92, '/')
  Write-Json $claudeJson @{
    mcpServers = @{ "1password" = @{ command = "x" } }
    projects = @{
      $rootCfull = @{ mcpServers = @{ "railway" = @{ command = "stale-legacy" }; "own" = @{ command = "foreign" } } }
      $rootCkey  = @{ mcpServers = @{ "railway" = @{ command = "stale-entry" } } }
    }
  }

  $scope = [ordered]@{
    "alpha" = @("trigger", "recall-ai")
    "beta"  = @("recall-ai")
    "gamma" = @("trigger", "recall-ai")
  }
  $roots = @{
    "alpha" = @($rootA)
    "beta"  = @($rootB)
    "gamma" = @($rootC)
  }

  # In-process call, exactly how setup-machine.ps1 step 7b invokes the writer
  # (a child `pwsh -File` boundary would stringify the hashtable parameters).
  & $writer -Scope $scope -Roots $roots -Catalog $catalog -ClaudeCodeConfig $claudeJson
  Assert-True ($?) "writer completes"

  $a = Read-Json (Join-Path $rootA ".mcp.json")
  Assert-True (@($a["mcpServers"].Keys | Sort-Object) -join "," -eq "recall-ai,trigger") "A: absent .mcp.json created with exactly the scoped names"

  $b = Read-Json (Join-Path $rootB ".mcp.json")
  Assert-True (@($b["mcpServers"].Keys | Sort-Object) -join "," -eq "hand-added,recall-ai") "B: foreign kept, stale managed removed, scoped added"
  Assert-True ($b["mcpServers"]["recall-ai"]["command"] -eq "catA") "B: scoped entry takes the catalog definition"

  $bytesAfter = [IO.File]::ReadAllBytes((Join-Path $rootC ".mcp.json"))
  Assert-True (@(Compare-Object $bytesBefore $bytesAfter).Count -eq 0) "C: tracked .mcp.json bytes unchanged"
  $cfg = Read-Json $claudeJson
  $entry = $cfg["projects"][$rootCkey]["mcpServers"]
  $legacyEntry = $cfg["projects"][$rootCfull]["mcpServers"]
  Assert-True (@($legacyEntry.Keys) -join "," -eq "own") "C: managed names migrate out of the legacy backslash key, foreign kept"
  Assert-True (@($entry.Keys | Sort-Object) -join "," -eq "recall-ai") "C: project entry gains only the missing name and prunes the stale one"
  Assert-True ($cfg["mcpServers"]["1password"]["command"] -eq "x") "C: global mcpServers in claude.json untouched"
  $backups = @(Get-ChildItem -LiteralPath $testRoot -Filter "claude.json.aidevops.*.bak" -ErrorAction SilentlyContinue)
  Assert-True ($backups.Count -eq 1) "C: one timestamped backup of claude.json was kept"

  # ---- idempotence: a second run changes nothing --------------------------
  $before2 = [IO.File]::ReadAllBytes($claudeJson)
  & $writer -Scope $scope -Roots $roots -Catalog $catalog -ClaudeCodeConfig $claudeJson
  $after2 = [IO.File]::ReadAllBytes($claudeJson)
  Assert-True (@(Compare-Object $before2 $after2).Count -eq 0) "second run is a no-op"

  # ---- DryRun writes nothing ----------------------------------------------
  $rootD = Join-Path $testRoot "delta"
  New-Item -ItemType Directory -Force -Path $rootD | Out-Null
  & $writer -Scope ([ordered]@{ "delta" = @("trigger") }) -Roots (@{ "delta" = @($rootD) }) `
    -Catalog $catalog -ClaudeCodeConfig $claudeJson -DryRun
  Assert-True (-not (Test-Path (Join-Path $rootD ".mcp.json"))) "DryRun writes no .mcp.json"

  # ---- untracked file with foreign-only survives a scope change -----------
  $scope2 = [ordered]@{ "beta" = @("railway") }
  & $writer -Scope $scope2 -Roots (@{ "beta" = @($rootB) }) -Catalog $catalog -ClaudeCodeConfig $claudeJson
  $b2 = Read-Json (Join-Path $rootB ".mcp.json")
  Assert-True (@($b2["mcpServers"].Keys | Sort-Object) -join "," -eq "hand-added,railway") "B2: scope change swaps managed names, foreign still kept"

  # ---- a scope key with no Roots entry (project not cloned) is skipped ----
  # Regression for the 2026-09-24 live run: @($null).Count is 1, so indexing
  # alone iterated once with a null root and died at GetFullPath before the
  # save, silently dropping every project entry written earlier.
  $scope3 = [ordered]@{ "beta" = @("railway"); "notcloned" = @("trigger") }
  $before3 = [IO.File]::ReadAllBytes($claudeJson)
  & $writer -Scope $scope3 -Roots (@{ "beta" = @($rootB) }) -Catalog $catalog -ClaudeCodeConfig $claudeJson
  $after3 = [IO.File]::ReadAllBytes($claudeJson)
  Assert-True (@(Compare-Object $before3 $after3).Count -eq 0) "a scope key missing from Roots is skipped and the run completes"

  # ---- Codex: scoped names with a Codex definition go to .codex/config.toml
  $rootE = Join-Path $testRoot "epsilon"
  New-Item -ItemType Directory -Force -Path $rootE | Out-Null
  git -C $rootE init -q 2>$null
  $codex = [ordered]@{ "vercel" = [ordered]@{ url = "https://mcp.vercel.com"; startup_timeout_sec = 20 } }
  $catalogE = @{ "trigger" = @{ command = "catA" }; "vercel" = @{ type = "http"; url = "https://mcp.vercel.com" } }
  & $writer -Scope ([ordered]@{ "epsilon" = @("trigger", "vercel") }) -Roots (@{ "epsilon" = @($rootE) }) `
    -Catalog $catalogE -ClaudeCodeConfig $claudeJson -CodexServers $codex
  $toml = Get-Content -Raw -LiteralPath (Join-Path $rootE ".codex\config.toml")
  Assert-True ($toml.Contains('[mcp_servers."vercel"]') -and $toml.Contains("url = 'https://mcp.vercel.com'") -and
    $toml.Contains("startup_timeout_sec = 20")) "E: Codex project config carries vercel natively"
  Assert-True (-not $toml.Contains("trigger")) "E: names without a Codex definition stay out of the Codex file"
  $e = Read-Json (Join-Path $rootE ".mcp.json")
  Assert-True ($e["mcpServers"]["vercel"]["type"] -eq "http") "E: Claude Code gets vercel as native http"
  git -C $rootE check-ignore -q .codex/config.toml 2>$null
  Assert-True ($LASTEXITCODE -eq 0) "E: .codex/config.toml is locally excluded"
  Set-Content -LiteralPath (Join-Path $rootE ".codex\config.toml") -Value "hand = 1"
  & $writer -Scope ([ordered]@{ "epsilon" = @("vercel") }) -Roots (@{ "epsilon" = @($rootE) }) `
    -Catalog $catalogE -ClaudeCodeConfig $claudeJson -CodexServers $codex
  Assert-True ((Get-Content -Raw -LiteralPath (Join-Path $rootE ".codex\config.toml")).Trim() -eq "hand = 1") "E: a hand-written Codex file is never overwritten"
} finally {
  Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "$passed passed, $failed failed"
if ($failed -gt 0) { exit 1 }
exit 0
