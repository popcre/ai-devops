# Daily housekeeping: disposable AI review sandboxes, old archives, temp debris.
# Safe targets only. Never touches live repos, secrets, recent work (<24h), or a
# review snapshot whose owner run is still alive (lease beside the snapshot).
param(
  [string]$SandboxRoot = 'C:\Users\ahazan\.local\state\ai-devops\review-sandboxes',
  [string]$WorktreeRoot = 'C:\Users\ahazan\.codex\worktrees',
  [string]$ArchiveRoot = 'C:\Users\ahazan\.codex\archived_sessions',
  [string]$CodexRoot = 'C:\Users\ahazan\.codex',
  [switch]$SkipNonSandbox
)
$ErrorActionPreference = 'Continue'
$log = 'D:\ai-data\logs\housekeeping.log'
if ($env:AI_HOUSEKEEPING_LOG) { $log = $env:AI_HOUSEKEEPING_LOG }
function Log($m) {
  $line = "[{0}] {1}" -f (Get-Date -Format o), $m
  Add-Content -LiteralPath $log -Value $line -ErrorAction SilentlyContinue
  Write-Output $line
}
function Test-SandboxLiveOwner([string]$sandboxPath) {
  # Mirror bin/ai-review-sandbox has-live-owner exactly: lease files name MSYS
  # pids and carry /proc start times, so only that helper can judge liveness
  # correctly. A live lease means the creating run still owns this snapshot.
  $leases = "$sandboxPath.leases"
  if (-not (Test-Path -LiteralPath $leases)) { return $false }
  $tool = $null
  foreach ($candidate in @(
    (Join-Path $PSScriptRoot '..\..\bin\ai-review-sandbox'),
    'C:\repos\ai-devops\bin\ai-review-sandbox',
    'D:\repos\ai-devops\bin\ai-review-sandbox'
  )) {
    if ($candidate -and (Test-Path -LiteralPath $candidate)) {
      $tool = (Resolve-Path -LiteralPath $candidate).Path
      break
    }
  }
  $bash = $null
  $bashCandidates = @()
  foreach ($root in @($env:ProgramFiles, $env:ProgramW6432, ${env:ProgramFiles(x86)}, 'C:\Program Files', 'C:\Program Files (x86)')) {
    if ($root) { $bashCandidates += (Join-Path $root 'Git\bin\bash.exe') }
  }
  $bashCandidates += @(
    "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe",
    'C:\Program Files\Git\bin\bash.exe'
  )
  foreach ($candidate in $bashCandidates) {
    if ($candidate -and (Test-Path -LiteralPath $candidate)) { $bash = $candidate; break }
  }
  if ($tool -and $bash) {
    $toolUnix = $tool -replace '\\', '/'
    $snapUnix = $sandboxPath -replace '\\', '/'
    & $bash $toolUnix has-live-owner $snapUnix 2>$null | Out-Null
    return ($LASTEXITCODE -eq 0)
  }
  # Fallback when Git Bash or the sandbox tool is missing: any live lease pid.
  foreach ($f in Get-ChildItem -LiteralPath $leases -Force -File -ErrorAction SilentlyContinue) {
    $pidNum = 0
    if (-not [int]::TryParse($f.BaseName, [ref]$pidNum)) { continue }
    if ($pidNum -le 1) { continue }
    if (Get-Process -Id $pidNum -ErrorAction SilentlyContinue) { return $true }
  }
  return $false
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
# Paths come from parameters (defaults are the machine layout).
$preserveWorktrees = @(
  'ai-devops-pr666-resume','issue-2371-owner-decision-evidence','issue-2662-six-views-01a0bc14',
  'issue-2876-catalog-row-order-refresh-01a0bc4c','issue-3273-resume-01a0bc4c','issue-634-shared-db-rename'
)

Log "housekeeping start"

# 1) Review sandboxes older than 24 hours (explicitly disposable snapshots)
if (Test-Path -LiteralPath $SandboxRoot) {
  $cutoff = (Get-Date).AddHours(-24)
  $old = @(Get-ChildItem -LiteralPath $SandboxRoot -Force -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt $cutoff -and $_.Name -notlike '*.leases' })
  $n = 0
  $skippedLive = 0
  $rootFull = (Get-Item -LiteralPath $SandboxRoot).FullName
  foreach ($d in $old) {
    if ($d.Parent.FullName -ne $rootFull) { continue }
    if (Test-SandboxLiveOwner $d.FullName) {
      Log "SKIP live-owner sandbox $($d.Name)"
      $skippedLive++
      continue
    }
    if (Wipe-Dir $d.FullName) {
      $n++
      $leasesDir = "$($d.FullName).leases"
      if (Test-Path -LiteralPath $leasesDir) { Wipe-Dir $leasesDir | Out-Null }
    }
  }
  Log "review-sandboxes removed=$n of $($old.Count) older than 24h (skipped live-owner=$skippedLive)"
}
if ($SkipNonSandbox) {
  Log "housekeeping done (sandbox-only)"
  return
}

# 2) Worktree groups older than 7 days that are not on the preserve list
if (Test-Path -LiteralPath $WorktreeRoot) {
  $cutoff = (Get-Date).AddDays(-7)
  $old = @(Get-ChildItem -LiteralPath $WorktreeRoot -Force -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt $cutoff -and $preserveWorktrees -notcontains $_.Name })
  $n = 0
  foreach ($d in $old) {
    if ($d.Parent.FullName -ne (Get-Item -LiteralPath $WorktreeRoot).FullName) { continue }
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
if (Test-Path -LiteralPath $ArchiveRoot) {
  $cutoff = (Get-Date).AddDays(-14)
  $old = @(Get-ChildItem -LiteralPath $ArchiveRoot -Force -ErrorAction SilentlyContinue |
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
$debris = @(Get-ChildItem -LiteralPath $CodexRoot -Force -File -ErrorAction SilentlyContinue | Where-Object {
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

# 6) ZCode exec session logs (runaway stdout can fill C: - issue #884)
#    Any *-stdout.log under .zcode/cli/exec older than 3 days, or larger than 50 MB.
$zExec = 'C:\Users\ahazan\.zcode\cli\exec'
if (Test-Path -LiteralPath $zExec) {
  $n = 0
  $bytes = 0L
  $cutoff = (Get-Date).AddDays(-3)
  Get-ChildItem -LiteralPath $zExec -Recurse -Force -File -Filter '*-stdout.log' -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.LastWriteTime -lt $cutoff -or $_.Length -gt 50MB) {
      try {
        $bytes += $_.Length
        Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop
        $n++
      } catch {
        # Still open - try truncate so the disk frees even if delete fails
        try {
          $fs = [System.IO.File]::Open($_.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Write, [System.IO.FileShare]::ReadWrite)
          $fs.SetLength(0); $fs.Close()
          $n++
        } catch {}
      }
    }
  }
  Log "zcode-exec-logs removed/truncated=$n bytes=$bytes"
}

# Prefer Win32_LogicalDisk: Get-PSDrive can report stale free space on Windows
$free = 0; $freeD = 0
try {
  $c = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
  if ($c) { $free = [math]::Round($c.FreeSpace/1GB,1) }
  $d = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='D:'"
  if ($d) { $freeD = [math]::Round($d.FreeSpace/1GB,1) }
} catch {
  $free = [math]::Round((Get-PSDrive C).Free/1GB,1)
  $freeD = [math]::Round((Get-PSDrive D).Free/1GB,1)
}
Log "housekeeping done C_free=${free}GB D_free=${freeD}GB"
