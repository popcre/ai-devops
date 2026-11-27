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

  # ---- All-harness delivery: Codex TOML arrays/tables, Antigravity, ZCode, MiMoCode, and non-git parent folder
  $rootF = Join-Path $testRoot "dflow_plm\designflow-frontend"
  $parentF = Split-Path -Parent $rootF
  New-Item -ItemType Directory -Force -Path $rootF | Out-Null
  git -C $rootF init -q 2>$null
  # Seed a sibling file inside .mimocode to prove it survives untouched.
  New-Item -ItemType Directory -Force -Path (Join-Path $parentF ".mimocode") | Out-Null
  Set-Content -LiteralPath (Join-Path $parentF ".mimocode\.cron-lock") -Value '{"pid":1}'

  $catalogF = [ordered]@{
    "ag-grid" = [ordered]@{
      command = "C:\Program Files\nodejs\node.exe"
      args    = @("C:\guard.mjs", "C:\ag-mcp.cmd")
      env     = [ordered]@{ "B_VAR" = "two"; "A_VAR" = "one" }
    }
    "vercel" = [ordered]@{
      type = "http"
      url  = "https://mcp.vercel.com"
    }
  }
  $codexF = [ordered]@{
    "ag-grid" = [ordered]@{
      command = "C:\Program Files\nodejs\node.exe"
      args    = @("C:\guard.mjs", "C:\ag-mcp.cmd")
      env     = [ordered]@{ "A_VAR" = "one" }
    }
  }
  & $writer -Scope ([ordered]@{ "designflow-frontend" = @("ag-grid", "vercel") }) `
    -Roots (@{ "designflow-frontend" = @($rootF, $parentF) }) `
    -Catalog $catalogF -ClaudeCodeConfig $claudeJson -CodexServers $codexF
  Assert-True ($?) "F: multi-harness writer completes"

  foreach ($target in @($rootF, $parentF)) {
    $tomlPath = Join-Path $target ".codex\config.toml"
    $pyOut = python3 -c "import json,sys,tomllib; d=tomllib.load(open(sys.argv[1],'rb')); s=d['mcp_servers']['ag-grid']; print(json.dumps(s))" $tomlPath 2>&1
    Assert-True ($LASTEXITCODE -eq 0) "F ($target): Codex TOML parses cleanly with tomllib"
    $parsedToml = $pyOut | ConvertFrom-Json -AsHashtable
    Assert-True ($parsedToml["args"] -is [System.Collections.IList] -and $parsedToml["args"].Count -eq 2 -and $parsedToml["args"][1] -eq "C:\ag-mcp.cmd") "F ($target): Codex args serialized as TOML array"
    Assert-True ($parsedToml["env"]["A_VAR"] -eq "one") "F ($target): Codex env serialized as TOML inline table"

    $agyPlugin = Read-Json (Join-Path $target ".agents\plugins\ai-devops-project-mcp\plugin.json")
    $agyMcp = Read-Json (Join-Path $target ".agents\plugins\ai-devops-project-mcp\mcp_config.json")
    Assert-True ($agyPlugin["name"] -eq "ai-devops-project-mcp" -and $agyPlugin["version"] -eq "1.0.0") "F ($target): Antigravity plugin.json includes name and version"
    Assert-True ($agyMcp["mcpServers"]["ag-grid"]["command"] -eq "C:\Program Files\nodejs\node.exe" -and $agyMcp["mcpServers"]["ag-grid"]["args"].Count -eq 2) "F ($target): Antigravity mcp_config.json carries ag-grid stdio"
    Assert-True ($agyMcp["mcpServers"]["vercel"]["url"] -eq "https://mcp.vercel.com" -and -not $agyMcp["mcpServers"]["vercel"].ContainsKey("type")) "F ($target): Antigravity strips type on HTTP server"

    $zcodeCfg = Read-Json (Join-Path $target ".zcode\config.json")
    Assert-True ($zcodeCfg["mcp"]["servers"]["ag-grid"]["timeoutMs"] -eq 120000 -and -not $zcodeCfg["mcp"]["servers"].ContainsKey("vercel")) "F ($target): ZCode strict stdio config keeps ag-grid and skips HTTP-only vercel"
    Assert-True (Test-Path -LiteralPath (Join-Path $target ".zcode\.ai-devops-mcp-managed")) "F ($target): ZCode sibling marker created"

    $mimoCfg = Read-Json (Join-Path $target ".mimocode\mimocode.json")
    Assert-True ($mimoCfg["mcp"]["ag-grid"]["type"] -eq "local" -and $mimoCfg["mcp"]["ag-grid"]["command"].Count -eq 3 -and $mimoCfg["mcp"]["ag-grid"]["timeout"] -eq 120000 -and -not $mimoCfg["mcp"].ContainsKey("vercel")) "F ($target): MiMoCode local stdio config flattens command array and skips HTTP-only vercel"
  }
  Assert-True ((Get-Content -Raw -LiteralPath (Join-Path $parentF ".mimocode\.cron-lock")).Trim() -eq '{"pid":1}') "F: existing .mimocode/.cron-lock in parent preserved"
  $parentMcp = Read-Json (Join-Path $parentF ".mcp.json")
  Assert-True ($parentMcp["mcpServers"]["ag-grid"]["command"] -eq "C:\Program Files\nodejs\node.exe") "F: non-git parent gets untracked .mcp.json"
  git -C $rootF check-ignore -q .agents/plugins/ai-devops-project-mcp/ 2>$null
  Assert-True ($LASTEXITCODE -eq 0) "F: Antigravity plugin excluded in git repo"
  git -C $rootF check-ignore -q .zcode/config.json 2>$null
  Assert-True ($LASTEXITCODE -eq 0) "F: ZCode config excluded in git repo"
  git -C $rootF check-ignore -q .mimocode/mimocode.json 2>$null
  Assert-True ($LASTEXITCODE -eq 0) "F: MiMoCode config excluded in git repo"

  # Idempotence + DryRun for the new harness files
  $beforeAgy = Get-FileHash -LiteralPath (Join-Path $parentF ".agents\plugins\ai-devops-project-mcp\mcp_config.json")
  & $writer -Scope ([ordered]@{ "designflow-frontend" = @("ag-grid", "vercel") }) `
    -Roots (@{ "designflow-frontend" = @($rootF, $parentF) }) `
    -Catalog $catalogF -ClaudeCodeConfig $claudeJson -CodexServers $codexF
  $afterAgy = Get-FileHash -LiteralPath (Join-Path $parentF ".agents\plugins\ai-devops-project-mcp\mcp_config.json")
  Assert-True ($beforeAgy.Hash -eq $afterAgy.Hash) "F: multi-harness rerun is idempotent"

  # Hand-written files in Antigravity/ZCode/MiMoCode (no marker) are never overwritten
  $rootG = Join-Path $testRoot "gamma-hand"
  New-Item -ItemType Directory -Force -Path (Join-Path $rootG ".zcode") | Out-Null
  Set-Content -LiteralPath (Join-Path $rootG ".zcode\config.json") -Value '{"hand":true}'
  & $writer -Scope ([ordered]@{ "gamma-hand" = @("ag-grid") }) -Roots (@{ "gamma-hand" = @($rootG) }) `
    -Catalog $catalogF -ClaudeCodeConfig $claudeJson -CodexServers $codexF
  Assert-True ((Get-Content -Raw -LiteralPath (Join-Path $rootG ".zcode\config.json")).Trim() -eq '{"hand":true}') "G: hand-written .zcode/config.json without marker is never overwritten"
} finally {
  Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "$passed passed, $failed failed"
if ($failed -gt 0) { exit 1 }
exit 0
