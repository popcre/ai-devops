param(
  [switch]$WindowsPullRequest,
  [switch]$ExcludeReviewerSafety,
  # Ordinary pull-request Windows verification is divided into declared,
  # balanced sections that run on independent hosted machines (issue #210).
  # Without WindowsPullRequest, sections partition the complete Bash inventory.
  # No-argument runs remain the complete serial backstop.
  [string]$Shard = ''
)

$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
$bash = if ($IsWindows) { 'C:\Program Files\Git\bin\bash.exe' } else { (Get-Command bash).Source }
$pwsh = (Get-Command pwsh).Source
$failures = 0
$timings = [System.Collections.Generic.List[object]]::new()
$sharedRuntimeLock = $env:AI_TEST_SHARED_RUNTIME_LOCK
$sharedRuntimeLockHeld = $false
if ($sharedRuntimeLock) {
  try {
    New-Item -ItemType Directory -Path $sharedRuntimeLock -ErrorAction Stop | Out-Null
    $sharedRuntimeLockHeld = $true
  } catch {
    if (Test-Path -LiteralPath $sharedRuntimeLock -PathType Container) {
      Write-Error "test-all.ps1: shared installed runtime is already in use: $sharedRuntimeLock"
      exit 3
    }
    Write-Error "test-all.ps1: shared-runtime lock cannot be created safely: $sharedRuntimeLock"
    exit 4
  }
  Remove-Item Env:AI_TEST_SHARED_RUNTIME_LOCK -ErrorAction SilentlyContinue
}

try {

if ($ExcludeReviewerSafety -and -not $WindowsPullRequest) {
  throw '-ExcludeReviewerSafety requires -WindowsPullRequest.'
}
if ($Shard -and $WindowsPullRequest -and -not $ExcludeReviewerSafety) {
  throw 'Windows -Shard requires -ExcludeReviewerSafety.'
}
$shardIndex = 0
$shardTotal = 0
if ($PSBoundParameters.ContainsKey('Shard')) {
  if ($Shard -notmatch '^([0-9]{1,9})/([0-9]{1,9})$') { throw "-Shard must be <i>/<n>, got $Shard." }
  $shardIndex = [int]$Matches[1]
  $shardTotal = [int]$Matches[2]
  if ($shardTotal -lt 1) { throw "-Shard count must be at least 1, got $shardTotal." }
  if ($shardIndex -lt 1 -or $shardIndex -gt $shardTotal) {
    throw "-Shard index $shardIndex is outside 1..$shardTotal."
  }
}

# Validate PowerShell ownership before starting any Bash or PowerShell suite.
$runPowerShell = $true
if ($Shard) {
  $manifestPath = if ($env:AI_CI_SUITE_MANIFEST) { $env:AI_CI_SUITE_MANIFEST }
                  else { Join-Path $root 'config/ci-suite-manifest.json' }
  if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Windows suite manifest is missing: $manifestPath"
  }
  $owner = (Get-Content -Raw -LiteralPath $manifestPath -ErrorAction Stop |
    ConvertFrom-Json -ErrorAction Stop).windows_offline_powershell_shard
  if ($null -eq $owner -or [string]$owner -notmatch '^[0-9]{1,9}$') {
    throw 'Windows suite manifest does not declare a valid windows_offline_powershell_shard.'
  }
  $owner = [int]$owner
  if ($owner -lt 1 -or $owner -gt $shardTotal) {
    throw "windows_offline_powershell_shard $owner is outside 1..$shardTotal."
  }
  $runPowerShell = ($owner -eq $shardIndex)
}

