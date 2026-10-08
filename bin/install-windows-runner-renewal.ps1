[CmdletBinding(DefaultParameterSetName='Verify')]
param(
  [Parameter(ParameterSetName='Install')][switch]$Install,
  [Parameter(ParameterSetName='Verify')][switch]$Verify,
  [Parameter(ParameterSetName='Remove')][switch]$Remove,
  [string]$OperatorUser = "$([Environment]::MachineName)\ahazan",
  [switch]$LibraryMode
)

# Automatic renewal of the Administrator security evidence (#1312).
# Installs ONE sibling scheduled task, \AiDevOps\WindowsRunnerQualificationRenewal,
# that runs as the operator's own NON-elevated (Limited) S4U token at startup
# and every 8 hours, and does nothing but call the existing #262 client for
# its fixed `refresh-qualification` operation. It adds no elevation path: the
# only elevated code remains the hash-pinned \AiDevOps\WindowsRunnerMaintenance
# payload, which must already be installed and verify before this installs.

$ErrorActionPreference = 'Stop'
$script:RenewalTaskFolder = '\AiDevOps\'
$script:RenewalTaskFolderCom = '\AiDevOps'
$script:RenewalTaskName = 'WindowsRunnerQualificationRenewal'
$script:RenewalPayloadRoot = 'C:\Program Files\ai-devops\windows-runner-renewal'
$script:RenewalStatusRoot = 'C:\ProgramData\ai-devops\windows-runner-renewal'
$script:RenewalPowerShell = 'C:\Program Files\PowerShell\7\pwsh.exe'
$script:RenewalIntervalHours = 8
$script:RenewalStartupDelayMinutes = 5
$script:RenewalFiles = @('renew-windows-runner-qualification.ps1', 'invoke-windows-runner-maintenance.ps1')

# Dot-sourcing rebinds that script's parameters in this scope, so this
# script's own switches are captured first.
$script:RenewalMode = if ($Install) { 'Install' } elseif ($Remove) { 'Remove' } else { 'Verify' }
$script:RenewalOperatorUser = $OperatorUser
$script:RenewalLibraryMode = [bool]$LibraryMode
# Reuse the hardened #262 installer's primitives (administrator check,
# checked icacls, operator SID resolution, reparse and COM-override guards,
# and the full maintenance installation verifier).
. (Join-Path $PSScriptRoot 'install-windows-runner-maintenance.ps1') -LibraryMode

