[CmdletBinding(DefaultParameterSetName='Verify')]
param(
  [Parameter(ParameterSetName='Install')][switch]$Install,
  [Parameter(ParameterSetName='Update')][switch]$Update,
  [Parameter(ParameterSetName='Verify')][switch]$Verify,
  [Parameter(ParameterSetName='Remove')][switch]$Remove,
  [Parameter(ParameterSetName='Remove')][switch]$RequireManifestMatch,
  [Parameter(ParameterSetName='Remove')][string]$BackupPath,
  [string]$OperatorUser = "$env:COMPUTERNAME\ahazan",
  [switch]$LibraryMode
)

$ErrorActionPreference = 'Stop'
$script:TaskPath = '\AiDevOps\WindowsRunnerMaintenance'
$script:TaskFolder = '\AiDevOps\'
$script:TaskName = 'WindowsRunnerMaintenance'
$script:PayloadRoot = 'C:\Program Files\ai-devops\windows-runner-maintenance'
$script:RuntimeRoot = 'C:\ProgramData\ai-devops\windows-runner-maintenance'
$script:EvidencePath = 'C:\ProgramData\ai-devops\windows-runner-security.json'
$script:PowerShellPath = 'C:\Program Files\PowerShell\7\pwsh.exe'
$script:OwnedRuntimeNames = @('requests', 'results', 'audit.jsonl', 'processed-requests.jsonl')

function Assert-Administrator {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = [Security.Principal.WindowsPrincipal]::new($identity)
  if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Administrator elevation is required.' }
}

function Resolve-OperatorSid {
  param([Parameter(Mandatory)][string]$User)
  if ($User -notmatch '^([^\\]+)\\([^\\]+)$' -or $Matches[1] -cne $env:COMPUTERNAME) { throw 'Operator must be one unambiguous local account on this host.' }
  $account = [Security.Principal.NTAccount]::new($User)
  try { $sid = $account.Translate([Security.Principal.SecurityIdentifier]) } catch { throw 'Operator SID could not be resolved.' }
  if (-not $sid.Value.StartsWith('S-1-5-21-', [StringComparison]::Ordinal)) { throw 'Operator SID is not a local account SID.' }
  return $sid.Value
}

