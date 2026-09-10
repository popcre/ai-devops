param(
  [switch]$WindowsPullRequest,
  [switch]$ExcludeReviewerSafety,
  # Ordinary pull-request Windows verification is divided into declared,
  # balanced sections that run on independent hosted machines (issue #210).
  # Scheduled, manual, qualification and no-argument runs pass no section and
  # remain the complete backstop.
  [string]$Shard = ''
)

$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
$bash = if ($IsWindows) { 'C:\Program Files\Git\bin\bash.exe' } else { (Get-Command bash).Source }
$pwsh = (Get-Command pwsh).Source
$failures = 0
$timings = [System.Collections.Generic.List[object]]::new()

if ($Shard -and -not ($WindowsPullRequest -and $ExcludeReviewerSafety)) {
  throw '-Shard requires -WindowsPullRequest -ExcludeReviewerSafety.'
}
$shardIndex = 0
$shardTotal = 0
if ($Shard) {
  if ($Shard -notmatch '^([0-9]+)/([0-9]+)$') { throw "-Shard must be <i>/<n>, got $Shard." }
  $shardIndex = [int]$Matches[1]
  $shardTotal = [int]$Matches[2]
  if ($shardTotal -lt 1) { throw "-Shard count must be at least 1, got $shardTotal." }
  if ($shardIndex -lt 1 -or $shardIndex -gt $shardTotal) {
    throw "-Shard index $shardIndex is outside 1..$shardTotal."
  }
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
& $bash @bashArgs
if ($LASTEXITCODE -ne 0) { $failures++ }
$elapsed = [int]((Get-Date) - $started).TotalSeconds
$timings.Add([pscustomobject]@{ Seconds = $elapsed; Suite = "test-all.sh ($($bashScope.ToLowerInvariant()) Bash suite)" })
Write-Host "----- BASH SUITE took ${elapsed}s -----"

$runPowerShell = $true
if ($Shard) {
  $manifestPath = if ($env:AI_CI_SUITE_MANIFEST) { $env:AI_CI_SUITE_MANIFEST }
                  else { Join-Path $root 'config/ci-suite-manifest.json' }
  if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Windows suite manifest is missing: $manifestPath"
  }
  $owner = (Get-Content -Raw -LiteralPath $manifestPath |
    ConvertFrom-Json).windows_offline_powershell_shard
  if ($null -eq $owner) {
    throw 'Windows suite manifest does not declare windows_offline_powershell_shard.'
  }
  $owner = [int]$owner
  if ($owner -lt 1 -or $owner -gt $shardTotal) {
    throw "windows_offline_powershell_shard $owner is outside 1..$shardTotal."
  }
  $runPowerShell = ($owner -eq $shardIndex)
  if (-not $runPowerShell) {
    Write-Host "`nPOWERSHELL SUITES run in section $owner of $shardTotal; section $shardIndex skips them by declaration."
  }
}

$tests = @()
if ($runPowerShell) {
  $tests = @(Get-ChildItem -LiteralPath $PSScriptRoot -File -Filter 'test-*.ps1' |
    Where-Object Name -ne 'test-all.ps1' | Sort-Object Name)
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
