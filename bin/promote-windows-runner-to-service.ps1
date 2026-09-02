#Requires -RunAsAdministrator
<#
.SYNOPSIS
Move an existing GitHub Actions runner from a logon scheduled task to a Windows
service, without changing its name or labels.

.DESCRIPTION
A runner started by a logon scheduled task cannot join the qualified pool. Both
bin/qualify-windows-runner.ps1 and the `qualify Windows runner` workflow require
exactly one `actions.runner.*` Windows service with automatic start, because
that is what proves the host comes back by itself after a reboot with nobody
signed in. A logon task also flashes console windows at the interactive user.

A runner configured without --runasservice has no svc.cmd, so the service cannot
simply be installed: the runner has to be unconfigured and configured again in
service mode. This script does that with the same name, labels and work folder,
so the host keeps its identity in the pool.

Registration and removal tokens are fetched from GitHub at use time with the
already-authenticated gh CLI and are piped to config.cmd on standard input. They
are never written to a file, a command line, the console or the repository.

.EXAMPLE
pwsh -File bin\promote-windows-runner-to-service.ps1
#>
[CmdletBinding()]
param(
  [string]$RunnerPath = 'C:\actions-runner',
  [string]$Repository = 'popcre/ai-devops',
  [string]$TaskNamePattern = 'GitHubActionsRunner*',
  [string]$ServiceAccount = 'NT AUTHORITY\NETWORK SERVICE'
)

$ErrorActionPreference = 'Stop'

$runnerFile = Join-Path $RunnerPath '.runner'
if (-not (Test-Path -LiteralPath $runnerFile -PathType Leaf)) {
  throw "No configured runner at $RunnerPath."
}
$runnerConfig = Get-Content -Raw -LiteralPath $runnerFile | ConvertFrom-Json
$runnerName = $runnerConfig.agentName
$workFolder = if ($runnerConfig.workFolder) { $runnerConfig.workFolder } else { '_work' }
if (-not $runnerName) { throw "Could not read the runner name from $runnerFile." }

$existingService = @(Get-Service | Where-Object Name -Like 'actions.runner.*')
if ($existingService.Count -gt 1) {
  throw "Exactly one runner service is allowed per physical computer; found $($existingService.Count)."
}

$labels = (gh api "repos/$Repository/actions/runners" --jq "[.runners[]|select(.name==`"$runnerName`")|.labels[]|select(.type==`"custom`")|.name]|join(`",`")")
if ($LASTEXITCODE -ne 0) { throw 'gh could not read the runner list; authenticate gh in this elevated session first.' }
Write-Output "Reconfiguring $runnerName with custom labels: $(if ($labels) { $labels } else { '(none)' })"

foreach ($task in @(Get-ScheduledTask -TaskName $TaskNamePattern -ErrorAction SilentlyContinue)) {
  Write-Output "Removing scheduled task $($task.TaskName)."
  try { Stop-ScheduledTask -TaskName $task.TaskName -ErrorAction SilentlyContinue } catch { }
  Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false
}
foreach ($stray in @(Get-Process -Name 'Runner.Listener' -ErrorAction SilentlyContinue)) {
  Write-Output "Stopping stray listener process $($stray.Id)."
  Stop-Process -Id $stray.Id -Force
}

Push-Location $RunnerPath
try {
  if (-not (Test-Path -LiteralPath (Join-Path $RunnerPath 'svc.cmd') -PathType Leaf)) {
    Write-Output 'Unconfiguring the task-mode runner.'
    $removeToken = gh api --method POST "repos/$Repository/actions/runners/remove-token" --jq .token
    if ($LASTEXITCODE -ne 0 -or -not $removeToken) { throw 'Could not obtain a runner removal token.' }
    $removeToken | & .\config.cmd remove
    $removeToken = $null
    if (Test-Path -LiteralPath $runnerFile -PathType Leaf) { throw 'The runner is still configured after config.cmd remove.' }

    Write-Output 'Configuring the runner in service mode.'
    $registrationToken = gh api --method POST "repos/$Repository/actions/runners/registration-token" --jq .token
    if ($LASTEXITCODE -ne 0 -or -not $registrationToken) { throw 'Could not obtain a runner registration token.' }
    $arguments = @(
      '--url', "https://github.com/$Repository",
      '--name', $runnerName,
      '--work', $workFolder,
      '--replace',
      '--runasservice',
      '--windowslogonaccount', $ServiceAccount
    )
    if ($labels) { $arguments += @('--labels', $labels) }
    # The token is the only answer config.cmd still needs, then a blank line
    # accepts the default runner group. It travels on standard input only.
    "$registrationToken`n`n" | & .\config.cmd @arguments
    $registrationToken = $null
    if ($LASTEXITCODE -ne 0) { throw "config.cmd failed with exit code $LASTEXITCODE." }
  }

  & .\svc.cmd start
} finally {
  Pop-Location
}

$service = @(Get-Service | Where-Object Name -Like 'actions.runner.*')
if ($service.Count -ne 1) { throw "Exactly one runner service is required; found $($service.Count)." }
$config = Get-CimInstance Win32_Service -Filter "Name='$($service[0].Name)'"
if ($config.StartMode -ne 'Auto') {
  Set-Service -Name $service[0].Name -StartupType Automatic
  $config = Get-CimInstance Win32_Service -Filter "Name='$($service[0].Name)'"
}
$service = Get-Service -Name $service[0].Name
if ($service.Status -ne 'Running') { throw "Runner service $($service.Name) is not running." }

$missing = @()
foreach ($tool in @('git', 'gh', 'jq', 'pwsh', 'node', 'python')) {
  $found = Get-Command $tool -ErrorAction SilentlyContinue
  if (-not $found -or $found.Source -like '*\Users\*') { $missing += $tool }
}
if ($missing.Count -gt 0) {
  Write-Warning "Not installed machine-wide, so the runner service account cannot see it: $($missing -join ', '). Install for all users before qualifying this host."
}

"PASS: $($service.Name) is running as a service with StartMode $($config.StartMode) under $($config.StartName)"