function Assert-NoReparsePoint {
  param([Parameter(Mandatory)][string]$LiteralPath, [switch]$AllowMissing)
  if (-not (Test-Path -LiteralPath $LiteralPath)) { if ($AllowMissing) { return }; throw "Missing required path: $LiteralPath" }
  $item = Get-Item -LiteralPath $LiteralPath -Force
  if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Reparse point refused: $LiteralPath" }
  if ($item.PSIsContainer) {
    foreach ($child in Get-ChildItem -LiteralPath $LiteralPath -Force -Recurse) {
      if (($child.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Reparse point refused: $($child.FullName)" }
    }
  }
}

function Get-DesiredPayloadManifest {
  param([Parameter(Mandatory)][string]$SourceRoot, [Parameter(Mandatory)][string]$OperatorSid)
  $sources = [ordered]@{
    'windows-runner-maintenance-worker.ps1' = Join-Path $SourceRoot 'bin\windows-runner-maintenance-worker.ps1'
    'qualify-windows-runner.ps1' = Join-Path $SourceRoot 'bin\qualify-windows-runner.ps1'
    'windows-runner-maintenance-policy.json' = Join-Path $SourceRoot 'config\windows-runner-maintenance-policy.json'
  }
  $files = [ordered]@{}
  foreach ($entry in $sources.GetEnumerator()) {
    Assert-NoReparsePoint -LiteralPath $entry.Value
    $files[$entry.Key] = (Get-FileHash -Algorithm SHA256 -LiteralPath $entry.Value).Hash.ToLowerInvariant()
  }
  $policy = Get-Content -Raw -LiteralPath $sources['windows-runner-maintenance-policy.json'] | ConvertFrom-Json
  foreach ($name in @('windows-runner-maintenance-worker.ps1','qualify-windows-runner.ps1')) {
    if ([string]$policy.payload_hashes.$name -cne [string]$files[$name]) { throw "Policy payload hash is stale for $name." }
  }
  return [ordered]@{ schema_version=1; owner='popcre/ai-devops#262'; operator_sid=$OperatorSid; task_path=$script:TaskPath; files=$files }
}

function Set-ProtectedFilesystemAcl {
  param([Parameter(Mandatory)][string]$LiteralPath, [Parameter(Mandatory)][string]$OperatorSid, [ValidateSet('Payload','Runtime')][string]$Kind)
  Assert-NoReparsePoint -LiteralPath $LiteralPath
  $admins = '*S-1-5-32-544'
  $system = '*S-1-5-18'
  if ($Kind -eq 'Payload') {
    & icacls.exe $LiteralPath /setowner $admins /T /C | Out-Null
    & icacls.exe $LiteralPath /inheritance:r /grant:r "${admins}:(OI)(CI)F" "${system}:(OI)(CI)F" "*${OperatorSid}:(OI)(CI)RX" /T /C | Out-Null
  } else {
    & icacls.exe $LiteralPath /setowner $admins /T /C | Out-Null
    & icacls.exe $LiteralPath /inheritance:r /grant:r "${admins}:(OI)(CI)F" "${system}:(OI)(CI)F" "*${OperatorSid}:(OI)(CI)RX" | Out-Null
    & icacls.exe (Join-Path $LiteralPath 'requests') /inheritance:r /grant:r "${admins}:(OI)(CI)F" "${system}:(OI)(CI)F" "*${OperatorSid}:(OI)(CI)M" /T /C | Out-Null
    & icacls.exe (Join-Path $LiteralPath 'results') /inheritance:r /grant:r "${admins}:(OI)(CI)F" "${system}:(OI)(CI)F" "*${OperatorSid}:(OI)(CI)RX" /T /C | Out-Null
    $audit = Join-Path $LiteralPath 'audit.jsonl'
    if (Test-Path -LiteralPath $audit) { & icacls.exe $audit /inheritance:r /grant:r "${admins}:F" "${system}:F" "*${OperatorSid}:R" | Out-Null }
    $ledger = Join-Path $LiteralPath 'processed-requests.jsonl'
    if (Test-Path -LiteralPath $ledger) { & icacls.exe $ledger /inheritance:r /grant:r "${admins}:F" "${system}:F" | Out-Null }
  }
  if ($LASTEXITCODE -ne 0) { throw 'Filesystem ACL update failed.' }
}

function Register-MaintenanceTask {
  param([Parameter(Mandatory)][string]$OperatorSid)
  $action = New-ScheduledTaskAction -Execute $script:PowerShellPath -Argument '-NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File "C:\Program Files\ai-devops\windows-runner-maintenance\windows-runner-maintenance-worker.ps1"'
  $principal = New-ScheduledTaskPrincipal -UserId $OperatorSid -LogonType S4U -RunLevel Highest
  $settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::FromMinutes(6)) -StartWhenAvailable:$false
  Register-ScheduledTask -TaskPath $script:TaskFolder -TaskName $script:TaskName -Action $action -Principal $principal -Settings $settings -Force | Out-Null
}

function Set-MaintenanceTaskAcl {
  param([Parameter(Mandatory)][string]$OperatorSid)
  $service = New-Object -ComObject 'Schedule.Service'
  $service.Connect()
  $task = $service.GetFolder($script:TaskFolder).GetTask($script:TaskName)
  $sddl = "D:P(A;;FA;;;SY)(A;;FA;;;BA)(A;;GRGX;;;$OperatorSid)"
  $task.SetSecurityDescriptor($sddl, 0)
  return $sddl
}

function Get-InstalledTaskSnapshot {
  $task = Get-ScheduledTask -TaskPath $script:TaskFolder -TaskName $script:TaskName -ErrorAction Stop
  $service = New-Object -ComObject 'Schedule.Service'
  $service.Connect()
  $sddl = $service.GetFolder($script:TaskFolder).GetTask($script:TaskName).GetSecurityDescriptor(0)
  return [ordered]@{
    execute = [string]$task.Actions[0].Execute
    arguments = [string]$task.Actions[0].Arguments
    user_id = [string]$task.Principal.UserId
    logon_type = [string]$task.Principal.LogonType
    run_level = [string]$task.Principal.RunLevel
    trigger_count = @($task.Triggers).Count
    multiple_instances = [string]$task.Settings.MultipleInstances
    sddl = [string]$sddl
    state = [string]$task.State
  }
}

function Test-PathAclContract {
  param([Parameter(Mandatory)][string]$LiteralPath, [Parameter(Mandatory)][string]$OperatorSid, [ValidateSet('Payload','RuntimeRoot','Requests','Results','Audit','Ledger')][string]$Kind)
  Assert-NoReparsePoint -LiteralPath $LiteralPath
  $acl = Get-Acl -LiteralPath $LiteralPath
  $ownerSid = ([Security.Principal.NTAccount]$acl.Owner).Translate([Security.Principal.SecurityIdentifier]).Value
  if ($ownerSid -notin @('S-1-5-32-544','S-1-5-18')) { throw "STALE_INSTALLATION: foreign owner on $Kind." }
  $rules = @($acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]))
  $unexpected = @($rules | Where-Object { $_.AccessControlType -ne 'Allow' -or $_.IdentityReference.Value -notin @('S-1-5-32-544','S-1-5-18',$OperatorSid) })
  if ($unexpected.Count -ne 0) { throw "STALE_INSTALLATION: unexpected ACL identity on $Kind." }
  foreach ($required in @('S-1-5-32-544','S-1-5-18')) {
    if (-not ($rules | Where-Object { $_.IdentityReference.Value -eq $required -and ($_.FileSystemRights -band [Security.AccessControl.FileSystemRights]::FullControl) })) { throw "STALE_INSTALLATION: missing protected ACL on $Kind." }
  }
  $operatorRules = @($rules | Where-Object { $_.IdentityReference.Value -eq $OperatorSid })
  if ($Kind -eq 'Ledger') { if ($operatorRules.Count -ne 0) { throw 'STALE_INSTALLATION: operator can read or write the replay ledger.' }; return }
  if ($operatorRules.Count -eq 0) { throw "STALE_INSTALLATION: operator ACL missing on $Kind." }
  $operatorRights = $operatorRules | ForEach-Object FileSystemRights
  $mayWrite = @($operatorRights | Where-Object { ($_ -band [Security.AccessControl.FileSystemRights]::Write) -or ($_ -band [Security.AccessControl.FileSystemRights]::Delete) -or ($_ -band [Security.AccessControl.FileSystemRights]::ChangePermissions) }).Count -ne 0
  if ($Kind -eq 'Requests') { if (-not $mayWrite) { throw 'STALE_INSTALLATION: operator cannot create requests.' } }
  elseif ($mayWrite) { throw "STALE_INSTALLATION: operator has write access on $Kind." }
}

