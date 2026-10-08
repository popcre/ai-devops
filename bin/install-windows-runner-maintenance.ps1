[CmdletBinding(DefaultParameterSetName='Verify')]
param(
  [Parameter(ParameterSetName='Install')][switch]$Install,
  [Parameter(ParameterSetName='Update')][switch]$Update,
  [Parameter(ParameterSetName='Verify')][switch]$Verify,
  [Parameter(ParameterSetName='Remove')][switch]$Remove,
  [Parameter(ParameterSetName='Remove')][switch]$RequireManifestMatch,
  [Parameter(ParameterSetName='Remove')][Parameter(ParameterSetName='Install')][Parameter(ParameterSetName='Update')][string]$BackupPath,
  [switch]$RecoverPartial,
  [string]$OperatorUser = "$([Environment]::MachineName)\ahazan",
  [switch]$LibraryMode
)

$ErrorActionPreference = 'Stop'
# Self-hardening: the installer runs elevated under the same account the
# operator uses, so its inherited console environment is untrusted input
# too. Module resolution is pinned to system-owned directories before any
# cmdlet runs, and known code-loading variables refuse the run outright
# (the pwsh host may already have consumed them before this line, so this
# is a fail-closed tripwire, not a sanitiser - rerun from a clean shell).
$env:PSModulePath = "$PSHOME\Modules;C:\Windows\System32\WindowsPowerShell\v1.0\Modules"
foreach ($hostile in @('DOTNET_STARTUP_HOOKS','DOTNET_ADDITIONAL_DEPS','CORECLR_ENABLE_PROFILING','CORECLR_PROFILER','COR_ENABLE_PROFILING','COR_PROFILER')) {
  if ([Environment]::GetEnvironmentVariable($hostile)) { throw "Refusing to run: hostile code-loading variable $hostile is set in this shell. Rerun from a clean elevated shell." }
}
$script:TaskPath = '\AiDevOps\WindowsRunnerMaintenance'
$script:TaskFolder = '\AiDevOps\'
# The raw Schedule.Service COM interface rejects a trailing path separator
# (0x8007007B, proven live on 2026-09-18); the cmdlet forms above tolerate it.
$script:TaskFolderCom = '\AiDevOps'
$script:TaskName = 'WindowsRunnerMaintenance'
$script:PayloadRoot = 'C:\Program Files\ai-devops\windows-runner-maintenance'
$script:RuntimeRoot = 'C:\ProgramData\ai-devops\windows-runner-maintenance'
$script:EvidencePath = 'C:\ProgramData\ai-devops\windows-runner-security.json'
$script:PowerShellPath = 'C:\Program Files\PowerShell\7\pwsh.exe'
$script:OwnedRuntimeNames = @('requests', 'results', 'audit.jsonl', 'processed-requests.jsonl', 'temp')

function Assert-Administrator {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = [Security.Principal.WindowsPrincipal]::new($identity)
  if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Administrator elevation is required.' }
}

function Invoke-ProtectedIcacls {
  # Every icacls invocation must be checked immediately: $LASTEXITCODE only
  # reflects the most recent native call, so a batch of unchecked calls lets
  # a failed /setowner or grant pass silently. The absolute path keeps the
  # installer independent of any PATH entry.
  param([Parameter(Mandatory)][string[]]$Arguments)
  & 'C:\Windows\System32\icacls.exe' @Arguments | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Filesystem ACL update failed.' }
}

