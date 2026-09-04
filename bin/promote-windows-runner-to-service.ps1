#Requires -RunAsAdministrator
<#
.SYNOPSIS
Make this computer's GitHub Actions runner a Windows service with automatic
start, from whatever state it is in now.

.DESCRIPTION
A runner that is started by a logon scheduled task, or that is left half
unconfigured, cannot join the qualified pool. bin/qualify-windows-runner.ps1 and
the qualification workflow both require exactly one actions.runner.* Windows
service with automatic start, because that is what proves the host comes back on
its own after a reboot with nobody signed in.

This script takes the host from any of these states to that one:

  * a runner started by a logon scheduled task, configured without
    --runasservice, so there is no svc.cmd to install a service with;
  * a configured service runner that is merely stopped or set to manual start;
  * a wrecked runner - service registered but stopped, and .runner,
    .credentials and svc.cmd deleted - which is where edge-dev was left on
    2026-09-02 after a reconfigure was interrupted.

It is safe to run twice. A runner that is already a running service with
automatic start is left alone.

Registration and removal tokens are requested from GitHub through the
already-authenticated gh CLI while the script runs. The removal token goes to
config.cmd on standard input. The registration token cannot: config.cmd reads it
with a masked console read that fails when standard input is redirected, so
--unattended --token is the only route the runner offers. That token is minted
seconds before use, is single-purpose, and expires within the hour. Neither token
is ever written to a log, a transcript, or the repository.

.EXAMPLE
pwsh -File bin\promote-windows-runner-to-service.ps1
#>
[CmdletBinding()]
param(
  [string]$RunnerPath = 'C:\actions-runner',
  [string]$Repository = 'popcre/ai-devops',
  [string]$RunnerName = 'edge-dev-win',
  [string]$Labels = 'edge-dev,ai-devops-windows',
  [string]$TaskNamePattern = 'GitHubActionsRunner*'
)

$ErrorActionPreference = 'Stop'

function Get-RunnerService {
  @(Get-Service | Where-Object Name -Like 'actions.runner.*')
}

if (-not (Test-Path -LiteralPath (Join-Path $RunnerPath 'config.cmd') -PathType Leaf)) {
  throw "No runner installation at $RunnerPath."
}
$runnerFile = Join-Path $RunnerPath '.runner'
$serviceInstaller = Join-Path $RunnerPath 'svc.cmd'

# A runner that is still configured tells us its own name and work folder, which
# are what the pool knows it by. Only fall back to the parameters when it cannot.
if (Test-Path -LiteralPath $runnerFile -PathType Leaf) {
  $runnerConfig = Get-Content -Raw -LiteralPath $runnerFile | ConvertFrom-Json
  if ($runnerConfig.agentName) { $RunnerName = $runnerConfig.agentName }
  $workFolder = if ($runnerConfig.workFolder) { $runnerConfig.workFolder } else { '_work' }
} else {
  $workFolder = '_work'
}

# Filter in PowerShell rather than in a --jq expression. Embedded quotes in a
# jq filter do not survive PowerShell native argument passing; they reach gh as
# backslash-escaped quotes and jq rejects them.
$runnerList = gh api "repos/$Repository/actions/runners" | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw 'gh could not read the runner list; sign gh in inside this elevated session first.' }
$registered = @($runnerList.runners | Where-Object { $_.name -eq $RunnerName })[0]
if ($registered) {
  $remoteLabels = ($registered.labels | Where-Object type -eq 'custom' | ForEach-Object name) -join ','
  if ($remoteLabels) { $Labels = $remoteLabels }
}

$services = Get-RunnerService
if ($services.Count -gt 1) {
  throw "Exactly one runner service is allowed per physical computer; found $($services.Count)."
}

