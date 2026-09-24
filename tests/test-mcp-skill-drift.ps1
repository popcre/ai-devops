# Drift checks for #703: installed Claude MCP sets vs. declared membership,
# Claude Desktop sync pruning and deferral, and the manual-only skill list.

$ErrorActionPreference = "Stop"
$passed = 0
$failed = 0

function Assert-True([bool]$Condition, [string]$Message) {
  if ($Condition) { Write-Host "  ok   $Message"; $script:passed++ }
  else { Write-Host "  FAIL $Message"; $script:failed++ }
}

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$drift = Join-Path $repoRoot "bin\check-mcp-drift.ps1"
$sync = Join-Path $repoRoot "bin\sync-claude-desktop-mcp.ps1"
$shell = (Get-Process -Id $PID).Path
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("mcp-drift-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $testRoot | Out-Null

function Write-Json([string]$Path, $Value) {
  $Value | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding utf8
}

try {
  # ---------------------------------------------------------- drift detection
  $setup = Join-Path $testRoot "setup-machine.ps1"
  @'
$ClaudeCodeMcpNames = @("1password")
$ClaudeDesktopMcpNames = @("1password", "trigger")
'@ | Set-Content -LiteralPath $setup -Encoding utf8
  $desktop = Join-Path $testRoot "desktop.json"
  $code = Join-Path $testRoot "claude.json"
  Write-Json $code @{ mcpServers = @{ "1password" = @{ command = "x" } } }

  Write-Json $desktop @{ theme = "dark"; mcpServers = @{ "1password" = @{ command = "x" }; "trigger" = @{ command = "x" }; "supabase" = @{ command = "x" } } }
  $out = & $shell -NoProfile -File $drift -SetupScript $setup -DesktopConfigPaths $desktop -ClaudeCodeConfigPath $code
  Assert-True ($LASTEXITCODE -eq 1) "an extra installed server fails the drift check"
  Assert-True (($out -join "`n") -match "installed but not declared: supabase") "the drift report names the extra server"

  Write-Json $desktop @{ mcpServers = @{ "1password" = @{ command = "x" }; "trigger" = @{ command = "x" } } }
  $null = & $shell -NoProfile -File $drift -SetupScript $setup -DesktopConfigPaths $desktop -ClaudeCodeConfigPath $code
  Assert-True ($LASTEXITCODE -eq 0) "matching sets pass the drift check"

  $realSetup = Join-Path $repoRoot "bin\setup-machine.ps1"
  $null = & $shell -NoProfile -File $drift -SetupScript $realSetup -DesktopConfigPaths (Join-Path $testRoot "absent.json") -ClaudeCodeConfigPath $code -SkipProjectScope
  Assert-True ($LASTEXITCODE -eq 0) "declared lists parse from the real setup-machine.ps1"

  # ------------------------------------------- project-scoped MCP drift (#705)
  $scanRoot = Join-Path $testRoot "scan"
  New-Item -ItemType Directory -Force -Path $scanRoot | Out-Null
  $identityFile = Join-Path $testRoot "identities.tsv"
  @'
fixtureproj	github.com/example/fixtureproj
trackedproj	github.com/example/trackedproj
absentproj	github.com/example/absentproj
'@ | Set-Content -LiteralPath $identityFile -Encoding utf8

  foreach ($name in @("fixtureproj", "trackedproj")) {
    $r = Join-Path $scanRoot $name
    New-Item -ItemType Directory -Force -Path $r | Out-Null
    git -C $r init -q 2>$null
    git -C $r remote add origin https://github.com/example/$name.git 2>$null
  }
  Write-Json (Join-Path $scanRoot "fixtureproj\.mcp.json") @{
    mcpServers = @{ "trigger" = @{ command = "x" } } }
  Write-Json (Join-Path $scanRoot "trackedproj\.mcp.json") @{
    mcpServers = @{ "repo-owned" = @{ command = "x" } } }
  git -C (Join-Path $scanRoot "trackedproj") add .mcp.json 2>$null
  $trackedFull = [IO.Path]::GetFullPath((Join-Path $scanRoot "trackedproj"))
  $codeProjects = Join-Path $testRoot "claude-projects.json"
  Write-Json $codeProjects @{
    mcpServers = @{ "1password" = @{ command = "x" } }
    projects = @{ $trackedFull = @{ mcpServers = @{ "trigger" = @{ command = "x" } } } } }

  $setupScoped = Join-Path $testRoot "setup-scoped.ps1"
  @'
$ClaudeCodeMcpNames = @("1password")
$ClaudeDesktopMcpNames = @("1password", "trigger", "recall-ai")
$McpProjectScope = [ordered]@{
  "fixtureproj" = @("trigger")
  "trackedproj" = @("trigger")
  "absentproj"  = @("recall-ai")
}
$McpServerCatalog["trigger"] = @{ command = "x" }
'@ | Set-Content -LiteralPath $setupScoped -Encoding utf8

  $oldIdFile = $env:AI_REPO_IDENTITY_FILE
  $oldCloneRoots = $env:AI_REPO_CLONE_ROOTS
  $env:AI_REPO_IDENTITY_FILE = $identityFile
  $env:AI_REPO_CLONE_ROOTS = $scanRoot
  try {
    # absentproj is not cloned, so recall-ai stays declared; trigger is scoped
    # away from the globals on this machine (fixtureproj + trackedproj exist).
    Write-Json $desktop @{ mcpServers = @{ "1password" = @{ command = "x" }; "recall-ai" = @{ command = "x" } } }
    $out = & $shell -NoProfile -File $drift -SetupScript $setupScoped -DesktopConfigPaths $desktop -ClaudeCodeConfigPath $codeProjects
    Assert-True ($LASTEXITCODE -eq 0) "scoped-away trigger leaves globals; delivery via untracked file and project entry passes"
    Assert-True (($out -join "`n") -match "absentproj.*stay global: recall-ai") "a not-cloned project keeps its server global"

    Write-Json $desktop @{ mcpServers = @{ "1password" = @{ command = "x" }; "recall-ai" = @{ command = "x" }; "trigger" = @{ command = "x" } } }
    $out = & $shell -NoProfile -File $drift -SetupScript $setupScoped -DesktopConfigPaths $desktop -ClaudeCodeConfigPath $codeProjects
    Assert-True ($LASTEXITCODE -eq 1) "a scoped server still installed globally fails the check"
    Assert-True (($out -join "`n") -match "installed but not declared: trigger") "the report names the scoped global server"

    Write-Json $desktop @{ mcpServers = @{ "1password" = @{ command = "x" }; "recall-ai" = @{ command = "x" } } }
    Write-Json $codeProjects @{
      mcpServers = @{ "1password" = @{ command = "x" } } }
    $out = & $shell -NoProfile -File $drift -SetupScript $setupScoped -DesktopConfigPaths $desktop -ClaudeCodeConfigPath $codeProjects
    Assert-True ($LASTEXITCODE -eq 1) "a tracked repo whose project entry lost the scoped server fails the check"
    Assert-True (($out -join "`n") -match "scoped but not delivered: trigger") "the report names the undelivered scoped server"

    Write-Json (Join-Path $scanRoot "fixtureproj\.mcp.json") @{
      mcpServers = @{ "hand-added" = @{ command = "x" } } }
    $out = & $shell -NoProfile -File $drift -SetupScript $setupScoped -DesktopConfigPaths $desktop -ClaudeCodeConfigPath $codeProjects
    Assert-True ($LASTEXITCODE -eq 1) "an untracked .mcp.json missing its scoped managed names fails the check"
    Assert-True (($out -join "`n") -match "declared but not installed: trigger") "the untracked-file drift names the missing managed name"

    Write-Json (Join-Path $scanRoot "fixtureproj\.mcp.json") @{
      mcpServers = @{ "hand-added" = @{ command = "x" }; "trigger" = @{ command = "x" } } }
    $out = & $shell -NoProfile -File $drift -SetupScript $setupScoped -DesktopConfigPaths $desktop -ClaudeCodeConfigPath $codeProjects
    Assert-True ($LASTEXITCODE -eq 1) "still failing while the tracked repo entry is absent"
  } finally {
    if ($null -ne $oldIdFile) { $env:AI_REPO_IDENTITY_FILE = $oldIdFile } else { Remove-Item Env:\AI_REPO_IDENTITY_FILE -ErrorAction SilentlyContinue }
    if ($null -ne $oldCloneRoots) { $env:AI_REPO_CLONE_ROOTS = $oldCloneRoots } else { Remove-Item Env:\AI_REPO_CLONE_ROOTS -ErrorAction SilentlyContinue }
  }

  # ------------------------------------------------ desktop sync and deferral
  $desired = Join-Path $testRoot "desired.json"
  Write-Json $desired @{
    servers = @{ "1password" = @{ command = "new" }; "trigger" = @{ command = "new" } }
    managed = @("1password", "trigger", "supabase", "codex-cli")
  }
  Write-Json $desktop @{ theme = "dark"; mcpServers = @{
    "1password" = @{ command = "old" }; "supabase" = @{ command = "x" }
    "codex-cli" = @{ command = "x" }; "hand-added" = @{ command = "x" } } }
  $before = Get-FileHash -LiteralPath $desktop

  $out = & $shell -NoProfile -File $sync -ConfigPath $desktop -DesiredPath $desired -DesktopStateOverride running
  Assert-True ($LASTEXITCODE -eq 3) "sync defers (exit 3) while Claude Desktop is running"
  Assert-True ((Get-FileHash -LiteralPath $desktop).Hash -eq $before.Hash) "a deferred sync writes nothing"

  $out = & $shell -NoProfile -File $sync -ConfigPath $desktop -DesiredPath $desired -DesktopStateOverride stopped
  $cfg = Get-Content -Raw -LiteralPath $desktop | ConvertFrom-Json -AsHashtable
  $names = @($cfg["mcpServers"].Keys | Sort-Object)
  Assert-True ($LASTEXITCODE -eq 0) "sync applies when Claude Desktop is stopped"
  Assert-True (($names -join ",") -eq "1password,hand-added,trigger") "managed undeclared servers are pruned; unmanaged kept"
  Assert-True ($cfg["mcpServers"]["1password"]["command"] -eq "new") "declared definitions are rewritten"
  Assert-True ($cfg["theme"] -eq "dark") "unrelated settings survive"
  Assert-True (($out -join "`n") -match "\[WARN\].*hand-added") "unmanaged server is reported"
  Assert-True (@(Get-ChildItem -LiteralPath $testRoot -Filter "desktop.json.aidevops.*.bak").Count -eq 1) "a recoverable backup is kept"

  # ---------------------------------------------------- manual-only skill list
  $flagged = @(Get-ChildItem -Path (Join-Path $repoRoot "skills") -Recurse -Filter SKILL.md |
    Where-Object { (Get-Content -Raw -LiteralPath $_.FullName) -match '(?m)^disable-model-invocation:\s*true\s*$' } |
    ForEach-Object { $_.Directory.Name } | Sort-Object -Unique)
  $doc = Get-Content -Raw -LiteralPath (Join-Path $repoRoot "docs\context-engineering.md")
  $m = [regex]::Match($doc, '(?s)reinstall\. The \w+ are:(.*?)\.\r?\n')
  $listed = @([regex]::Matches($m.Groups[1].Value, '`([a-z0-9-]+)`') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
  Assert-True ($m.Success -and $listed.Count -gt 0) "the manual-only list is found in docs/context-engineering.md"
  $diff = @(Compare-Object $flagged $listed | ForEach-Object { "$($_.InputObject) ($($_.SideIndicator))" })
  Assert-True ($diff.Count -eq 0) "skills carrying disable-model-invocation match the documented list $($diff -join ', ')"
  Assert-True ($flagged -contains "designflow-human-qa") "designflow-human-qa stays manual-only"
} finally {
  $resolved = [System.IO.Path]::GetFullPath($testRoot)
  if ((Split-Path -Leaf $resolved).StartsWith("mcp-drift-")) { Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host ""
Write-Host "$passed passed, $failed failed"
if ($failed -gt 0) { exit 1 }
