<#
.SYNOPSIS
  Run the offline PowerShell suites concurrently on this machine.

.DESCRIPTION
  tests/test-all.ps1 runs the PowerShell suites one at a time after the whole
  Bash suite. This runner runs only the PowerShell suites, in parallel, each in
  its own pwsh process with its own uniquely named log.

  It changes nothing about the suites: same scripts, same assertions, same exit
  codes. Only the scheduling differs.
#>
[CmdletBinding()]
param(
  [int]$Jobs = 0,
  [string]$Pattern = 'test-*.ps1',
  [string]$LogDir = '',
  [switch]$List
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

if ($Jobs -le 0) {
  $cpus = [Environment]::ProcessorCount
  $Jobs = [Math]::Max(1, [Math]::Min(8, [int]($cpus / 4)))
}

if (-not $LogDir) {
  $stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
  $LogDir = Join-Path $root ".test-logs/pwsh-$stamp-$PID"
}
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

$suites = @(Get-ChildItem -LiteralPath $PSScriptRoot -File -Filter $Pattern |
  Where-Object { $_.Name -ne 'test-all.ps1' -and $_.Name -ne 'run-parallel.ps1' } |
  Sort-Object Name)

if ($suites.Count -eq 0) { Write-Error 'run-parallel: no suites matched'; exit 2 }

if ($List) { $suites | ForEach-Object { $_.Name }; exit 0 }

Write-Host "run-parallel: $($suites.Count) suites, $Jobs workers, logs in $LogDir`n"

$pwshPath = (Get-Command pwsh).Source
$started = Get-Date
$results = @{}

$jobsList = @()
foreach ($suite in $suites) {
  while ($jobsList.Count -ge $Jobs) {
    $done = Wait-Job -Job $jobsList -Any
    $jobsList = @($jobsList | Where-Object { $_.Id -ne $done.Id })
    $r = Receive-Job -Job $done
    $results[$r.Name] = $r
    Remove-Job -Job $done
    if ($r.Code -eq 0) { Write-Host ("  pass  {0,-46} {1,4}s" -f $r.Name, $r.Seconds) }
    else { Write-Host ("  FAIL  {0,-46} {1,4}s  rc={2}" -f $r.Name, $r.Seconds, $r.Code) }
  }
  $jobsList += Start-Job -ScriptBlock {
    param($pwshPath, $full, $name, $log)
    $t0 = Get-Date
    & $pwshPath -NoProfile -File $full *> $log
    $code = $LASTEXITCODE
    [pscustomobject]@{
      Name    = $name
      Code    = $code
      Seconds = [int]((Get-Date) - $t0).TotalSeconds
      Log     = $log
    }
  } -ArgumentList $pwshPath, $suite.FullName, $suite.Name, (Join-Path $LogDir "$($suite.Name).log")
}

while ($jobsList.Count -gt 0) {
  $done = Wait-Job -Job $jobsList -Any
  $jobsList = @($jobsList | Where-Object { $_.Id -ne $done.Id })
  $r = Receive-Job -Job $done
  $results[$r.Name] = $r
  Remove-Job -Job $done
  if ($r.Code -eq 0) { Write-Host ("  pass  {0,-46} {1,4}s" -f $r.Name, $r.Seconds) }
  else { Write-Host ("  FAIL  {0,-46} {1,4}s  rc={2}" -f $r.Name, $r.Seconds, $r.Code) }
}

$wall = [int]((Get-Date) - $started).TotalSeconds
$serial = ($results.Values | Measure-Object -Property Seconds -Sum).Sum
$failed = @($results.Values | Where-Object { $_.Code -ne 0 })

$failed | ForEach-Object { $_.Name } | Set-Content -LiteralPath (Join-Path $LogDir 'failed.txt')

Write-Host ""
Write-Host ("PARALLEL POWERSHELL SUMMARY tests={0} failures={1} wall={2}s serial-equivalent={3}s workers={4}" -f `
  $results.Count, $failed.Count, $wall, $serial, $Jobs)

if ($failed.Count -gt 0) {
  Write-Host "`nFailing suites - read the log, do not assume flake:"
  foreach ($f in $failed) { Write-Host ("  {0}`n    {1}" -f $f.Name, $f.Log) }
  exit 1
}
exit 0