$healthy = $services.Count -eq 1 -and (Test-Path -LiteralPath $runnerFile -PathType Leaf) -and (Test-Path -LiteralPath $serviceInstaller -PathType Leaf)
if (-not $healthy) {
  Write-Output "Rebuilding the runner registration for $RunnerName with labels: $Labels"

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
    if (Test-Path -LiteralPath $runnerFile -PathType Leaf) {
      Write-Output 'Unconfiguring the existing runner.'
      $removeToken = gh api --method POST "repos/$Repository/actions/runners/remove-token" --jq .token
      if ($LASTEXITCODE -ne 0 -or -not $removeToken) { throw 'Could not obtain a runner removal token.' }
      $removeToken | & .\config.cmd remove
      $removeToken = $null
      if (Test-Path -LiteralPath $runnerFile -PathType Leaf) { throw 'The runner is still configured after config.cmd remove.' }
    } elseif ($registered) {
      # The local credentials are gone, so config.cmd remove cannot authenticate.
      # Drop the stale registration from GitHub instead.
      Write-Output "Deleting the stale GitHub registration for $RunnerName."
      gh api --method DELETE "repos/$Repository/actions/runners/$($registered.id)" | Out-Null
      if ($LASTEXITCODE -ne 0) { throw 'Could not delete the stale runner registration.' }
    }

    # A service left behind by an interrupted reconfigure would fail the
    # "exactly one service" check, and config.cmd cannot install over it.
    foreach ($service in Get-RunnerService) {
      Write-Output "Deleting the leftover service $($service.Name)."
      if ($service.Status -ne 'Stopped') { Stop-Service -Name $service.Name -Force }
      & sc.exe delete $service.Name | Out-Null
    }
    Remove-Item -LiteralPath (Join-Path $RunnerPath '.service') -Force -ErrorAction SilentlyContinue

    Write-Output 'Configuring the runner in service mode.'
    $registrationToken = gh api --method POST "repos/$Repository/actions/runners/registration-token" --jq .token
    if ($LASTEXITCODE -ne 0 -or -not $registrationToken) { throw 'Could not obtain a runner registration token.' }
    # config.cmd reads the token with a masked console read, which fails outright
    # when standard input is redirected ("Cannot read keys when either application
    # does not have a console or when console input has been redirected"). So a
    # pipe cannot be used and --unattended --token is the only route the runner
    # offers. The token is a registration token minted seconds earlier by gh, is
    # single-purpose, and expires within the hour; it is visible only in this
    # elevated process's own command line and never reaches a log, a transcript
    # or the repository.
    $arguments = @(
      '--url', "https://github.com/$Repository",
      '--name', $RunnerName,
      '--labels', $Labels,
      '--work', $workFolder,
      '--replace',
      '--unattended',
      '--runasservice',
      '--token', $registrationToken
    )
    & .\config.cmd @arguments
    $registrationToken = $null
    if ($LASTEXITCODE -ne 0) { throw "config.cmd failed with exit code $LASTEXITCODE." }
  } finally {
    Pop-Location
  }
}

$services = Get-RunnerService
if ($services.Count -ne 1) { throw "Exactly one runner service is required; found $($services.Count)." }
$serviceName = $services[0].Name
$config = Get-CimInstance Win32_Service -Filter "Name='$serviceName'"
if ($config.StartMode -ne 'Auto') {
  Set-Service -Name $serviceName -StartupType Automatic
  $config = Get-CimInstance Win32_Service -Filter "Name='$serviceName'"
}
if ((Get-Service -Name $serviceName).Status -ne 'Running') { Start-Service -Name $serviceName }
$service = Get-Service -Name $serviceName
if ($service.Status -ne 'Running') { throw "Runner service $serviceName is not running." }

$missing = @()
foreach ($tool in @('git', 'gh', 'jq', 'pwsh', 'node', 'python')) {
  $found = Get-Command $tool -ErrorAction SilentlyContinue
  if (-not $found -or $found.Source -like '*\Users\*') { $missing += $tool }
}
if ($missing.Count -gt 0) {
  Write-Warning "Not installed machine-wide, so the runner service account cannot see it: $($missing -join ', '). Install for all users before qualifying this host."
}

"PASS: $serviceName is running as a service with StartMode $($config.StartMode) under $($config.StartName)"