function Resolve-OperatorSid {
  param([Parameter(Mandatory)][string]$User)
  if ($User -notmatch '^([^\\]+)\\([^\\]+)$' -or $Matches[1] -cne [Environment]::MachineName) { throw 'Operator must be one unambiguous local account on this host.' }
  $account = [Security.Principal.NTAccount]::new($User)
  try { $sid = $account.Translate([Security.Principal.SecurityIdentifier]) } catch { throw 'Operator SID could not be resolved.' }
  if (-not $sid.Value.StartsWith('S-1-5-21-', [StringComparison]::Ordinal)) { throw 'Operator SID is not a local account SID.' }
  # A local GROUP resolves through the same Translate call and would grant
  # every member request-write and task-run rights, so the account must be
  # positively confirmed as a user before it may own the boundary.
  try {
    Add-Type -AssemblyName System.DirectoryServices.AccountManagement
    $machine = [System.DirectoryServices.AccountManagement.PrincipalContext]::new([System.DirectoryServices.AccountManagement.ContextType]::Machine)
    $matched = [System.DirectoryServices.AccountManagement.Principal]::FindByIdentity($machine, [System.DirectoryServices.AccountManagement.IdentityType]::Sid, $sid.Value)
  } catch { throw 'Operator account type could not be verified.' }
  if ($null -eq $matched -or -not ($matched -is [System.DirectoryServices.AccountManagement.UserPrincipal])) { throw 'Operator is not a local user account.' }
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

function Assert-NoForeignOwnership {
  # Nothing this boundary adopts may pre-date it under foreign ownership:
  # ProgramData defaults let any local user create directories and files
  # there first, and blessing such state with an administrator ACL would
  # launder a forged evidence file or a pre-loaded audit trail. Pre-existing
  # paths are adopted only when Administrators/SYSTEM already own them
  # (an earlier install or manual elevated preflight); anything else stops.
  param([Parameter(Mandatory)][string]$LiteralPath)
  if (-not (Test-Path -LiteralPath $LiteralPath)) { return }
  $item = Get-Item -LiteralPath $LiteralPath -Force
  if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Reparse point refused: $LiteralPath" }
  $owner = (Get-Acl -LiteralPath $LiteralPath).GetOwner([Security.Principal.SecurityIdentifier]).Value
  if ($owner -notin @('S-1-5-32-544','S-1-5-18')) { throw "STALE_INSTALLATION: refusing to adopt foreign-owned path: $LiteralPath" }
}

function Assert-SafeBackupChain {
  # A root-prefix allowlist is defeated by an ancestor junction: a standard
  # user can create C:\ProgramData\<name> as a junction, and the elevated
  # backup copy would then land outside the administrator-managed root.
  # Every EXISTING ancestor of the destination must therefore be a plain
  # directory, and every existing ancestor under ProgramData (where users
  # can create entries) must additionally be Administrators/SYSTEM-owned.
  param([Parameter(Mandatory)][string]$LiteralPath)
  $full = [IO.Path]::GetFullPath($LiteralPath)
  $current = $full
  while ($true) {
    $parent = Split-Path -Parent $current
    if (-not $parent -or $parent -eq $current) { break }
    if (Test-Path -LiteralPath $parent) {
      $item = Get-Item -LiteralPath $parent -Force
      if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Reparse point refused in backup chain: $parent" }
      if ($parent -like 'C:\ProgramData\*') { Assert-NoForeignOwnership -LiteralPath $parent }
    }
    $current = $parent
  }
}

function Get-DesiredPayloadManifest {
  param([Parameter(Mandatory)][string]$SourceRoot, [Parameter(Mandatory)][string]$OperatorSid)
  $sources = [ordered]@{
    'windows-runner-maintenance-worker.ps1' = Join-Path $SourceRoot 'bin\windows-runner-maintenance-worker.ps1'
    'launch-worker.bat' = Join-Path $SourceRoot 'bin\launch-worker.bat'
    'qualify-windows-runner.ps1' = Join-Path $SourceRoot 'bin\qualify-windows-runner.ps1'
    'windows-runner-maintenance-policy.json' = Join-Path $SourceRoot 'config\windows-runner-maintenance-policy.json'
  }
  $files = [ordered]@{}
  foreach ($entry in $sources.GetEnumerator()) {
    Assert-NoReparsePoint -LiteralPath $entry.Value
    $files[$entry.Key] = (Get-FileHash -Algorithm SHA256 -LiteralPath $entry.Value).Hash.ToLowerInvariant()
  }
  $policy = Get-Content -Raw -LiteralPath $sources['windows-runner-maintenance-policy.json'] | ConvertFrom-Json
  foreach ($name in @('windows-runner-maintenance-worker.ps1','launch-worker.bat','qualify-windows-runner.ps1')) {
    if ([string]$policy.payload_hashes.$name -cne [string]$files[$name]) { throw "Policy payload hash is stale for $name." }
  }
  return [ordered]@{ schema_version=1; owner='popcre/ai-devops#262'; operator_sid=$OperatorSid; task_path=$script:TaskPath; files=$files }
}

function Set-PayloadFileAcl {
  # icacls applies (OI)(CI) grants to FILES as nothing at all: with
  # /inheritance:r /T every payload file was left with an EMPTY protected
  # DACL (D:PAI), unreadable even by Administrators, so the elevated worker
  # could not load and -Verify/-RecoverPartial failed on access denied
  # (#1312, reproduced 2026-10-08). Each payload file therefore gets explicit
  # non-inheritable grants: Administrators/SYSTEM full, operator read/execute.
  param([Parameter(Mandatory)][string]$LiteralPath, [Parameter(Mandatory)][string]$OperatorSid)
  foreach ($child in @(Get-ChildItem -LiteralPath $LiteralPath -Force -File -Recurse)) {
    Assert-NoReparsePoint -LiteralPath $child.FullName
    Invoke-ProtectedIcacls -Arguments @($child.FullName,'/L','/inheritance:r','/grant:r','*S-1-5-32-544:F','*S-1-5-18:F',"*${OperatorSid}:RX")
  }
}

function Repair-RuntimeResultFileAcl {
  # A partial install made by an installer before #1312 ran icacls /T over the
  # runtime tree and left result records with an EMPTY protected DACL, which
  # even Administrators cannot read, so the recovery backup failed on access
  # denied (edge-dev, 2026-10-08). Restore the install-time result grants on
  # administrator-owned result files only, before they are backed up.
  param([Parameter(Mandatory)][string]$OperatorSid)
  $results = Join-Path $script:RuntimeRoot 'results'
  if (-not (Test-Path -LiteralPath $results)) { return }
  Assert-NoReparsePoint -LiteralPath $results
  Assert-NoForeignOwnership -LiteralPath $results
  foreach ($child in @(Get-ChildItem -LiteralPath $results -Force -File)) {
    Assert-NoReparsePoint -LiteralPath $child.FullName
    Assert-NoForeignOwnership -LiteralPath $child.FullName
    Invoke-ProtectedIcacls -Arguments @($child.FullName,'/L','/inheritance:r','/grant:r','*S-1-5-32-544:F','*S-1-5-18:F',"*${OperatorSid}:R")
  }
}

function Set-ProtectedFilesystemAcl {
  param([Parameter(Mandatory)][string]$LiteralPath, [Parameter(Mandatory)][string]$OperatorSid, [ValidateSet('Payload','Runtime','Evidence','EvidenceParent','Temp')][string]$Kind)
  Assert-NoReparsePoint -LiteralPath $LiteralPath
  $admins = '*S-1-5-32-544'
  $system = '*S-1-5-18'
  if ($Kind -eq 'Payload') {
    Invoke-ProtectedIcacls -Arguments @($LiteralPath,'/setowner',$admins,'/T','/C')
    Invoke-ProtectedIcacls -Arguments @($LiteralPath,'/inheritance:r','/grant:r',"${admins}:(OI)(CI)F","${system}:(OI)(CI)F","*${OperatorSid}:(OI)(CI)RX",'/T','/C')
    Set-PayloadFileAcl -LiteralPath $LiteralPath -OperatorSid $OperatorSid
  } elseif ($Kind -eq 'Evidence') {
    # No operator grant: the elevated qualification child writes through its
    # Administrators membership, so the non-elevated operator must hold
    # nothing on the CI qualification gate.
    Invoke-ProtectedIcacls -Arguments @($LiteralPath,'/setowner',$admins)
    Invoke-ProtectedIcacls -Arguments @($LiteralPath,'/inheritance:r','/grant:r',"${admins}:F","${system}:F",'*S-1-1-0:R')
  } elseif ($Kind -eq 'EvidenceParent') {
    Invoke-ProtectedIcacls -Arguments @($LiteralPath,'/setowner',$admins)
    Invoke-ProtectedIcacls -Arguments @($LiteralPath,'/inheritance:r','/grant:r',"${admins}:(OI)(CI)F","${system}:(OI)(CI)F",'*S-1-5-32-545:(OI)(CI)(IO)(RX)')
  } elseif ($Kind -eq 'Temp') {
    # Elevated-worker scratch space: administrators and SYSTEM only, so no
    # standard user can squat predictable temp names against the host.
    Invoke-ProtectedIcacls -Arguments @($LiteralPath,'/setowner',$admins)
    Invoke-ProtectedIcacls -Arguments @($LiteralPath,'/inheritance:r','/grant:r',"${admins}:(OI)(CI)F","${system}:(OI)(CI)F")
  } else {
    # Runtime root: never icacls /T through operator-writable children
    # (requests is Modify by design). Apply each ACL at its exact target
    # after a per-entry reparse check at the operation site, so a junction
    # planted under requests cannot be re-owned or granted.
    Invoke-ProtectedIcacls -Arguments @($LiteralPath,'/setowner',$admins)
    Invoke-ProtectedIcacls -Arguments @($LiteralPath,'/inheritance:r','/grant:r',"${admins}:(OI)(CI)F","${system}:(OI)(CI)F","*${OperatorSid}:(OI)(CI)RX")
    $requests = Join-Path $LiteralPath 'requests'
    Assert-NoReparsePoint -LiteralPath $requests
    Invoke-ProtectedIcacls -Arguments @($requests,'/setowner',$admins)
    Invoke-ProtectedIcacls -Arguments @($requests,'/inheritance:r','/grant:r',"${admins}:(OI)(CI)F","${system}:(OI)(CI)F","*${OperatorSid}:(OI)(CI)M")
    foreach ($child in @(Get-ChildItem -LiteralPath $requests -Force)) {
      Assert-NoReparsePoint -LiteralPath $child.FullName
      # /L acts on the link itself, so a child swapped to a junction after
      # the check cannot re-own or grant the junction target.
      Invoke-ProtectedIcacls -Arguments @($child.FullName,'/L','/setowner',$admins)
      Invoke-ProtectedIcacls -Arguments @($child.FullName,'/L','/inheritance:r','/grant:r',"${admins}:F","${system}:F","*${OperatorSid}:M")
    }
    $results = Join-Path $LiteralPath 'results'
    Assert-NoReparsePoint -LiteralPath $results
    Invoke-ProtectedIcacls -Arguments @($results,'/setowner',$admins)
    Invoke-ProtectedIcacls -Arguments @($results,'/inheritance:r','/grant:r',"${admins}:(OI)(CI)F","${system}:(OI)(CI)F","*${OperatorSid}:(OI)(CI)RX")
    foreach ($child in @(Get-ChildItem -LiteralPath $results -Force)) {
      Assert-NoReparsePoint -LiteralPath $child.FullName
      Invoke-ProtectedIcacls -Arguments @($child.FullName,'/L','/setowner',$admins)
      Invoke-ProtectedIcacls -Arguments @($child.FullName,'/L','/inheritance:r','/grant:r',"${admins}:F","${system}:F","*${OperatorSid}:R")
    }
    $audit = Join-Path $LiteralPath 'audit.jsonl'
    if (Test-Path -LiteralPath $audit) { Assert-NoReparsePoint -LiteralPath $audit; Invoke-ProtectedIcacls -Arguments @($audit,'/setowner',$admins); Invoke-ProtectedIcacls -Arguments @($audit,'/inheritance:r','/grant:r',"${admins}:F","${system}:F","*${OperatorSid}:R") }
    $ledger = Join-Path $LiteralPath 'processed-requests.jsonl'
    if (Test-Path -LiteralPath $ledger) { Assert-NoReparsePoint -LiteralPath $ledger; Invoke-ProtectedIcacls -Arguments @($ledger,'/setowner',$admins); Invoke-ProtectedIcacls -Arguments @($ledger,'/inheritance:r','/grant:r',"${admins}:F","${system}:F") }
  }
}

function Register-MaintenanceTask {
  param([Parameter(Mandatory)][string]$OperatorSid)
  # The worker is launched through cmd.exe with /d (no per-user AutoRun)
  # running the hash-pinned launch-worker.bat from the protected payload.
  # That launcher clears the ENTIRE inherited S4U environment and rebuilds
  # a fixed allowlist of well-known literals, so no operator-controlled
  # variable - .NET startup hooks, CoreCLR profilers, runtime roots, or
  # their siblings - can reach a .NET host before the worker script runs.
  $action = New-ScheduledTaskAction -Execute 'C:\Windows\System32\cmd.exe' -Argument '/d /c "C:\Program Files\ai-devops\windows-runner-maintenance\launch-worker.bat"'
  $principal = New-ScheduledTaskPrincipal -UserId $OperatorSid -LogonType S4U -RunLevel Highest
  $settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::FromMinutes(6)) -StartWhenAvailable:$false
  Register-ScheduledTask -TaskPath $script:TaskFolder -TaskName $script:TaskName -Action $action -Principal $principal -Settings $settings -Force | Out-Null
}

