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
  $null = & $shell -NoProfile -File $drift -SetupScript $realSetup -DesktopConfigPaths (Join-Path $testRoot "absent.json") -ClaudeCodeConfigPath $code
  Assert-True ($LASTEXITCODE -eq 0) "declared lists parse from the real setup-machine.ps1"

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