function Test-MaintenanceInstallation {
  param([string]$ExpectedOperatorSid)
  Assert-NoReparsePoint -LiteralPath $script:PayloadRoot
  Assert-NoReparsePoint -LiteralPath $script:RuntimeRoot
  $manifestPath = Join-Path $script:PayloadRoot 'manifest.json'
  $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
  if ($manifest.owner -cne 'popcre/ai-devops#262' -or $manifest.task_path -cne $script:TaskPath -or $manifest.operator_sid -cne $ExpectedOperatorSid) { throw 'STALE_INSTALLATION: manifest identity mismatch.' }
  foreach ($file in $manifest.files.PSObject.Properties) {
    $path = Join-Path $script:PayloadRoot $file.Name
    if ((Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant() -cne [string]$file.Value) { throw "STALE_INSTALLATION: hash drift in $($file.Name)." }
  }
  Test-PathAclContract -LiteralPath $script:PayloadRoot -OperatorSid $ExpectedOperatorSid -Kind Payload
  Test-PathAclContract -LiteralPath $script:RuntimeRoot -OperatorSid $ExpectedOperatorSid -Kind RuntimeRoot
  Test-PathAclContract -LiteralPath (Join-Path $script:RuntimeRoot 'requests') -OperatorSid $ExpectedOperatorSid -Kind Requests
  Test-PathAclContract -LiteralPath (Join-Path $script:RuntimeRoot 'results') -OperatorSid $ExpectedOperatorSid -Kind Results
  Test-PathAclContract -LiteralPath (Join-Path $script:RuntimeRoot 'audit.jsonl') -OperatorSid $ExpectedOperatorSid -Kind Audit
  Test-PathAclContract -LiteralPath (Join-Path $script:RuntimeRoot 'processed-requests.jsonl') -OperatorSid $ExpectedOperatorSid -Kind Ledger
  $task = Get-InstalledTaskSnapshot
  $expectedArgs = '-NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File "C:\Program Files\ai-devops\windows-runner-maintenance\windows-runner-maintenance-worker.ps1"'
  $expectedSddl = "D:P(A;;FA;;;SY)(A;;FA;;;BA)(A;;GRGX;;;$ExpectedOperatorSid)"
  if ($task.execute -cne $script:PowerShellPath -or $task.arguments -cne $expectedArgs -or $task.user_id -cne $ExpectedOperatorSid -or $task.logon_type -cne 'S4U' -or $task.run_level -cne 'Highest' -or $task.trigger_count -ne 0 -or $task.multiple_instances -cne 'IgnoreNew' -or $task.sddl -cne $expectedSddl) { throw 'STALE_INSTALLATION: scheduled task drift.' }
  return $true
}

function Backup-MaintenanceInstallation {
  param([Parameter(Mandatory)][string]$Destination)
  New-Item -ItemType Directory -Path $Destination -Force | Out-Null
  $task = Get-ScheduledTask -TaskPath $script:TaskFolder -TaskName $script:TaskName -ErrorAction SilentlyContinue
  if ($null -ne $task) { Export-ScheduledTask -TaskPath $script:TaskFolder -TaskName $script:TaskName | Set-Content -LiteralPath (Join-Path $Destination 'task.xml') -Encoding utf8 }
  if (Test-Path -LiteralPath $script:PayloadRoot) { Copy-Item -LiteralPath $script:PayloadRoot -Destination (Join-Path $Destination 'payload') -Recurse }
  @{ schema_version=1; task_path=$script:TaskPath; backed_up_at_utc=[DateTime]::UtcNow.ToString('o') } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $Destination 'recovery.json') -Encoding utf8
}