function Assert-NoPerUserComOverride {
  # The installer runs elevated under the same account the operator uses,
  # so its HKCU is operator-writable too: a per-user ProgID or CLSID
  # registration for the Task Scheduler COM class would load operator code
  # into this elevated process. Both resolution channels are refused.
  $scheduleServiceClsid = '{148BD52A-A2AB-11CE-B07F-00AA006C7A83}'
  if (Test-Path -LiteralPath 'HKCU:\Software\Classes\Schedule.Service') { throw 'PER_USER_COM_OVERRIDE' }
  if (Test-Path -LiteralPath 'HKCU:\Software\Classes\Schedule.Service.1') { throw 'PER_USER_COM_OVERRIDE' }
  if (Test-Path -LiteralPath "HKCU:\Software\Classes\CLSID\$scheduleServiceClsid") { throw 'PER_USER_COM_OVERRIDE' }
}

function Test-TaskDaclEquivalent {
  # Task Scheduler on current Windows 11 builds returns an EMPTY string for
  # a descriptor read with flag 0 even elevated, and stores generic rights mapped
  # (GRGX -> 0x1200a9) with auto-inherit flags (D:PAI). The DACL is therefore
  # read with DACL_SECURITY_INFORMATION (4) and compared semantically: same
  # protected flag, and exactly the same set of (type, SID, mapped mask) ACEs.
  param([AllowEmptyString()][string]$Actual, [Parameter(Mandatory)][string]$Expected)
  if ([string]::IsNullOrWhiteSpace($Actual)) { return $false }
  $map = { param([int]$m)
    $r = $m -band 0x0FFFFFFF
    if ($m -band 0x80000000) { $r = $r -bor 0x120089 }
    if ($m -band 0x40000000) { $r = $r -bor 0x120116 }
    if ($m -band 0x20000000) { $r = $r -bor 0x1200a0 }
    if ($m -band 0x10000000) { $r = $r -bor 0x1F01FF }
    $r }
  $parse = { param([string]$s)
    try { $sd = [Security.AccessControl.RawSecurityDescriptor]::new($s) } catch { return $null }
    if ($null -eq $sd.DiscretionaryAcl) { return $null }
    $aces = @(foreach ($ace in $sd.DiscretionaryAcl) {
      if ($ace -isnot [Security.AccessControl.CommonAce]) { 'unsupported' } else { '{0}|{1}|{2}' -f $ace.AceQualifier, $ace.SecurityIdentifier.Value, (& $map $ace.AccessMask) } })
    [pscustomobject]@{ Protected = (($sd.ControlFlags -band [Security.AccessControl.ControlFlags]::DiscretionaryAclProtected) -ne 0); Aces = @($aces | Sort-Object) } }
  $a = & $parse $Actual; $e = & $parse $Expected
  if ($null -eq $a -or $null -eq $e -or $a.Protected -ne $e.Protected -or $a.Aces.Count -ne $e.Aces.Count) { return $false }
  for ($i = 0; $i -lt $a.Aces.Count; $i++) { if ($a.Aces[$i] -cne $e.Aces[$i]) { return $false } }
  return $true
}

