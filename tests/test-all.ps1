$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
$bash = if ($IsWindows) { 'C:\Program Files\Git\bin\bash.exe' } else { (Get-Command bash).Source }
$failures = 0

Write-Host '===== COMPLETE OFFLINE BASH SUITE ====='
& $bash (Join-Path $PSScriptRoot 'test-all.sh')
if ($LASTEXITCODE -ne 0) { $failures++ }

$tests = @(Get-ChildItem -LiteralPath $PSScriptRoot -File -Filter 'test-*.ps1' |
  Where-Object Name -ne 'test-all.ps1' | Sort-Object Name)
foreach ($test in $tests) {
  Write-Host "`n===== POWERSHELL $($test.Name) ====="
  try { & $test.FullName; if ($LASTEXITCODE -ne 0) { $failures++ } }
  catch { Write-Error $_; $failures++ }
}
Write-Host "`nOFFLINE COMPLETE SUMMARY bash=1 powershell=$($tests.Count) failures=$failures"
if ($failures -ne 0) { exit 1 }
exit 0