function Install-MaintenancePayload {
  param([Parameter(Mandatory)][string]$SourceRoot, [Parameter(Mandatory)][string]$OperatorSid)
  $manifest = Get-DesiredPayloadManifest -SourceRoot $SourceRoot -OperatorSid $OperatorSid
  $parent = Split-Path -Parent $script:PayloadRoot
  New-Item -ItemType Directory -Path $parent -Force | Out-Null
  Assert-NoReparsePoint -LiteralPath $parent
  $staging = Join-Path $parent ('.maintenance-staging-' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $staging | Out-Null
  foreach ($name in $manifest.files.Keys) {
    $source = if ($name -eq 'windows-runner-maintenance-policy.json') { Join-Path $SourceRoot "config\$name" } else { Join-Path $SourceRoot "bin\$name" }
    Copy-Item -LiteralPath $source -Destination (Join-Path $staging $name)
  }
  $policyPath = Join-Path $staging 'windows-runner-maintenance-policy.json'
  $policy = Get-Content -Raw -LiteralPath $policyPath | ConvertFrom-Json
  $policy | Add-Member -NotePropertyName operator_sid -NotePropertyValue $OperatorSid -Force
  $policy | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $policyPath -Encoding utf8
  $manifest.files.'windows-runner-maintenance-policy.json' = (Get-FileHash -Algorithm SHA256 -LiteralPath $policyPath).Hash.ToLowerInvariant()
  $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $staging 'manifest.json') -Encoding utf8
  $old = "$script:PayloadRoot.previous"
  if (Test-Path -LiteralPath $old) { throw 'Refusing to replace an unverified previous payload backup.' }
  if (Test-Path -LiteralPath $script:PayloadRoot) { Move-Item -LiteralPath $script:PayloadRoot -Destination $old }
  Move-Item -LiteralPath $staging -Destination $script:PayloadRoot
  if (Test-Path -LiteralPath $old) { Remove-Item -LiteralPath $old -Recurse -Force }
  $runtimeParent = Split-Path -Parent $script:RuntimeRoot
  New-Item -ItemType Directory -Path $runtimeParent -Force | Out-Null
  Assert-NoReparsePoint -LiteralPath $runtimeParent
  New-Item -ItemType Directory -Path (Join-Path $script:RuntimeRoot 'requests'), (Join-Path $script:RuntimeRoot 'results') -Force | Out-Null
  foreach ($name in @('audit.jsonl','processed-requests.jsonl')) { $p = Join-Path $script:RuntimeRoot $name; if (-not (Test-Path -LiteralPath $p)) { [IO.File]::WriteAllBytes($p, [byte[]]@()) } }
  Set-ProtectedFilesystemAcl -LiteralPath $script:PayloadRoot -OperatorSid $OperatorSid -Kind Payload
  Set-ProtectedFilesystemAcl -LiteralPath $script:RuntimeRoot -OperatorSid $OperatorSid -Kind Runtime
}

