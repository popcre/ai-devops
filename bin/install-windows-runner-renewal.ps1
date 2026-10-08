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
# Same self-hardening as the #262 installer, and BEFORE any cmdlet runs: this
# installer is elevated under the operator's own account, so its console is
# untrusted input. Module resolution is pinned to system-owned directories
# and known code-loading variables refuse the run (only .NET calls above).
$env:PSModulePath = "$PSHOME\Modules;C:\Windows\System32\WindowsPowerShell\v1.0\Modules"
foreach ($hostile in @('DOTNET_STARTUP_HOOKS','DOTNET_ADDITIONAL_DEPS','CORECLR_ENABLE_PROFILING','CORECLR_PROFILER','COR_ENABLE_PROFILING','COR_PROFILER')) {
  if ([Environment]::GetEnvironmentVariable($hostile)) { throw "Refusing to run: hostile code-loading variable $hostile is set in this shell. Rerun from a clean elevated shell." }
}
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
. ([IO.Path]::Combine($PSScriptRoot, 'install-windows-runner-maintenance.ps1')) -LibraryMode

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
  if (Test-Path -LiteralPath $staging) { Assert-NoReparsePoint -LiteralPath $staging; Assert-NoForeignOwnership -LiteralPath $staging; Remove-Item -LiteralPath $staging -Recurse -Force }
  New-Item -ItemType Directory -Path $staging | Out-Null
  foreach ($name in $script:RenewalFiles) { Copy-Item -LiteralPath (Join-Path $SourceRoot "bin\$name") -Destination (Join-Path $staging $name) }
  ($manifest | ConvertTo-Json -Depth 4) | Set-Content -LiteralPath (Join-Path $staging 'manifest.json') -Encoding utf8
  Set-RenewalAcl -LiteralPath $staging -OperatorSid $OperatorSid -Kind Payload
  foreach ($name in $script:RenewalFiles) {
    if ((Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $staging $name)).Hash.ToLowerInvariant() -cne [string]$manifest.files[$name]) { throw "Staged renewal payload hash mismatch: $name" }
  }
  if (Test-Path -LiteralPath $script:RenewalPayloadRoot) { Assert-NoReparsePoint -LiteralPath $script:RenewalPayloadRoot; Assert-NoForeignOwnership -LiteralPath $script:RenewalPayloadRoot; Remove-Item -LiteralPath $script:RenewalPayloadRoot -Recurse -Force }
  Move-Item -LiteralPath $staging -Destination $script:RenewalPayloadRoot
  $statusParent = Split-Path -Parent $script:RenewalStatusRoot
  Assert-NoReparsePoint -LiteralPath $statusParent -AllowMissing:$false
  Assert-NoForeignOwnership -LiteralPath $statusParent
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
  # COM tripwire BEFORE the first task write, then register DISABLED, seal
  # the DACL, and only then enable. Any failure unregisters, so a planted
  # override can never leave an enabled, unsealed startup task behind.
  Assert-NoPerUserComOverride
  $action = New-ScheduledTaskAction -Execute $script:RenewalPowerShell -Argument (Get-RenewalTaskArguments)
  $startup = New-ScheduledTaskTrigger -AtStartup
  $startup.Delay = 'PT{0}M' -f $script:RenewalStartupDelayMinutes
  $repeat = New-ScheduledTaskTrigger -Once -At ([DateTime]::Now.Date.AddHours(1)) -RepetitionInterval ([TimeSpan]::FromHours($script:RenewalIntervalHours))
  # Limited run level: this task holds no administrator power at all.
  $principal = New-ScheduledTaskPrincipal -UserId $OperatorSid -LogonType S4U -RunLevel Limited
  $settings = New-ScheduledTaskSettingsSet -Disable -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::FromMinutes(10)) -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
  try {
    Register-ScheduledTask -TaskPath $script:RenewalTaskFolder -TaskName $script:RenewalTaskName -Action $action -Trigger @($startup, $repeat) -Principal $principal -Settings $settings -Force | Out-Null
    $service = New-Object -ComObject 'Schedule.Service'
    $service.Connect()
    $registered = $service.GetFolder($script:RenewalTaskFolderCom).GetTask($script:RenewalTaskName)
    $registered.SetSecurityDescriptor((Get-RenewalTaskSddl -OperatorSid $OperatorSid), 0)
    $registered.Enabled = $true
  } catch {
    Unregister-ScheduledTask -TaskPath $script:RenewalTaskFolder -TaskName $script:RenewalTaskName -Confirm:$false -ErrorAction SilentlyContinue
    throw
  }
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
    enabled = [bool]$task.Settings.Enabled
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
  Test-RenewalPathAcl -LiteralPath $script:RenewalPayloadRoot -OperatorSid $ExpectedOperatorSid -Kind Payload
  foreach ($child in @(Get-ChildItem -LiteralPath $script:RenewalPayloadRoot -Force)) { Test-RenewalPathAcl -LiteralPath $child.FullName -OperatorSid $ExpectedOperatorSid -Kind Payload }
  Test-RenewalPathAcl -LiteralPath $script:RenewalStatusRoot -OperatorSid $ExpectedOperatorSid -Kind Status
  Assert-RenewalTaskContract -Task (Get-RenewalTaskSnapshot) -ExpectedOperatorSid $ExpectedOperatorSid
  return $true
}