function Set-MaintenanceTaskAcl {
  param([Parameter(Mandatory)][string]$OperatorSid)
  Assert-NoPerUserComOverride
  $service = New-Object -ComObject 'Schedule.Service'
  $service.Connect()
  $task = $service.GetFolder($script:TaskFolderCom).GetTask($script:TaskName)
  $sddl = "D:P(A;;FA;;;SY)(A;;FA;;;BA)(A;;GRGX;;;$OperatorSid)"
  # 0x10 = TASK_DONT_ADD_PRINCIPAL_ACE: without it Windows silently adds an
  # extra principal ACE and drops the protected flag.
  $task.SetSecurityDescriptor($sddl, 0x10)
  return $sddl
}

function Set-MaintenanceTaskTeardownAcl {
  # Teardown descriptor: administrators and SYSTEM only. Removing the
  # operator ACE entirely closes the start window instead of detecting a
  # start after the fact; a GRGX-only seal would still allow Start.
  Assert-NoPerUserComOverride
  $service = New-Object -ComObject 'Schedule.Service'
  $service.Connect()
  $task = $service.GetFolder($script:TaskFolderCom).GetTask($script:TaskName)
  $sddl = 'D:P(A;;FA;;;SY)(A;;FA;;;BA)'
  # 0x10 = TASK_DONT_ADD_PRINCIPAL_ACE: without it Windows silently adds an
  # extra principal ACE and drops the protected flag.
  $task.SetSecurityDescriptor($sddl, 0x10)
  return $sddl
}

function Resolve-TaskIdentitySid {
  # Task Scheduler may report the principal as a local account name or as a
  # SID string depending on how it was registered and which token queries it.
  param([Parameter(Mandatory)][string]$Identity)
  if ($Identity -match '^S-1-5-21-') { return $Identity }
  return ([Security.Principal.NTAccount]$Identity).Translate([Security.Principal.SecurityIdentifier]).Value
}

function Get-InstalledTaskSnapshot {
  $task = Get-ScheduledTask -TaskPath $script:TaskFolder -TaskName $script:TaskName -ErrorAction Stop
  Assert-NoPerUserComOverride
  $service = New-Object -ComObject 'Schedule.Service'
  $service.Connect()
  $sddl = [string]$service.GetFolder($script:TaskFolderCom).GetTask($script:TaskName).GetSecurityDescriptor(4)
  # A filtered remote token returns an empty descriptor rather than an error.
  # Callers that must reason about permissions need an elevated read.
  if ([string]::IsNullOrWhiteSpace($sddl)) { throw 'TASK_SDDL_UNREADABLE: elevated token is required to read the task security descriptor.' }
  return [ordered]@{
    execute = [string]$task.Actions[0].Execute
    arguments = [string]$task.Actions[0].Arguments
    action_count = @($task.Actions | Where-Object { $null -ne $_ }).Count
    user_id = [string]$task.Principal.UserId
    logon_type = [string]$task.Principal.LogonType
    run_level = [string]$task.Principal.RunLevel
    # @($null).Count is 1 in PowerShell: a triggerless task reports a null
    # Triggers collection, so nulls are filtered before counting.
    trigger_count = @($task.Triggers | Where-Object { $null -ne $_ }).Count
    multiple_instances = [string]$task.Settings.MultipleInstances
    sddl = $sddl
    state = [string]$task.State
  }
}