function Remove-MaintenanceInstallation {
  param([Parameter(Mandatory)][string]$ExpectedOperatorSid, [string]$RecoveryPath)
  if (-not (Test-Path -LiteralPath $script:PayloadRoot) -and $null -eq (Get-ScheduledTask -TaskPath $script:TaskFolder -TaskName $script:TaskName -ErrorAction SilentlyContinue)) { return 'ABSENT' }
  Test-MaintenanceInstallation -ExpectedOperatorSid $ExpectedOperatorSid | Out-Null
  if ((Get-InstalledTaskSnapshot).state -eq 'Running') { throw 'RECOVERY_RUNNING_TASK: wait for the bounded task to stop before removal.' }
  if ([string]::IsNullOrWhiteSpace($RecoveryPath)) { $RecoveryPath = Join-Path (Split-Path -Parent $script:RuntimeRoot) ('windows-runner-maintenance-recovery-' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')) }
  Backup-MaintenanceInstallation -Destination $RecoveryPath
  Unregister-ScheduledTask -TaskPath $script:TaskFolder -TaskName $script:TaskName -Confirm:$false
  Remove-Item -LiteralPath $script:PayloadRoot -Recurse -Force
  foreach ($name in $script:OwnedRuntimeNames) { $path = Join-Path $script:RuntimeRoot $name; if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force } }
  return 'REMOVED'
}

function Invoke-InstallerMain {
  $sid = Resolve-OperatorSid -User $OperatorUser
  $sourceRoot = Split-Path -Parent $PSScriptRoot
  if ($Remove) { Assert-Administrator; Remove-MaintenanceInstallation -ExpectedOperatorSid $sid -RecoveryPath $BackupPath; return }
  if ($Verify -or (-not $Install -and -not $Update)) { Test-MaintenanceInstallation -ExpectedOperatorSid $sid | Out-Null; Write-Output 'PASS: Windows runner maintenance installation verified'; return }
  Assert-Administrator
  $existingTask = Get-ScheduledTask -TaskPath $script:TaskFolder -TaskName $script:TaskName -ErrorAction SilentlyContinue
  if ((Test-Path -LiteralPath $script:PayloadRoot) -or $null -ne $existingTask) {
    Test-MaintenanceInstallation -ExpectedOperatorSid $sid | Out-Null
    if ((Get-InstalledTaskSnapshot).state -eq 'Running') { throw 'RECOVERY_RUNNING_TASK: wait for the bounded task to stop before update.' }
    $backup = Join-Path (Split-Path -Parent $script:RuntimeRoot) ('windows-runner-maintenance-recovery-' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ'))
    Backup-MaintenanceInstallation -Destination $backup
  }
  Install-MaintenancePayload -SourceRoot $sourceRoot -OperatorSid $sid
  Register-MaintenanceTask -OperatorSid $sid
  Set-MaintenanceTaskAcl -OperatorSid $sid | Out-Null
  Test-MaintenanceInstallation -ExpectedOperatorSid $sid | Out-Null
  Write-Output 'PASS: Windows runner maintenance installation verified'
}

if (-not $LibraryMode) { Invoke-InstallerMain }
