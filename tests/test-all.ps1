$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
$bash = if ($IsWindows) { 'C:\Program Files\Git\bin\bash.exe' } else { (Get-Command bash).Source }
$pwsh = (Get-Command pwsh).Source
$failures = 0
$timings = [System.Collections.Generic.List[object]]::new()

Write-Host '===== COMPLETE OFFLINE BASH SUITE ====='
$started = Get-Date
& $bash (Join-Path $PSScriptRoot 'test-all.sh')
if ($LASTEXITCODE -ne 0) { $failures++ }
$elapsed = [int]((Get-Date) - $started).TotalSeconds
$timings.Add([pscustomobject]@{ Seconds = $elapsed; Suite = 'test-all.sh (complete Bash suite)' })
Write-Host "----- BASH SUITE took ${elapsed}s -----"

$tests = @(Get-ChildItem -LiteralPath $PSScriptRoot -File -Filter 'test-*.ps1' |
  Where-Object Name -ne 'test-all.ps1' | Sort-Object Name)
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

Write-Host "`nOFFLINE COMPLETE SUMMARY bash=1 powershell=$($tests.Count) failures=$failures"
if ($failures -ne 0) { exit 1 }
exit 0