function Test-PathAclContract {
  param([Parameter(Mandatory)][string]$LiteralPath, [Parameter(Mandatory)][string]$OperatorSid, [ValidateSet('Payload','RuntimeRoot','Requests','Results','Audit','Ledger','Evidence','EvidenceParent','Temp')][string]$Kind)
  Assert-NoReparsePoint -LiteralPath $LiteralPath
  $acl = Get-Acl -LiteralPath $LiteralPath
  $ownerSid = ([Security.Principal.NTAccount]$acl.Owner).Translate([Security.Principal.SecurityIdentifier]).Value
  if ($ownerSid -notin @('S-1-5-32-544','S-1-5-18')) { throw "STALE_INSTALLATION: foreign owner on $Kind." }
  $allowedIdentities = @('S-1-5-32-544','S-1-5-18',$OperatorSid)
  if ($Kind -eq 'Evidence') { $allowedIdentities = @('S-1-5-32-544','S-1-5-18','S-1-1-0') }
  if ($Kind -eq 'Temp') { $allowedIdentities = @('S-1-5-32-544','S-1-5-18') }
  if ($Kind -eq 'EvidenceParent') { $allowedIdentities = @('S-1-5-32-544','S-1-5-18','S-1-5-32-545') }
  $rules = @($acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]))
  $unexpected = @($rules | Where-Object { $_.AccessControlType -ne 'Allow' -or $_.IdentityReference.Value -notin $allowedIdentities })
  if ($unexpected.Count -ne 0) { throw "STALE_INSTALLATION: unexpected ACL identity on $Kind." }
  foreach ($required in @('S-1-5-32-544','S-1-5-18')) {
    if (-not ($rules | Where-Object { $_.IdentityReference.Value -eq $required -and ($_.FileSystemRights -band [Security.AccessControl.FileSystemRights]::FullControl) })) { throw "STALE_INSTALLATION: missing protected ACL on $Kind." }
  }
  if ($Kind -eq 'Evidence') {
    # The evidence gate stays world-READABLE exactly as ProgramData files
    # already are (the runner service account reads it), but read must
    # never drift into write or delete for any non-administrator.
    $worldRules = @($rules | Where-Object { $_.IdentityReference.Value -eq 'S-1-1-0' })
    if ($worldRules.Count -eq 0) { throw 'STALE_INSTALLATION: world read access missing on Evidence.' }
    if (@($worldRules | Where-Object { ($_.FileSystemRights -band [Security.AccessControl.FileSystemRights]::Write) -or ($_.FileSystemRights -band [Security.AccessControl.FileSystemRights]::Delete) }).Count -ne 0) { throw 'STALE_INSTALLATION: world access exceeds read on Evidence.' }
  }
  if ($Kind -eq 'EvidenceParent') {
    # Users may hold inherit-only read on the shared ProgramData root and
    # nothing else: no direct rights on the directory itself, and no write.
    $userRules = @($rules | Where-Object { $_.IdentityReference.Value -eq 'S-1-5-32-545' })
    if ($userRules.Count -eq 0) { throw 'STALE_INSTALLATION: Users read access missing on EvidenceParent.' }
    if (@($userRules | Where-Object { ($_.InheritanceFlags -eq [Security.AccessControl.InheritanceFlags]::None) -or ($_.FileSystemRights -band [Security.AccessControl.FileSystemRights]::Write) -or ($_.FileSystemRights -band [Security.AccessControl.FileSystemRights]::Delete) }).Count -ne 0) { throw 'STALE_INSTALLATION: Users access exceeds inherit-only read on EvidenceParent.' }
  }
  $operatorRules = @($rules | Where-Object { $_.IdentityReference.Value -eq $OperatorSid })
  if ($Kind -eq 'Ledger' -or $Kind -eq 'Evidence' -or $Kind -eq 'EvidenceParent' -or $Kind -eq 'Temp') { if ($operatorRules.Count -ne 0) { throw "STALE_INSTALLATION: operator access must not exist on $Kind." }; return }
  if ($operatorRules.Count -eq 0) { throw "STALE_INSTALLATION: operator ACL missing on $Kind." }
  $operatorRights = $operatorRules | ForEach-Object FileSystemRights
  $mayWrite = @($operatorRights | Where-Object { ($_ -band [Security.AccessControl.FileSystemRights]::Write) -or ($_ -band [Security.AccessControl.FileSystemRights]::Delete) -or ($_ -band [Security.AccessControl.FileSystemRights]::ChangePermissions) }).Count -ne 0
  if ($Kind -eq 'Requests') { if (-not $mayWrite) { throw "STALE_INSTALLATION: operator write access missing on $Kind." } }
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
  Test-PathAclContract -LiteralPath (Join-Path $script:RuntimeRoot 'temp') -OperatorSid $ExpectedOperatorSid -Kind Temp
  Test-PathAclContract -LiteralPath (Split-Path -Parent $script:EvidencePath) -OperatorSid $ExpectedOperatorSid -Kind EvidenceParent
  Test-PathAclContract -LiteralPath $script:EvidencePath -OperatorSid $ExpectedOperatorSid -Kind Evidence
  Test-PathAclContract -LiteralPath "$script:EvidencePath.tmp" -OperatorSid $ExpectedOperatorSid -Kind Evidence
  $task = Get-InstalledTaskSnapshot
  $expectedExecute = 'C:\Windows\System32\cmd.exe'
  $expectedArgs = '/d /c "C:\Program Files\ai-devops\windows-runner-maintenance\launch-worker.bat"'
  $expectedSddl = "D:P(A;;FA;;;SY)(A;;FA;;;BA)(A;;GRGX;;;$ExpectedOperatorSid)"
  if ($task.action_count -ne 1 -or $task.execute -cne $expectedExecute -or $task.arguments -cne $expectedArgs -or (Resolve-TaskIdentitySid -Identity $task.user_id) -cne $ExpectedOperatorSid -or $task.logon_type -cne 'S4U' -or $task.run_level -cne 'Highest' -or $task.trigger_count -ne 0 -or $task.multiple_instances -cne 'IgnoreNew' -or -not (Test-TaskDaclEquivalent -Actual $task.sddl -Expected $expectedSddl)) { throw 'STALE_INSTALLATION: scheduled task drift.' }
  return $true
}

function Copy-VerifiedTree {
  # Per-entry copy with a reparse check at the operation site. Copy-Item
  # -Recurse follows junctions; operator-writable trees (runtime requests)
  # must never be copied that way from an elevated process.
  param([Parameter(Mandatory)][string]$Source, [Parameter(Mandatory)][string]$TargetRoot)
  Assert-NoReparsePoint -LiteralPath $Source
  [IO.Directory]::CreateDirectory($TargetRoot) | Out-Null
  foreach ($child in @(Get-ChildItem -LiteralPath $Source -Force)) {
    Assert-NoReparsePoint -LiteralPath $child.FullName
    $target = Join-Path $TargetRoot $child.Name
    if ($child.PSIsContainer) { Copy-VerifiedTree -Source $child.FullName -TargetRoot $target }
    else { Copy-Item -LiteralPath $child.FullName -Destination $target -Force }
  }
}