function Test-RenewalAclRules {
  # Pure contract over (owner, rules) so it is testable offline. Payload:
  # Administrators/SYSTEM full control, operator read/execute only, nothing
  # else. Status: the same plus operator modify and Users read only.
  param([Parameter(Mandatory)][string]$OwnerSid, [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Rules, [Parameter(Mandatory)][string]$OperatorSid, [ValidateSet('Payload','Status')][string]$Kind)
  if ($OwnerSid -notin @('S-1-5-32-544','S-1-5-18')) { throw "STALE_INSTALLATION: foreign owner on renewal $Kind." }
  $allowed = @('S-1-5-32-544','S-1-5-18',$OperatorSid)
  if ($Kind -eq 'Status') { $allowed += 'S-1-5-32-545' }
  if (@($Rules | Where-Object { [string]$_.AccessControlType -ne 'Allow' -or [string]$_.Sid -notin $allowed }).Count -ne 0) { throw "STALE_INSTALLATION: unexpected ACL identity on renewal $Kind." }
  foreach ($required in @('S-1-5-32-544','S-1-5-18')) {
    if (-not ($Rules | Where-Object { [string]$_.Sid -eq $required -and (([int]$_.Rights -band 2032127) -eq 2032127) })) { throw "STALE_INSTALLATION: missing protected ACL on renewal $Kind." }
  }
  # Write | AppendData | WriteEA | WriteAttributes | DeleteSubdirectoriesAndFiles | Delete | ChangePermissions | TakeOwnership
  $mutating = 0x2 -bor 0x4 -bor 0x10 -bor 0x100 -bor 0x40 -bor 0x10000 -bor 0x40000 -bor 0x80000
  $ownerChange = 0x40000 -bor 0x80000
  foreach ($rule in @($Rules | Where-Object { [string]$_.Sid -notin @('S-1-5-32-544','S-1-5-18') })) {
    $rights = [int]$rule.Rights
    if ([string]$rule.Sid -eq $OperatorSid -and $Kind -eq 'Status') { if ($rights -band $ownerChange) { throw 'STALE_INSTALLATION: operator may change ownership or permissions on renewal Status.' }; continue }
    if ($rights -band $mutating) { throw "STALE_INSTALLATION: non-administrator write access on renewal $Kind." }
  }
}

function Test-RenewalPathAcl {
  param([Parameter(Mandatory)][string]$LiteralPath, [Parameter(Mandatory)][string]$OperatorSid, [ValidateSet('Payload','Status')][string]$Kind)
  Assert-NoReparsePoint -LiteralPath $LiteralPath
  $acl = Get-Acl -LiteralPath $LiteralPath
  $rules = @($acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]) | ForEach-Object { [pscustomobject]@{ Sid=$_.IdentityReference.Value; AccessControlType=[string]$_.AccessControlType; Rights=[int]$_.FileSystemRights } })
  Test-RenewalAclRules -OwnerSid $acl.GetOwner([Security.Principal.SecurityIdentifier]).Value -Rules $rules -OperatorSid $OperatorSid -Kind $Kind
}

function Assert-RenewalTaskContract {
  param([Parameter(Mandatory)]$Task, [Parameter(Mandatory)][string]$ExpectedOperatorSid)
  $expectedInterval = 'PT{0}H' -f $script:RenewalIntervalHours
  if ($Task.action_count -ne 1 -or $Task.execute -cne $script:RenewalPowerShell -or $Task.arguments -cne (Get-RenewalTaskArguments)) { throw 'STALE_INSTALLATION: renewal task action drift.' }
  if ($Task.user_id -cne $ExpectedOperatorSid -or $Task.logon_type -cne 'S4U' -or $Task.run_level -cne 'Limited') { throw 'STALE_INSTALLATION: renewal task principal drift.' }
  if ($Task.trigger_count -ne 2 -or $Task.startup_trigger -ne 1 -or $Task.repetition_interval -cne $expectedInterval) { throw 'STALE_INSTALLATION: renewal task schedule drift.' }
  if (-not $Task.enabled) { throw 'STALE_INSTALLATION: renewal task is disabled.' }
  if ($Task.multiple_instances -cne 'IgnoreNew' -or $Task.sddl -cne (Get-RenewalTaskSddl -OperatorSid $ExpectedOperatorSid)) { throw 'STALE_INSTALLATION: renewal task settings or ACL drift.' }
}

function Remove-RenewalInstallation {
  # Tripwire first; a planted override blocks removal (fail closed) and is
  # reported, never silently bypassed.
  Assert-NoPerUserComOverride
  $task = Get-ScheduledTask -TaskPath $script:RenewalTaskFolder -TaskName $script:RenewalTaskName -ErrorAction SilentlyContinue
  if ($null -eq $task -and -not (Test-Path -LiteralPath $script:RenewalPayloadRoot)) { return 'ABSENT' }
  if ($null -ne $task) {
    # Seal to administrators/SYSTEM first so the operator cannot start it
    # during teardown, then unregister.
    $service = New-Object -ComObject 'Schedule.Service'
    $service.Connect()
    $service.GetFolder($script:RenewalTaskFolderCom).GetTask($script:RenewalTaskName).SetSecurityDescriptor('D:P(A;;FA;;;SY)(A;;FA;;;BA)', 0)
    Unregister-ScheduledTask -TaskPath $script:RenewalTaskFolder -TaskName $script:RenewalTaskName -Confirm:$false
  }
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
