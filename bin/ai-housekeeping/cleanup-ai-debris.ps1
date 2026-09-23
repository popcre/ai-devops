# Daily housekeeping: disposable AI review sandboxes, old archives, temp debris.
# Safe targets only. Never touches live repos, secrets, or recent work (<24h).
$ErrorActionPreference = 'Continue'
$log = 'D:\ai-data\logs\housekeeping.log'
function Log($m) {
  $line = "[{0}] {1}" -f (Get-Date -Format o), $m
  Add-Content -LiteralPath $log -Value $line -ErrorAction SilentlyContinue
  Write-Output $line
}
function Wipe-Dir($path) {
  if (-not (Test-Path -LiteralPath $path)) { return $false }
  $empty = Join-Path $env:TEMP 'robo-empty-housekeep'
  if (-not (Test-Path -LiteralPath $empty)) { New-Item -ItemType Directory -Path $empty | Out-Null }
  & robocopy $empty $path /MIR /NFL /NDL /NJH /NJS /R:0 /W:0 /XJ | Out-Null
  try { [System.IO.Directory]::Delete($path, $true) } catch {
    try { cmd /c "rmdir /s /q `"$path`"" | Out-Null } catch {}
  }
  Remove-Item -LiteralPath $empty -Recurse -Force -ErrorAction SilentlyContinue
  return -not (Test-Path -LiteralPath $path)
}

# Resolve via junction so this works whether data is on C: or D:
$sandboxRoot = 'C:\Users\ahazan\.local\state\ai-devops\review-sandboxes'
$worktreeRoot = 'C:\Users\ahazan\.codex\worktrees'
$archiveRoot = 'C:\Users\ahazan\.codex\archived_sessions'
$codexRoot = 'C:\Users\ahazan\.codex'
$preserveWorktrees = @(
  'ai-devops-pr666-resume','issue-2371-owner-decision-evidence','issue-2662-six-views-01a0bc14',
  'issue-2876-catalog-row-order-refresh-01a0bc4c','issue-3273-resume-01a0bc4c','issue-634-shared-db-rename'
)

Log "housekeeping start"

# 1) Review sandboxes older than 24 hours (explicitly disposable snapshots)
if (Test-Path -LiteralPath $sandboxRoot) {
  $cutoff = (Get-Date).AddHours(-24)
  $old = @(Get-ChildItem -LiteralPath $sandboxRoot -Force -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt $cutoff })
  $n = 0
  foreach ($d in $old) {
    if ($d.Parent.FullName -ne (Get-Item -LiteralPath $sandboxRoot).FullName) { continue }
    if (Wipe-Dir $d.FullName) { $n++ }
  }
  Log "review-sandboxes removed=$n of $($old.Count) older than 24h"
}

# 2) Worktree groups older than 7 days that are not on the preserve list
if (Test-Path -LiteralPath $worktreeRoot) {
  $cutoff = (Get-Date).AddDays(-7)
  $old = @(Get-ChildItem -LiteralPath $worktreeRoot -Force -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt $cutoff -and $preserveWorktrees -notcontains $_.Name })
  $n = 0
  foreach ($d in $old) {
    if ($d.Parent.FullName -ne (Get-Item -LiteralPath $worktreeRoot).FullName) { continue }
    # Skip if dirty (has modified files)
    $inner = Get-ChildItem $d.FullName -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($inner -and (Test-Path (Join-Path $inner.FullName '.git'))) {
      $st = & git -C $inner.FullName status --porcelain 2>$null
      if ($st) { Log "SKIP dirty worktree $($d.Name)"; continue }
    }
    if (Wipe-Dir $d.FullName) { $n++ }
  }
  Log "worktrees removed=$n of $($old.Count) older than 7d (non-preserve)"
}

# 3) Archived sessions older than 14 days
if (Test-Path -LiteralPath $archiveRoot) {
  $cutoff = (Get-Date).AddDays(-14)
  $old = @(Get-ChildItem -LiteralPath $archiveRoot -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt $cutoff })
  $n = 0
  foreach ($d in $old) {
    try {
      if ($d.PSIsContainer) { if (Wipe-Dir $d.FullName) { $n++ } }
      else { Remove-Item -LiteralPath $d.FullName -Force -ErrorAction Stop; $n++ }
    } catch {}
  }
  Log "archived-sessions removed=$n of $($old.Count)"
}

# 4) Codex root temp/backup debris older than 7 days (never live auth/config)
$debris = @(Get-ChildItem -LiteralPath $codexRoot -Force -File -ErrorAction SilentlyContinue | Where-Object {
  ($_.Name -match '\.bak$|\.bak-|\.tmp-|^tmp-|^..codex-global-state\.json\.') -and
  $_.LastWriteTime -lt (Get-Date).AddDays(-7) -and
  $_.Name -notmatch 'auth|secret|config\.toml$'
})
$n = 0
foreach ($f in $debris) {
  try { Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop; $n++ } catch {}
}
Log "codex-root debris removed=$n"

# 5) Stale gemini live folders older than 3 days
$stateAi = 'C:\Users\ahazan\.local\state\ai-devops'
if (Test-Path -LiteralPath $stateAi) {
  $old = @(Get-ChildItem -LiteralPath $stateAi -Force -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^gemini-live-|^gemini-tracked-review' -and $_.LastWriteTime -lt (Get-Date).AddDays(-3) })
  $n = 0
  foreach ($d in $old) { if (Wipe-Dir $d.FullName) { $n++ } }
  Log "stale-gemini-folders removed=$n"
}

$free = [math]::Round((Get-PSDrive C).Free/1GB,1)
$freeD = [math]::Round((Get-PSDrive D).Free/1GB,1)
Log "housekeeping done C_free=${free}GB D_free=${freeD}GB"