function Backup-MaintenanceInstallation {
  param([Parameter(Mandatory)][string]$Destination)
  # The destination must be NEW, or an EMPTY Administrators/SYSTEM-owned
  # directory: re-ACLing an arbitrary pre-existing directory (for example
  # the machine-wide PowerShell tree an allowlisted root contains) would
  # strip access other software depends on. The ancestor chain is verified
  # against junctions before anything is created through it.
  $normalizedDestination = [IO.Path]::GetFullPath($Destination)
  foreach ($ownedRoot in @($script:PayloadRoot, $script:RuntimeRoot)) {
    # Require a boundary at a path separator: a sibling such as
    # windows-runner-maintenance-recovery-<ts> shares the runtime root
    # prefix without being inside the tree.
    $ownedFull = [IO.Path]::GetFullPath($ownedRoot)
    if (-not $ownedFull.EndsWith('\', [StringComparison]::Ordinal)) { $ownedFull += '\' }
    if ($normalizedDestination.StartsWith($ownedFull, [StringComparison]::OrdinalIgnoreCase) -or
        ($normalizedDestination + '\') -eq $ownedFull) {
      throw 'Recovery backup path must not be inside the installation trees.'
    }
  }
  if (Test-Path -LiteralPath $Destination) {
    Assert-NoForeignOwnership -LiteralPath $Destination
    if (@(Get-ChildItem -LiteralPath $Destination -Force).Count -ne 0) { throw "Recovery backup destination exists and is not empty: $Destination" }
  }
  Assert-SafeBackupChain -LiteralPath $Destination
  New-Item -ItemType Directory -Path $Destination -Force | Out-Null
  # The recovery bundle must be admin-only wherever it lands, and must not
  # itself be a redirection target.
  Assert-NoReparsePoint -LiteralPath $Destination
  Invoke-ProtectedIcacls -Arguments @($Destination,'/setowner','*S-1-5-32-544')
  Invoke-ProtectedIcacls -Arguments @($Destination,'/inheritance:r','/grant:r','*S-1-5-32-544:(OI)(CI)F','*S-1-5-18:(OI)(CI)F')
  $task = Get-ScheduledTask -TaskPath $script:TaskFolder -TaskName $script:TaskName -ErrorAction SilentlyContinue
  if ($null -ne $task) { Export-ScheduledTask -TaskPath $script:TaskFolder -TaskName $script:TaskName | Set-Content -LiteralPath (Join-Path $Destination 'task.xml') -Encoding utf8 }
  if (Test-Path -LiteralPath $script:PayloadRoot) {
    # Operator holds read/execute only on payload, but the copy still uses the
    # per-entry verified walker so no elevated recursive copy can follow a
    # junction planted at any depth.
    Copy-VerifiedTree -Source $script:PayloadRoot -TargetRoot (Join-Path $Destination 'payload')
  }
  # Runtime request/result/audit/replay records are part of the durable state
  # of this boundary. Recovery keeps the live copies in place; the bundle
  # carries a pinned per-entry copy. Never Copy-Item -Recurse here: requests
  # is operator-writable by design.
  if (Test-Path -LiteralPath $script:RuntimeRoot) {
    Copy-VerifiedTree -Source $script:RuntimeRoot -TargetRoot (Join-Path $Destination 'runtime')
  }
  @{ schema_version=1; task_path=$script:TaskPath; backed_up_at_utc=[DateTime]::UtcNow.ToString('o') } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $Destination 'recovery.json') -Encoding utf8
}

function Protect-EvidenceFile {
  # The qualification evidence is the TPM/Secure Boot gate CI consumes, and
  # this boundary makes it remotely refreshable, so neither the gate itself
  # nor its atomic-replace tmp sibling may ever sit as a pre-created
  # attacker-owned file. The PARENT directory is pinned as well: ProgramData
  # defaults let any local user create entries there, while the pinned
  # contract keeps every existing reader reading and only admins creating.
  # Existing evidence content (including a manual preflight's) is preserved.
  param([Parameter(Mandatory)][string]$OperatorSid)
  $parent = Split-Path -Parent $script:EvidencePath
  New-Item -ItemType Directory -Path $parent -Force | Out-Null
  Assert-NoForeignOwnership -LiteralPath $parent
  Set-ProtectedFilesystemAcl -LiteralPath $parent -OperatorSid $OperatorSid -Kind EvidenceParent
  $tmpSibling = "$script:EvidencePath.tmp"
  foreach ($path in @($script:EvidencePath, $tmpSibling)) {
    Assert-NoForeignOwnership -LiteralPath $path
    if (-not (Test-Path -LiteralPath $path)) {
      [IO.File]::WriteAllBytes($path, [byte[]]@())
    }
    Set-ProtectedFilesystemAcl -LiteralPath $path -OperatorSid $OperatorSid -Kind Evidence
  }
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
  # The runtime parent's ownership is verified BEFORE the payload and
  # runtime trees are created beneath it: an operator-owned ProgramData
  # directory must stop the install immediately, not after owned state
  # has already been written under it.
  Assert-NoForeignOwnership -LiteralPath $runtimeParent
  # Nothing pre-existing under the runtime root may be foreign-owned: a
  # pre-planted audit trail or replay ledger must never be adopted.
  Assert-NoForeignOwnership -LiteralPath $script:RuntimeRoot
  Assert-NoForeignOwnership -LiteralPath (Join-Path $script:RuntimeRoot 'requests')
  Assert-NoForeignOwnership -LiteralPath (Join-Path $script:RuntimeRoot 'results')
  Assert-NoForeignOwnership -LiteralPath (Join-Path $script:RuntimeRoot 'audit.jsonl')
  Assert-NoForeignOwnership -LiteralPath (Join-Path $script:RuntimeRoot 'processed-requests.jsonl')
  # Assert the runtime root itself BEFORE anything is created through it:
  # a pre-planted junction at that name would otherwise redirect the
  # requests/results/audit creations outside the intended boundary.
  if (-not (Test-Path -LiteralPath $script:RuntimeRoot)) { New-Item -ItemType Directory -Path $script:RuntimeRoot | Out-Null }
  Assert-NoReparsePoint -LiteralPath $script:RuntimeRoot
  New-Item -ItemType Directory -Path (Join-Path $script:RuntimeRoot 'requests'), (Join-Path $script:RuntimeRoot 'results') -Force | Out-Null
  foreach ($name in @('audit.jsonl','processed-requests.jsonl')) { $p = Join-Path $script:RuntimeRoot $name; if (-not (Test-Path -LiteralPath $p)) { [IO.File]::WriteAllBytes($p, [byte[]]@()) } }
  Assert-NoForeignOwnership -LiteralPath (Join-Path $script:RuntimeRoot 'temp')
  New-Item -ItemType Directory -Path (Join-Path $script:RuntimeRoot 'temp') -Force | Out-Null
  Set-ProtectedFilesystemAcl -LiteralPath $script:PayloadRoot -OperatorSid $OperatorSid -Kind Payload
  Set-ProtectedFilesystemAcl -LiteralPath $script:RuntimeRoot -OperatorSid $OperatorSid -Kind Runtime
  Set-ProtectedFilesystemAcl -LiteralPath (Join-Path $script:RuntimeRoot 'temp') -OperatorSid $OperatorSid -Kind Temp
  Protect-EvidenceFile -OperatorSid $OperatorSid
}

function Remove-MaintenanceInstallation {
  param([Parameter(Mandatory)][string]$ExpectedOperatorSid, [string]$RecoveryPath, [switch]$RequireManifestMatch, [string]$SourceRoot)
  if (-not (Test-Path -LiteralPath $script:PayloadRoot) -and $null -eq (Get-ScheduledTask -TaskPath $script:TaskFolder -TaskName $script:TaskName -ErrorAction SilentlyContinue)) { return 'ABSENT' }
  Test-MaintenanceInstallation -ExpectedOperatorSid $ExpectedOperatorSid | Out-Null
  if ($RequireManifestMatch) {
    # The documented stricter rollback gate: removal may only proceed when
    # the installed payload is byte-identical to the repository checkout the
    # operator is removing from, so a rollback always removes exactly what
    # was reviewed. Default removal still verifies ownership and internal
    # consistency unconditionally.
    $desired = Get-DesiredPayloadManifest -SourceRoot $SourceRoot -OperatorSid $ExpectedOperatorSid
    $installed = Get-Content -Raw -LiteralPath (Join-Path $script:PayloadRoot 'manifest.json') | ConvertFrom-Json
    foreach ($name in @('windows-runner-maintenance-worker.ps1','launch-worker.bat','qualify-windows-runner.ps1')) {
      if ([string]$installed.files.$name -cne [string]$desired.files[$name]) { throw "RECOVERY_MANIFEST_MISMATCH: installed $name does not match this repository checkout." }
    }
  }
  if ((Get-InstalledTaskSnapshot).state -eq 'Running') { throw 'RECOVERY_RUNNING_TASK: wait for the bounded task to stop before removal.' }
  if ([string]::IsNullOrWhiteSpace($RecoveryPath)) { $RecoveryPath = Join-Path (Split-Path -Parent $script:RuntimeRoot) ('windows-runner-maintenance-recovery-' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')) }
  # The rollback bundle must land under an administrator-managed root: task
  # XML and payload copies never go to user profiles, UNC shares, or other
  # operator-writable locations. The bundle directory itself is additionally
  # pinned Administrators/SYSTEM-only after creation.
  if (-not [IO.Path]::IsPathRooted($RecoveryPath)) { throw 'Recovery backup path must be absolute.' }
  $normalizedRecovery = [IO.Path]::GetFullPath($RecoveryPath)
  $adminRoots = @('C:\ProgramData\', 'C:\Program Files\', 'C:\Windows\')
  if (-not @($adminRoots | Where-Object { $normalizedRecovery.StartsWith($_, [StringComparison]::OrdinalIgnoreCase) }).Count) { throw 'Recovery backup path must be under an administrator-managed root (ProgramData, Program Files or Windows).' }
  Backup-MaintenanceInstallation -Destination $RecoveryPath
  Unregister-ScheduledTask -TaskPath $script:TaskFolder -TaskName $script:TaskName -Confirm:$false
  # Re-verify immediately before every elevated recursive delete: the
  # verification at the top of removal is separated from these deletes by
  # a backup and an unregister, and the operator can plant a junction in
  # place under the payload root or the runtime root at any time.
  Assert-NoReparsePoint -LiteralPath $script:PayloadRoot
  Assert-NoForeignOwnership -LiteralPath $script:PayloadRoot
  Remove-Item -LiteralPath $script:PayloadRoot -Recurse -Force
  foreach ($name in $script:OwnedRuntimeNames) {
    $path = Join-Path $script:RuntimeRoot $name
    if (Test-Path -LiteralPath $path) {
      Assert-NoReparsePoint -LiteralPath $path
      Assert-NoForeignOwnership -LiteralPath $path
      Remove-Item -LiteralPath $path -Recurse -Force
    }
  }
  return 'REMOVED'
}

function Recover-MaintenanceInstallation {
  # Recovery of a PARTIAL or drifted installation (for example one that
  # failed mid-run after task registration, leaving a registered task and/or
  # installed trees that fail Test-MaintenanceInstallation and therefore block
  # both -Install and -Remove). This runs INSIDE the hardened installer
  # process - pinned module path, hostile-variable refusal - and refuses the
  # per-user COM overrides before its first task cmdlet.
  #
  # Identity: a partial install never reached the sealed task DACL, so recovery
  # must identify the task by its fixed action, principal, S4U/Highest run
  # level, empty trigger set, and IgnoreNew policy - not by requiring the
  # already-sealed descriptor. Payload present must still hash-match its
  # administrator-owned manifest.
  #
  # Race: a GRGX operator can Start-ScheduledTask during teardown. Recovery
  # therefore drops the operator ACE entirely (admins/SYSTEM only) before
  # disable, stops any instance that landed first, waits for a non-running
  # state, re-checks full identity, and only then unregisters. The window is
  # narrowed to Start-ScheduledTask issued before the teardown descriptor;
  # a surviving worker is still only the hash-verified fixed payload. Runtime
  # request/result/audit/replay records stay in place; the backup bundle also
  # carries a pinned copy. Qualification evidence, its tmp sibling, and the
  # parent directory are never touched.
  param([Parameter(Mandatory)][string]$ExpectedOperatorSid, [string]$RecoveryPath)
  Assert-NoPerUserComOverride
  $task = Get-ScheduledTask -TaskPath $script:TaskFolder -TaskName $script:TaskName -ErrorAction SilentlyContinue
  $payloadPresent = Test-Path -LiteralPath $script:PayloadRoot
  if ($null -eq $task -and -not $payloadPresent) { return 'ABSENT' }
  if ($null -ne $task -and [string]$task.State -eq 'Running') { throw 'RECOVERY_RUNNING_TASK: wait for the bounded task to stop before recovery.' }
  $expectedExecute = 'C:\Windows\System32\cmd.exe'
  $expectedArgs = '/d /c "C:\Program Files\ai-devops\windows-runner-maintenance\launch-worker.bat"'
  $snapshot = $null
  if ($null -ne $task) {
    $snapshot = Get-InstalledTaskSnapshot
    $taskSid = Resolve-TaskIdentitySid -Identity $snapshot.user_id
    if ($snapshot.action_count -ne 1 -or $snapshot.execute -cne $expectedExecute -or
        $snapshot.arguments -cne $expectedArgs -or $taskSid -cne $ExpectedOperatorSid -or
        $snapshot.logon_type -cne 'S4U' -or $snapshot.run_level -cne 'Highest' -or
        $snapshot.trigger_count -ne 0 -or $snapshot.multiple_instances -cne 'IgnoreNew') {
      throw 'RECOVERY_IDENTITY_MISMATCH: scheduled task is not the expected maintenance task.'
    }
  }
  if ($payloadPresent) {
    Assert-NoReparsePoint -LiteralPath $script:PayloadRoot
    Assert-NoForeignOwnership -LiteralPath $script:PayloadRoot
    # A partial install made by an installer before #1312 left every payload
    # file with an empty DACL. Restore the intended file grants on the
    # administrator-owned files only, then verify identity and hashes as before.
    foreach ($child in @(Get-ChildItem -LiteralPath $script:PayloadRoot -Force -File)) { Assert-NoForeignOwnership -LiteralPath $child.FullName }
    Set-PayloadFileAcl -LiteralPath $script:PayloadRoot -OperatorSid $ExpectedOperatorSid
    $manifest = Get-Content -Raw -LiteralPath (Join-Path $script:PayloadRoot 'manifest.json') | ConvertFrom-Json
    if ($manifest.schema_version -ne 1 -or $manifest.owner -cne 'popcre/ai-devops#262' -or
        $manifest.task_path -cne $script:TaskPath -or $manifest.operator_sid -cne $ExpectedOperatorSid) {
      throw 'RECOVERY_IDENTITY_MISMATCH: payload manifest does not identify this installation.'
    }
    $expectedFiles = @('windows-runner-maintenance-worker.ps1', 'launch-worker.bat',
      'qualify-windows-runner.ps1', 'windows-runner-maintenance-policy.json')
    $actualFiles = @($manifest.files.PSObject.Properties.Name)
    if ($actualFiles.Count -ne $expectedFiles.Count -or @($actualFiles | Where-Object { $_ -cnotin $expectedFiles }).Count -ne 0) {
      throw 'RECOVERY_IDENTITY_MISMATCH: payload file list drift.'
    }
    $diskFiles = @(Get-ChildItem -LiteralPath $script:PayloadRoot -Force -File | Select-Object -ExpandProperty Name)
    $allowedDisk = @($expectedFiles + 'manifest.json')
    if ($diskFiles.Count -ne $allowedDisk.Count -or @($diskFiles | Where-Object { $_ -cnotin $allowedDisk }).Count -ne 0) {
      throw 'RECOVERY_IDENTITY_MISMATCH: payload file list drift.'
    }
    foreach ($file in $manifest.files.PSObject.Properties) {
      $path = Join-Path $script:PayloadRoot $file.Name
      if ((Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant() -cne [string]$file.Value) {
        throw 'RECOVERY_IDENTITY_MISMATCH: payload hash drift.'
      }
    }
  }
  if ([string]::IsNullOrWhiteSpace($RecoveryPath)) { $RecoveryPath = Join-Path (Split-Path -Parent $script:RuntimeRoot) ('windows-runner-maintenance-recovery-partial-' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')) }
  if (-not [IO.Path]::IsPathRooted($RecoveryPath)) { throw 'Recovery backup path must be absolute.' }
  $normalizedRecovery = [IO.Path]::GetFullPath($RecoveryPath)
  $adminRoots = @('C:\ProgramData\', 'C:\Program Files\', 'C:\Windows\')
  if (-not @($adminRoots | Where-Object { $normalizedRecovery.StartsWith($_, [StringComparison]::OrdinalIgnoreCase) }).Count) { throw 'Recovery backup path must be under an administrator-managed root (ProgramData, Program Files or Windows).' }
  Assert-SafeBackupChain -LiteralPath $RecoveryPath
  if ($payloadPresent) {
    Assert-NoReparsePoint -LiteralPath $script:PayloadRoot
    Assert-NoForeignOwnership -LiteralPath $script:PayloadRoot
  }
  $runtimeParent = Split-Path -Parent $script:RuntimeRoot
  Assert-NoReparsePoint -LiteralPath $runtimeParent -AllowMissing
  Assert-NoForeignOwnership -LiteralPath $runtimeParent
  Assert-NoReparsePoint -LiteralPath $script:RuntimeRoot -AllowMissing
  Assert-NoForeignOwnership -LiteralPath $script:RuntimeRoot
  if ($null -ne $task) {
    # Close the start/unregister race before any backup window: drop the
    # operator ACE entirely (admins/SYSTEM only), then disable, then require
    # the full identity again. A GRGX seal would still permit Start.
    Set-MaintenanceTaskTeardownAcl | Out-Null
    $sealed = Get-InstalledTaskSnapshot
    $teardownSddl = 'D:P(A;;FA;;;SY)(A;;FA;;;BA)'
    if (-not (Test-TaskDaclEquivalent -Actual $sealed.sddl -Expected $teardownSddl)) { throw 'RECOVERY_SEAL_FAILED: scheduled task permissions were not sealed before recovery.' }
    Disable-ScheduledTask -TaskPath $script:TaskFolder -TaskName $script:TaskName | Out-Null
    # Start-ScheduledTask is asynchronous: stop any instance that landed
    # before the teardown descriptor, then wait for a terminal state.
    try { Stop-ScheduledTask -TaskPath $script:TaskFolder -TaskName $script:TaskName -ErrorAction SilentlyContinue } catch { }
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    do {
      $disabled = Get-InstalledTaskSnapshot
      if ($disabled.state -ne 'Running') { break }
      Start-Sleep -Milliseconds 250
    } while ([DateTime]::UtcNow -lt $deadline)
    $disabled = Get-InstalledTaskSnapshot
    if ($disabled.state -eq 'Running') { throw 'RECOVERY_RUNNING_TASK: wait for the bounded task to stop before recovery.' }
    if ($disabled.state -ne 'Disabled') { throw 'RECOVERY_SEAL_FAILED: scheduled task is not disabled before recovery.' }
    $disabledSid = Resolve-TaskIdentitySid -Identity $disabled.user_id
    if ($disabled.action_count -ne 1 -or $disabled.execute -cne $expectedExecute -or
        $disabled.arguments -cne $expectedArgs -or $disabledSid -cne $ExpectedOperatorSid -or
        $disabled.logon_type -cne 'S4U' -or $disabled.run_level -cne 'Highest' -or
        $disabled.trigger_count -ne 0 -or $disabled.multiple_instances -cne 'IgnoreNew') {
      throw 'RECOVERY_IDENTITY_MISMATCH: scheduled task changed before unregister.'
    }
  }
  Repair-RuntimeResultFileAcl -OperatorSid $ExpectedOperatorSid
  Backup-MaintenanceInstallation -Destination $RecoveryPath
  if ($null -ne $task) {
    Unregister-ScheduledTask -TaskPath $script:TaskFolder -TaskName $script:TaskName -Confirm:$false
  }
  # Re-verify immediately before the elevated recursive payload delete. Runtime
  # request/result/audit/replay records stay in place; only the protected
  # payload tree is removed so a clean install can replace it. Qualification
  # evidence is never opened here.
  if ($payloadPresent) {
    Assert-NoReparsePoint -LiteralPath $script:PayloadRoot
    Assert-NoForeignOwnership -LiteralPath $script:PayloadRoot
    Remove-Item -LiteralPath $script:PayloadRoot -Recurse -Force
  }
  return 'RECOVERED'
}
function Invoke-InstallerMain {
  $sid = Resolve-OperatorSid -User $OperatorUser
  $sourceRoot = Split-Path -Parent $PSScriptRoot
  if ($RecoverPartial) {
    Assert-Administrator
    $result = Recover-MaintenanceInstallation -ExpectedOperatorSid $sid -RecoveryPath $BackupPath
    Write-Output ("RECOVERY: " + $result)
    if (-not $Install -and -not $Update) { return }
  }
  if ($Remove) { Assert-Administrator; Remove-MaintenanceInstallation -ExpectedOperatorSid $sid -RecoveryPath $BackupPath -RequireManifestMatch:$RequireManifestMatch -SourceRoot $sourceRoot; return }
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