function Get-RenewalTaskArguments {
  return "-NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File `"$script:RenewalPayloadRoot\renew-windows-runner-qualification.ps1`""
}

function Get-RenewalTaskSddl {
  param([Parameter(Mandatory)][string]$OperatorSid)
  return "D:P(A;;FA;;;SY)(A;;FA;;;BA)(A;;GRGX;;;$OperatorSid)"
}

function Get-DesiredRenewalManifest {
  param([Parameter(Mandatory)][string]$SourceRoot, [Parameter(Mandatory)][string]$OperatorSid)
  $files = [ordered]@{}
  foreach ($name in $script:RenewalFiles) {
    $path = Join-Path $SourceRoot "bin\$name"
    Assert-NoReparsePoint -LiteralPath $path
    $files[$name] = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant()
  }
  return [ordered]@{ schema_version=1; owner='popcre/ai-devops#1312'; operator_sid=$OperatorSid; task_path=($script:RenewalTaskFolder + $script:RenewalTaskName); files=$files }
}

function Install-RenewalPayload {
  param([Parameter(Mandatory)][string]$SourceRoot, [Parameter(Mandatory)][string]$OperatorSid)
  $manifest = Get-DesiredRenewalManifest -SourceRoot $SourceRoot -OperatorSid $OperatorSid
  $parent = Split-Path -Parent $script:RenewalPayloadRoot
  Assert-NoReparsePoint -LiteralPath $parent
  $staging = "$script:RenewalPayloadRoot.staging"
  if (Test-Path -LiteralPath $staging) { Assert-NoReparsePoint -LiteralPath $staging; Remove-Item -LiteralPath $staging -Recurse -Force }
  New-Item -ItemType Directory -Path $staging | Out-Null
  foreach ($name in $script:RenewalFiles) { Copy-Item -LiteralPath (Join-Path $SourceRoot "bin\$name") -Destination (Join-Path $staging $name) }
  ($manifest | ConvertTo-Json -Depth 4) | Set-Content -LiteralPath (Join-Path $staging 'manifest.json') -Encoding utf8
  Set-RenewalAcl -LiteralPath $staging -OperatorSid $OperatorSid -Kind Payload
  foreach ($name in $script:RenewalFiles) {
    if ((Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $staging $name)).Hash.ToLowerInvariant() -cne [string]$manifest.files[$name]) { throw "Staged renewal payload hash mismatch: $name" }
  }
  if (Test-Path -LiteralPath $script:RenewalPayloadRoot) { Assert-NoReparsePoint -LiteralPath $script:RenewalPayloadRoot; Assert-NoForeignOwnership -LiteralPath $script:RenewalPayloadRoot; Remove-Item -LiteralPath $script:RenewalPayloadRoot -Recurse -Force }
  Move-Item -LiteralPath $staging -Destination $script:RenewalPayloadRoot
  if (-not (Test-Path -LiteralPath $script:RenewalStatusRoot)) { New-Item -ItemType Directory -Path $script:RenewalStatusRoot | Out-Null }
  Assert-NoForeignOwnership -LiteralPath $script:RenewalStatusRoot
  Set-RenewalAcl -LiteralPath $script:RenewalStatusRoot -OperatorSid $OperatorSid -Kind Status
}

function Set-RenewalAcl {
  param([Parameter(Mandatory)][string]$LiteralPath, [Parameter(Mandatory)][string]$OperatorSid, [ValidateSet('Payload','Status')][string]$Kind)
  Assert-NoReparsePoint -LiteralPath $LiteralPath
  $admins = '*S-1-5-32-544'; $system = '*S-1-5-18'
  if ($Kind -eq 'Payload') {
    Invoke-ProtectedIcacls -Arguments @($LiteralPath,'/setowner',$admins,'/T','/C')
    Invoke-ProtectedIcacls -Arguments @($LiteralPath,'/inheritance:r','/grant:r',"${admins}:(OI)(CI)F","${system}:(OI)(CI)F","*${OperatorSid}:(OI)(CI)RX",'/T','/C')
  } else {
    # The status directory is the only operator-writable location this adds;
    # it holds informational run records, never anything the CI gate reads.
    # Everyone may read it so a failed renewal is visible to any session.
    Invoke-ProtectedIcacls -Arguments @($LiteralPath,'/setowner',$admins)
    Invoke-ProtectedIcacls -Arguments @($LiteralPath,'/inheritance:r','/grant:r',"${admins}:(OI)(CI)F","${system}:(OI)(CI)F","*${OperatorSid}:(OI)(CI)M",'*S-1-5-32-545:(OI)(CI)RX')
  }
}

function Register-RenewalTask {
  param([Parameter(Mandatory)][string]$OperatorSid)
  $action = New-ScheduledTaskAction -Execute $script:RenewalPowerShell -Argument (Get-RenewalTaskArguments)
  $startup = New-ScheduledTaskTrigger -AtStartup
  $startup.Delay = 'PT{0}M' -f $script:RenewalStartupDelayMinutes
  $repeat = New-ScheduledTaskTrigger -Once -At ([DateTime]::Now.Date.AddHours(1)) -RepetitionInterval ([TimeSpan]::FromHours($script:RenewalIntervalHours))
  # Limited run level: this task holds no administrator power at all.
  $principal = New-ScheduledTaskPrincipal -UserId $OperatorSid -LogonType S4U -RunLevel Limited
  $settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::FromMinutes(10)) -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
  Register-ScheduledTask -TaskPath $script:RenewalTaskFolder -TaskName $script:RenewalTaskName -Action $action -Trigger @($startup, $repeat) -Principal $principal -Settings $settings -Force | Out-Null
  Assert-NoPerUserComOverride
  $service = New-Object -ComObject 'Schedule.Service'
  $service.Connect()
  $service.GetFolder($script:RenewalTaskFolderCom).GetTask($script:RenewalTaskName).SetSecurityDescriptor((Get-RenewalTaskSddl -OperatorSid $OperatorSid), 0)
}

function Get-RenewalTaskSnapshot {
  $task = Get-ScheduledTask -TaskPath $script:RenewalTaskFolder -TaskName $script:RenewalTaskName -ErrorAction Stop
  Assert-NoPerUserComOverride
  $service = New-Object -ComObject 'Schedule.Service'
  $service.Connect()
  $sddl = [string]$service.GetFolder($script:RenewalTaskFolderCom).GetTask($script:RenewalTaskName).GetSecurityDescriptor(0)
  if ([string]::IsNullOrWhiteSpace($sddl)) { throw 'TASK_SDDL_UNREADABLE: elevated token is required to read the task security descriptor.' }
  return [ordered]@{
    execute = [string]$task.Actions[0].Execute
    arguments = [string]$task.Actions[0].Arguments
    action_count = @($task.Actions).Count
    user_id = [string]$task.Principal.UserId
    logon_type = [string]$task.Principal.LogonType
    run_level = [string]$task.Principal.RunLevel
    trigger_count = @($task.Triggers).Count
    startup_trigger = @($task.Triggers | Where-Object { $_.CimClass.CimClassName -eq 'MSFT_TaskBootTrigger' }).Count
    repetition_interval = [string](@($task.Triggers | Where-Object { $_.Repetition.Interval } | ForEach-Object { $_.Repetition.Interval }) | Select-Object -First 1)
    multiple_instances = [string]$task.Settings.MultipleInstances
    sddl = $sddl
  }
}

function Test-RenewalInstallation {
  param([Parameter(Mandatory)][string]$ExpectedOperatorSid)
  # The renewal is only meaningful on top of a verified #262 boundary.
  Test-MaintenanceInstallation -ExpectedOperatorSid $ExpectedOperatorSid | Out-Null
  Assert-NoReparsePoint -LiteralPath $script:RenewalPayloadRoot
  Assert-NoReparsePoint -LiteralPath $script:RenewalStatusRoot
  $manifest = Get-Content -Raw -LiteralPath (Join-Path $script:RenewalPayloadRoot 'manifest.json') | ConvertFrom-Json
  if ($manifest.owner -cne 'popcre/ai-devops#1312' -or $manifest.operator_sid -cne $ExpectedOperatorSid) { throw 'STALE_INSTALLATION: renewal manifest identity mismatch.' }
  foreach ($name in $script:RenewalFiles) {
    if ((Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $script:RenewalPayloadRoot $name)).Hash.ToLowerInvariant() -cne [string]$manifest.files.$name) { throw "STALE_INSTALLATION: renewal hash drift in $name." }
  }
  $acl = Get-Acl -LiteralPath $script:RenewalPayloadRoot
  $owner = $acl.GetOwner([Security.Principal.SecurityIdentifier]).Value
  if ($owner -notin @('S-1-5-32-544','S-1-5-18')) { throw 'STALE_INSTALLATION: foreign owner on renewal payload.' }
  $operatorWrite = @($acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]) | Where-Object { $_.IdentityReference.Value -notin @('S-1-5-32-544','S-1-5-18') -and (($_.FileSystemRights -band [Security.AccessControl.FileSystemRights]::Write) -or ($_.FileSystemRights -band [Security.AccessControl.FileSystemRights]::Delete) -or ($_.FileSystemRights -band [Security.AccessControl.FileSystemRights]::ChangePermissions)) })
  if ($operatorWrite.Count -ne 0) { throw 'STALE_INSTALLATION: non-administrator write access on renewal payload.' }
  Assert-RenewalTaskContract -Task (Get-RenewalTaskSnapshot) -ExpectedOperatorSid $ExpectedOperatorSid
  return $true
}

function Assert-RenewalTaskContract {
  param([Parameter(Mandatory)]$Task, [Parameter(Mandatory)][string]$ExpectedOperatorSid)
  $expectedInterval = 'PT{0}H' -f $script:RenewalIntervalHours
  if ($Task.action_count -ne 1 -or $Task.execute -cne $script:RenewalPowerShell -or $Task.arguments -cne (Get-RenewalTaskArguments)) { throw 'STALE_INSTALLATION: renewal task action drift.' }
  if ($Task.user_id -cne $ExpectedOperatorSid -or $Task.logon_type -cne 'S4U' -or $Task.run_level -cne 'Limited') { throw 'STALE_INSTALLATION: renewal task principal drift.' }
  if ($Task.trigger_count -ne 2 -or $Task.startup_trigger -ne 1 -or $Task.repetition_interval -cne $expectedInterval) { throw 'STALE_INSTALLATION: renewal task schedule drift.' }
  if ($Task.multiple_instances -cne 'IgnoreNew' -or $Task.sddl -cne (Get-RenewalTaskSddl -OperatorSid $ExpectedOperatorSid)) { throw 'STALE_INSTALLATION: renewal task settings or ACL drift.' }
}

function Remove-RenewalInstallation {
  $task = Get-ScheduledTask -TaskPath $script:RenewalTaskFolder -TaskName $script:RenewalTaskName -ErrorAction SilentlyContinue
  if ($null -eq $task -and -not (Test-Path -LiteralPath $script:RenewalPayloadRoot)) { return 'ABSENT' }
  if ($null -ne $task) { Unregister-ScheduledTask -TaskPath $script:RenewalTaskFolder -TaskName $script:RenewalTaskName -Confirm:$false }
  if (Test-Path -LiteralPath $script:RenewalPayloadRoot) {
    Assert-NoReparsePoint -LiteralPath $script:RenewalPayloadRoot
    Assert-NoForeignOwnership -LiteralPath $script:RenewalPayloadRoot
    Remove-Item -LiteralPath $script:RenewalPayloadRoot -Recurse -Force
  }
  # Status records are kept on purpose: they are the failure history.
  return 'REMOVED'
}

function Invoke-RenewalInstallerMain {
  $sid = Resolve-OperatorSid -User $script:RenewalOperatorUser
  $sourceRoot = Split-Path -Parent $PSScriptRoot
  if ($script:RenewalMode -eq 'Remove') { Assert-Administrator; Write-Output ('RENEWAL: ' + (Remove-RenewalInstallation)); return }
  if ($script:RenewalMode -eq 'Install') {
    Assert-Administrator
    Test-MaintenanceInstallation -ExpectedOperatorSid $sid | Out-Null
    Install-RenewalPayload -SourceRoot $sourceRoot -OperatorSid $sid
    Register-RenewalTask -OperatorSid $sid
  }
  Test-RenewalInstallation -ExpectedOperatorSid $sid | Out-Null
  Write-Output 'PASS: Windows runner qualification renewal installation verified'
}

if (-not $script:RenewalLibraryMode) { Invoke-RenewalInstallerMain }