$bashScope = if ($WindowsPullRequest) { 'WINDOWS-SENSITIVE' } else { 'COMPLETE' }
if ($Shard) { $bashScope = "$bashScope SECTION $shardIndex/$shardTotal" }
Write-Host "===== $bashScope OFFLINE BASH SUITE ====="
$started = Get-Date
$bashArgs = @((Join-Path $PSScriptRoot 'test-all.sh'))
if ($WindowsPullRequest) { $bashArgs += '--windows-offline' }
if ($ExcludeReviewerSafety) {
  if (-not $WindowsPullRequest) { throw '-ExcludeReviewerSafety requires -WindowsPullRequest.' }
  $bashArgs += '--exclude-reviewer-safety'
}
if ($Shard) { $bashArgs += @('--shard', $Shard) }
if ($Shard) {
  # Validate the complete selection before either language executes a suite.
  # The existing selector owns both dynamic inventory and declared PR coverage.
  $selectionProof = & $bash @bashArgs --list 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "Bash section selection is invalid: $($selectionProof -join [Environment]::NewLine)"
  }
}
& $bash @bashArgs
if ($LASTEXITCODE -ne 0) { $failures++ }
$elapsed = [int]((Get-Date) - $started).TotalSeconds
$timings.Add([pscustomobject]@{ Seconds = $elapsed; Suite = "test-all.sh ($($bashScope.ToLowerInvariant()) Bash suite)" })
Write-Host "----- BASH SUITE took ${elapsed}s -----"

if ($Shard -and -not $runPowerShell) {
    Write-Host "`nPOWERSHELL SUITES run in section $owner of $shardTotal; section $shardIndex skips them by declaration."
}

$tests = @()
if ($runPowerShell) {
  $tests = @(Get-ChildItem -LiteralPath $PSScriptRoot -File -Filter 'test-*.ps1' |
    Where-Object Name -ne 'test-all.ps1' | Sort-Object Name)
  # Suspended suites drop out before running (Kimi CI suspension, 2026-09-17).
  # Declared in the manifest next to the Bash suspension list; the file stays
  # for direct runs and returns when its entry is removed.
  $manifestPath = if ($env:AI_CI_SUITE_MANIFEST) { $env:AI_CI_SUITE_MANIFEST }
                  else { Join-Path $root 'config/ci-suite-manifest.json' }
  if (Test-Path -LiteralPath $manifestPath) {
    $manifest = Get-Content -Raw -LiteralPath $manifestPath -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    if ($null -ne $manifest.suspended_powershell) {
      $suspended = @($manifest.suspended_powershell | ForEach-Object { [string]$_ })
      foreach ($name in $suspended) {
        if ($tests.Name -contains $name) {
          $tests = @($tests | Where-Object Name -ne $name)
          Write-Host "test-all.ps1: suspended suite skipped: $name"
        } else {
          Write-Warning "test-all.ps1: suspended_powershell names a suite not on disk: $name"
        }
      }
    }
  }
}
foreach ($test in $tests) {
  Write-Host "`n===== POWERSHELL $($test.Name) ====="
  $started = Get-Date
  try { & $pwsh -NoProfile -File $test.FullName; if ($LASTEXITCODE -ne 0) { $failures++ } }
  catch { Write-Error $_; $failures++ }
  $elapsed = [int]((Get-Date) - $started).TotalSeconds
  $timings.Add([pscustomobject]@{ Seconds = $elapsed; Suite = $test.Name })
  Write-Host "----- POWERSHELL $($test.Name) took ${elapsed}s -----"
}

Write-Host "`nWINDOWS SUITE TIMINGS slowest-first"
$timings | Sort-Object Seconds -Descending |
  ForEach-Object { Write-Host ("{0,6} {1}" -f $_.Seconds, $_.Suite) }

$bashSummaryScope = $bashScope.ToLowerInvariant()
if ($Shard) {
  Write-Host "`nOFFLINE WINDOWS SECTION SUMMARY section=$shardIndex of $shardTotal bash=1 powershell=$($tests.Count) failures=$failures"
}
Write-Host "`nOFFLINE COMPLETE SUMMARY bash=1 bash_scope=$bashSummaryScope powershell=$($tests.Count) failures=$failures"
if ($failures -ne 0) { exit 1 }
exit 0
} finally {
  if ($sharedRuntimeLockHeld) {
    Remove-Item -LiteralPath $sharedRuntimeLock -Force -ErrorAction SilentlyContinue
  }
}
