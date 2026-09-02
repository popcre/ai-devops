#Requires -RunAsAdministrator
<#
.SYNOPSIS
Convert a scheduled-task GitHub Actions runner into a Windows service.

.DESCRIPTION
A runner started by a logon scheduled task is not eligible for the qualified
pool. Both bin/qualify-windows-runner.ps1 and the `qualify Windows runner`
workflow require exactly one `actions.runner.*` Windows service with automatic
start, because that is what proves the host comes back by itself after a reboot
with nobody logged in. A logon task also flashes console windows at the
interactive user.

This script is idempotent: it stops and removes the runner scheduled tasks,
installs the runner service from the runner directory, starts it, and then
proves the result. It changes nothing about the runner's registration, so the
host keeps its name and labels.
#>
[CmdletBinding()]
param(
  [string]$RunnerPath = 'C:\actions-runner',
  [string]$TaskNamePattern = 'GitHubActionsRunner*'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath (Join-Path $RunnerPath '.runner') -PathType Leaf)) {
  throw "No configured runner at $RunnerPath. Configure the runner first; this script only changes how it starts."
}
$serviceScript = Join-Path $RunnerPath 'svc.cmd'
if (-not (Test-Path -LiteralPath $serviceScript -PathType Leaf)) {
  throw "The runner at $RunnerPath has no svc.cmd; it was not configured by config.cmd."
}

foreach ($task in @(Get-ScheduledTask -TaskName $TaskNamePattern -ErrorAction SilentlyContinue)) {
  Write-Output "Removing scheduled task $($task.TaskName)."
  try { Stop-ScheduledTask -TaskName $task.TaskName -ErrorAction SilentlyContinue } catch { }
  Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false
}

foreach ($stray in @(Get-Process -Name 'Runner.Listener' -ErrorAction SilentlyContinue)) {
  Write-Output "Stopping stray listener process $($stray.Id)."
  Stop-Process -Id $stray.Id -Force
}

$existing = @(Get-Service | Where-Object Name -Like 'actions.runner.*')
if ($existing.Count -eq 0) {
  Write-Output 'Installing the runner service.'
  & $serviceScript install
  if ($LASTEXITCODE -ne 0) { throw "svc.cmd install failed with exit code $LASTEXITCODE." }
}

& $serviceScript start
if ($LASTEXITCODE -ne 0) { throw "svc.cmd start failed with exit code $LASTEXITCODE." }

$service = @(Get-Service | Where-Object Name -Like 'actions.runner.*')
if ($service.Count -ne 1) { throw "Exactly one runner service is required; found $($service.Count)." }
$config = Get-CimInstance Win32_Service -Filter "Name='$($service[0].Name)'"
if ($config.StartMode -ne 'Auto') {
  Set-Service -Name $service[0].Name -StartupType Automatic
  $config = Get-CimInstance Win32_Service -Filter "Name='$($service[0].Name)'"
}
if ($service[0].Status -ne 'Running') { throw "Runner service $($service[0].Name) is not running." }

$missing = @()
foreach ($tool in @('git', 'gh', 'jq', 'pwsh', 'node', 'python')) {
  $found = Get-Command $tool -ErrorAction SilentlyContinue
  if (-not $found -or $found.Source -like 'C:\Users\*') { $missing += $tool }
}
if ($missing.Count -gt 0) {
  Write-Warning "Not visible machine-wide, so the service account cannot see it: $($missing -join ', '). Install it for all users before qualifying this host."
}

"PASS: $($service[0].Name) is running as a service with StartMode $($config.StartMode) under $($config.StartName)"
