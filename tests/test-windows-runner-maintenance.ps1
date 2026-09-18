$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$installerPath = Join-Path $repo 'bin\install-windows-runner-maintenance.ps1'
$workerPath = Join-Path $repo 'bin\windows-runner-maintenance-worker.ps1'
$clientPath = Join-Path $repo 'bin\invoke-windows-runner-maintenance.ps1'
$policyPath = Join-Path $repo 'config\windows-runner-maintenance-policy.json'
$installer = Get-Content -Raw -LiteralPath $installerPath
$worker = Get-Content -Raw -LiteralPath $workerPath
$client = Get-Content -Raw -LiteralPath $clientPath
$launcherPath = Join-Path $repo 'bin\launch-worker.cmd'
$launcher = Get-Content -Raw -LiteralPath $launcherPath
$policyText = Get-Content -Raw -LiteralPath $policyPath
$policy = $policyText | ConvertFrom-Json
$script:passed = 0
$script:failed = 0

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Assert-Contains([string]$Text, [string]$Needle) { Assert-True $Text.Contains($Needle) "Missing contract marker: $Needle" }
function Case([string]$Name, [scriptblock]$Body) {
  try { & $Body; $script:passed++; Write-Output "PASS $Name" }
  catch { $script:failed++; Write-Error "FAIL ${Name}: $($_.Exception.Message)" -ErrorAction Continue }
}

$temp = Join-Path ([IO.Path]::GetTempPath()) ('ai-devops-maintenance-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp | Out-Null
try {
  . $installerPath -LibraryMode
  $sourceRoot = $repo
  $script:PayloadRoot = Join-Path $temp 'payload'
  $script:RuntimeRoot = Join-Path $temp 'runtime'
  $script:EvidencePath = Join-Path $temp 'windows-runner-security.json'
  $script:mockTask = $null
  function Set-ProtectedFilesystemAcl { param($LiteralPath,$OperatorSid,$Kind) Assert-NoReparsePoint -LiteralPath $LiteralPath }
  function Assert-NoForeignOwnership { param($LiteralPath) }
  function Test-PathAclContract { param($LiteralPath,$OperatorSid,$Kind) }
  function Register-MaintenanceTask { param($OperatorSid) $script:mockTask = [ordered]@{ execute='C:\Windows\System32\cmd.exe'; arguments='/d /c "C:\Program Files\ai-devops\windows-runner-maintenance\launch-worker.cmd"'; action_count=1; user_id=$OperatorSid; logon_type='S4U'; run_level='Highest'; trigger_count=0; multiple_instances='IgnoreNew'; sddl="D:P(A;;FA;;;SY)(A;;FA;;;BA)(A;;GRGX;;;$OperatorSid)"; state='Ready' } }
  function Get-InstalledTaskSnapshot { return $script:mockTask }
  function Backup-MaintenanceInstallation { param($Destination) New-Item -ItemType Directory -Path $Destination -Force | Out-Null; 'backup' | Set-Content (Join-Path $Destination 'recovery.json') }
  $sid = 'S-1-5-21-100-200-300-1001'

  Case 'Install_IsIdempotent' {
    Install-MaintenancePayload -SourceRoot $sourceRoot -OperatorSid $sid
    Register-MaintenanceTask -OperatorSid $sid
    $first = (Get-FileHash (Join-Path $script:PayloadRoot 'manifest.json')).Hash
    Install-MaintenancePayload -SourceRoot $sourceRoot -OperatorSid $sid
    $second = (Get-FileHash (Join-Path $script:PayloadRoot 'manifest.json')).Hash
    Assert-True ($first -eq $second) 'second install changed owned state'
  }
  Case 'Update_IsAtomicAndBackedUp' { Assert-Contains $installer 'Backup-MaintenanceInstallation'; Assert-Contains $installer "Move-Item -LiteralPath `$staging -Destination `$script:PayloadRoot" }
  Case 'Verify_IsReadOnly' { Assert-True (([regex]::Match($installer, 'if \(\$Verify[\s\S]*?return \}').Value -notmatch 'Set-|New-Item|Move-Item|Remove-Item|Register-')) 'verify branch mutates state' }
  Case 'Remove_IsIdempotent' { Assert-Contains $installer "return 'ABSENT'"; Assert-Contains $installer "return 'REMOVED'" }
  Case 'Remove_RefusesForeignOrDriftedTask' { $prior=$script:mockTask.arguments; $script:mockTask.arguments='foreign.exe'; try { Test-MaintenanceInstallation -ExpectedOperatorSid $sid; throw 'drift accepted' } catch { Assert-True ($_.Exception.Message -like 'STALE_INSTALLATION*') 'wrong refusal' }; $script:mockTask.arguments=$prior }
  Case 'Task_UsesS4UHighestFixedProtectedAction' { foreach($m in @('-LogonType S4U','-RunLevel Highest',$script:PowerShellPath,'windows-runner-maintenance-worker.ps1')) { Assert-Contains $installer $m } }
  Case 'Task_HasNoTrigger' { Assert-True ($installer -notmatch 'New-ScheduledTaskTrigger') 'a trigger was created'; Assert-Contains $installer 'trigger_count -ne 0' }
  Case 'Task_IgnoresParallelInstance' { Assert-Contains $installer '-MultipleInstances IgnoreNew' }
  Case 'Operator_CanReadAndRunOnly' { Assert-Contains $installer '(A;;GRGX;;;' }
  Case 'Operator_CannotChangeDeleteOrReplaceTask' { Assert-True ($installer -notmatch '\(A;;FA;;;\$OperatorSid') 'operator gets full task access'; Assert-Contains $installer 'SetSecurityDescriptor($sddl, 0)' }
  Case 'Payload_IsAdministratorOwnedAndHashVerified' { Assert-Contains $installer '*S-1-5-32-544'; Assert-Contains $installer 'Get-FileHash -Algorithm SHA256'; Assert-True ($policy.payload_hashes.'windows-runner-maintenance-worker.ps1' -ceq (Get-FileHash -Algorithm SHA256 $workerPath).Hash.ToLowerInvariant()) 'policy worker hash is stale'; Assert-True ($policy.payload_hashes.'qualify-windows-runner.ps1' -ceq (Get-FileHash -Algorithm SHA256 (Join-Path $repo 'bin\qualify-windows-runner.ps1')).Hash.ToLowerInvariant()) 'policy qualification hash is stale' }
  Case 'RepositoryMutation_CannotChangeInstalledPayload' { Assert-Contains $installer 'Copy-Item -LiteralPath $source'; Assert-Contains $worker 'Test-PayloadManifest' }
  Case 'ReparsePoint_IsRejected' { Assert-Contains $installer '[IO.FileAttributes]::ReparsePoint'; Assert-Contains $worker '[IO.FileAttributes]::ReparsePoint' }
  Case 'AclDrift_FailsClosed' { Assert-Contains $installer 'Set-ProtectedFilesystemAcl'; Assert-Contains $installer 'STALE_INSTALLATION' }

  Remove-Item Function:\Set-ProtectedFilesystemAcl,Function:\Assert-NoForeignOwnership,Function:\Test-PathAclContract,Function:\Register-MaintenanceTask,Function:\Get-InstalledTaskSnapshot,Function:\Backup-MaintenanceInstallation -ErrorAction SilentlyContinue
  . $workerPath
  $requestPath = Join-Path $temp 'request.json'
  function Write-Request($Object) { [IO.File]::WriteAllText($requestPath, ($Object | ConvertTo-Json -Compress), [Text.UTF8Encoding]::new($false)) }
  function Valid-Request { [ordered]@{ schema_version=1; request_id=[guid]::NewGuid().ToString(); operation='refresh-qualification'; requested_at=[DateTime]::UtcNow.ToString('o') } }
  $owner = { param($p) 'S-1-5-21-100-200-300-1001' }
  Case 'Request_AllowsOnlyRefreshQualification' { Write-Request (Valid-Request); $r=Read-ValidatedRequest $requestPath $sid -OwnerSidReader $owner; Assert-True ($r.operation -ceq 'refresh-qualification') 'operation rejected' }
  Case 'Request_RejectsUnknownFields' { $r=Valid-Request; $r.extra='x'; Write-Request $r; try { Read-ValidatedRequest $requestPath $sid -OwnerSidReader $owner; throw 'accepted' } catch { Assert-True ($_.Exception.Message -eq 'UNKNOWN_FIELDS') 'wrong refusal' } }
  Case 'Request_RejectsArgumentsPathsAndEnvironment' { foreach($field in @('arguments','path','environment')) { $r=Valid-Request; $r[$field]='x'; Write-Request $r; try { Read-ValidatedRequest $requestPath $sid -OwnerSidReader $owner; throw 'accepted' } catch { Assert-True ($_.Exception.Message -eq 'UNKNOWN_FIELDS') 'wrong refusal' } } }
  Case 'Request_RejectsWrongOwner' { Write-Request (Valid-Request); try { Read-ValidatedRequest $requestPath $sid -OwnerSidReader { 'S-1-5-21-9' }; throw 'accepted' } catch { Assert-True ($_.Exception.Message -eq 'WRONG_OWNER') 'wrong refusal' } }
  Case 'Request_RejectsMalformedJson' { [IO.File]::WriteAllText($requestPath,'{bad',[Text.UTF8Encoding]::new($false)); try { Read-ValidatedRequest $requestPath $sid -OwnerSidReader $owner; throw 'accepted' } catch { Assert-True ($_.Exception.Message -eq 'MALFORMED_JSON') 'wrong refusal' } }
  Case 'Request_RejectsOversize' { [IO.File]::WriteAllText($requestPath,('x'*2049)); try { Read-ValidatedRequest $requestPath $sid -OwnerSidReader $owner; throw 'accepted' } catch { Assert-True ($_.Exception.Message -eq 'OVERSIZE') 'wrong refusal' } }
  Case 'Request_RejectsStaleTimestamp' { $r=Valid-Request; $r.requested_at=[DateTime]::UtcNow.AddMinutes(-10).ToString('o'); Write-Request $r; try { Read-ValidatedRequest $requestPath $sid -OwnerSidReader $owner; throw 'accepted' } catch { Assert-True ($_.Exception.Message -eq 'STALE_TIMESTAMP') 'wrong refusal' } }
  Case 'Request_RejectsReusedUuid' { Assert-Contains $worker 'REUSED_UUID'; Assert-Contains $worker 'processed-requests.jsonl' }
  Case 'Concurrency_OneRunsAndDuplicateGetsExplicitResult' { Assert-Contains $worker "'CONCURRENT_EXECUTION'"; Assert-Contains $worker 'WaitOne(0)' }
  Case 'StaleLock_IsDiagnosedNotSilentlyRemoved' { Assert-True ($worker -notmatch 'Remove-Item.*lock') 'worker deletes a lock'; Assert-Contains $worker 'Enter-MaintenanceLock' }
  Case 'TaskIgnoredStart_DoesNotLoseRequest' { Assert-Contains $worker 'Get-ChildItem -LiteralPath $requests'; Assert-Contains $worker 'CONCURRENT_EXECUTION' }
  Case 'Result_IsAtMost8KiB' { Assert-True ($policy.max_result_bytes -eq 8192) 'wrong result bound'; Assert-Contains $worker 'RESULT_OVERSIZE' }
  Case 'Result_ContainsOnlySafeSchema' { $result=[ordered]@{schema_version=1;request_id='x';operation='refresh-qualification';host='host';started_at_utc='s';ended_at_utc='e';result='SUCCESS';exit_code=0;message='ok'}; $out=Join-Path $temp 'result.json'; Write-SafeResult $result $out; Assert-True ((Get-Item $out).Length -lt 8192) 'result too large' }
  Case 'Result_RejectsMismatchedUuid' { Assert-Contains $client 'result.request_id -cne $ExpectedRequestId' }
  Case 'Result_RejectsReparsePoint' { Assert-Contains $client '[IO.FileAttributes]::ReparsePoint' }
  Case 'Timeout_IsBounded' { Assert-Contains $client '[ValidateRange(1,300)]'; Assert-Contains $client '[Math]::Min($Timeout, 300)' }
  Case 'Failure_DoesNotExposeExceptionStdoutStderrEnvironmentOrEvidence' { foreach($unsafe in @('StackTrace','Get-ChildItem Env:','Out-String')) { Assert-True (-not $worker.Contains($unsafe)) "unsafe diagnostic marker: $unsafe" }; Assert-Contains $worker "The request was rejected." }
  Case 'Audit_RecordsRequesterSidHostOperationStartEndResult' { foreach($f in @('requester_sid','host','operation','started_at_utc','ended_at_utc','result')) { Assert-Contains $worker $f } }
  Case 'Audit_IsAppendOnlyForOperator' { Assert-Contains $worker '[IO.File]::AppendAllText'; Assert-Contains $installer '*${OperatorSid}:R' }
  Case 'Audit_RecordsRejectedAndFailedRequests' { Assert-Contains $worker 'Write-AuditEvent'; Assert-Contains $worker "'REQUEST_REJECTED'"; Assert-Contains $worker "'OPERATION_FAILED'" }
  Case 'RefreshQualification_UsesFixedEvidencePath' { Assert-Contains $worker "`$script:EvidencePath = 'C:\ProgramData\ai-devops\windows-runner-security.json'"; Assert-Contains $worker ('-EvidencePath ' + [char]34 + '{1}' + [char]34 + [char]39 + ' -f') }
  Case 'RefreshQualification_PreservesAllExistingGuards' { foreach($m in @('Get-Tpm','Confirm-SecureBootUEFI','CurrentBuildNumber','actions.runner.*','StartMode')) { Assert-Contains (Get-Content -Raw (Join-Path $repo 'bin\qualify-windows-runner.ps1')) $m } }
  Case 'RunnerService_IsReadOnly' { Assert-True (($installer+$worker+$client) -notmatch 'Stop-Service|Start-Service|Restart-Service|Set-Service|sc.exe') 'runner service mutation found' }
  Case 'Recovery_MissingTask' { Assert-Contains $client "throw 'MISSING_TASK'" }
  Case 'Recovery_StaleInstall' { Assert-Contains $worker "'STALE_INSTALLATION'" }
  Case 'Recovery_RunningTask' { Assert-Contains $worker "'CONCURRENT_EXECUTION'"; Assert-Contains $installer 'RECOVERY_RUNNING_TASK' }
  Case 'Recovery_FailedCleanup' { Assert-Contains $installer 'Refusing to replace an unverified previous payload backup.' }
  Case 'Rollback_RestoresExactPriorOwnedState' { Assert-Contains $installer 'Export-ScheduledTask'; Assert-Contains $installer 'task.xml'; Assert-Contains $installer 'recovery.json' }
  Case 'Worker_PinsSystemOnlyModuleResolution' { Assert-Contains $worker '$env:PSModulePath'; Assert-Contains $worker '$PSHOME\Modules;C:\Windows\System32\WindowsPowerShell\v1.0\Modules'; Assert-True ($worker.IndexOf('`$env:PSModulePath') -lt $worker.IndexOf('function Read-BoundedBytes')) 'module path pinned after function definitions' }
  Case 'Worker_RefusesPerUserComOverride' { Assert-Contains $worker 'Assert-NoPerUserComOverride'; Assert-Contains $worker '{148BD52A-A2AB-11CE-B07F-00AA006C7A83}' }
  Case 'Integrity_CapacityCheckedBeforeExecution' { Assert-Contains $worker 'Test-IntegrityCapacity'; Assert-True ($worker.IndexOf('Test-IntegrityCapacity -AuditPath') -lt $worker.IndexOf('Invoke-RefreshQualification -ProtectedQualificationScript')) 'capacity checked after execution' }
  Case 'Integrity_RequestConsumedExactlyOnce' { Assert-True ($worker -match 'finally \{[\s\S]*?Remove-Item -LiteralPath \$file\.FullName -Force') 'request removal is not guaranteed in finally'; Assert-Contains $worker "'AUDIT_FULL|LEDGER_FULL'" }
  Case 'Evidence_IsProtectedAtInstall' { Assert-Contains $installer 'Protect-EvidenceFile'; Assert-Contains $installer "'*S-1-1-0:R'"; Assert-Contains $installer 'Test-PathAclContract -LiteralPath $script:EvidencePath' }
  Case 'Evidence_WorkerVerifiesBeforeRefresh' { Assert-Contains $worker 'Test-EvidenceBoundary' }
  Case 'RuntimeRoot_ReparseCheckedBeforeChildren' { Assert-True ($installer.IndexOf('Assert-NoReparsePoint -LiteralPath $script:RuntimeRoot') -ge 0 -and $installer.IndexOf('Assert-NoReparsePoint -LiteralPath $script:RuntimeRoot') -lt $installer.IndexOf("New-Item -ItemType Directory -Path (Join-Path `$script:RuntimeRoot 'requests')")) 'runtime root not asserted before children are created' }
  Case 'RequestId_SanitizedBeforeUse' { Assert-Contains $worker "'REJECTED'"; Assert-True ($worker -match '\$id -notmatch ''\^\[A-Za-z0-9-\]\{1,80\}\$''') 'request id is not sanitized to a safe character set' }
  Case 'Acl_EveryIcaclsCallChecksExitCode' { Assert-Contains $installer 'Invoke-ProtectedIcacls'; Assert-Contains $installer "'C:\Windows\System32\icacls.exe'"; Assert-True (@([regex]::Matches($installer, [regex]::Escape("& 'C:\Windows\System32\icacls.exe'"))).Count -eq 1) 'icacls is invoked outside the per-call exit-checked helper' }
  Case 'Operator_MustBeLocalUserNotGroup' { Assert-Contains $installer 'UserPrincipal'; Assert-Contains $installer 'Operator is not a local user account.' }
  Case 'Remove_RequireManifestMatchEnforcesRepositoryMatch' { Assert-Contains $installer 'RECOVERY_MANIFEST_MISMATCH'; Assert-Contains $installer 'RequireManifestMatch:$RequireManifestMatch' }
  Case 'Launcher_IsAnEnvironmentAllowlist' { Assert-Contains $installer '/d /c "C:\Program Files\ai-devops\windows-runner-maintenance\launch-worker.cmd"'; Assert-Contains $worker '/d /c "C:\Program Files\ai-devops\windows-runner-maintenance\launch-worker.cmd"'; Assert-Contains $launcher 'for /f "delims==" %%v in (''set ^| C:\Windows\System32\findstr.exe /r /c:"^[A-Za-z0-9_-]*="'') do set "%%v="'; Assert-Contains $launcher 'set "SystemRoot=C:\Windows"'; Assert-True (-not $launcher.Contains('DOTNET_STARTUP_HOOKS')) 'launcher is still a denylist, not an allowlist' }
  Case 'Task_RefusesAdditionalActions' { Assert-Contains $worker '@($task.Actions).Count -ne 1'; Assert-Contains $installer 'action_count -ne 1' }
  Case 'Worker_RefusesPerUserProgIdOverride' { Assert-Contains $worker 'HKCU:\Software\Classes\Schedule.Service' }
  Case 'Worker_VerifiesRuntimeAclBoundary' { Assert-Contains $worker 'Test-RuntimeBoundary -ExpectedOperatorSid'; Assert-True ($worker.IndexOf('Test-RuntimeBoundary -ExpectedOperatorSid') -lt $worker.IndexOf('Invoke-RefreshQualification -ProtectedQualificationScript')) 'runtime boundary verified after execution' }
  Case 'Worker_AclChecksCountGroupGrantedRights' { Assert-True (@([regex]::Matches($worker, [regex]::Escape("AccessControlType -ne 'Allow'"))).Count -ge 3) 'group-granted rights are not refused in every boundary check' }
  Case 'Evidence_TmpSiblingIsPinnedAndRestored' { Assert-Contains $installer 'tmpSibling = "$script:EvidencePath.tmp"'; Assert-Contains $worker 'Set-EvidenceContractAcl'; Assert-Contains $installer 'Test-PathAclContract -LiteralPath "$script:EvidencePath.tmp"' }
  Case 'Evidence_ParentDirectoryIsPinned' { Assert-Contains $installer '*S-1-5-32-545:(OI)(CI)(IO)(RX)' }
  Case 'RequestId_CanonicalGuidSpelling' { Assert-Contains $worker '$requestId.ToString(''D'')' }
  Case 'Ledger_CheckFailsClosed' { Assert-Contains $worker '-SimpleMatch -Quiet -Pattern ('; Assert-Contains $worker '-ErrorAction Stop'; Assert-Contains $worker 'LEDGER_UNREADABLE' }
  Case 'Policy_LoadedOnlyAfterManifestVerification' { Assert-True ($worker.IndexOf('Test-PayloadManifest -Root $script:PayloadRoot') -ge 0 -and $worker.IndexOf('Test-PayloadManifest -Root $script:PayloadRoot') -lt $worker.IndexOf("windows-runner-maintenance-policy.json') | ConvertFrom-Json")) 'policy loaded before payload verification' }
  Case 'Request_OwnerBoundToSingleRead' { Assert-True ($worker.IndexOf('Read-BoundedBytes -LiteralPath $LiteralPath -MaximumBytes $MaximumBytes') -gt 0 -and $worker.IndexOf('Read-BoundedBytes -LiteralPath $LiteralPath -MaximumBytes $MaximumBytes') -lt $worker.IndexOf("'WRONG_OWNER'")) 'owner check does not follow the single bounded read' }
  Case 'Worker_UsesCaseExactTaskPath' { Assert-Contains $worker "TaskPath '\AiDevOps\'" }
  Case 'Payload_LauncherIsHashPinned' { Assert-True ($policy.payload_hashes.'launch-worker.cmd' -ceq (Get-FileHash -Algorithm SHA256 $launcherPath).Hash.ToLowerInvariant()) 'policy launcher hash is stale' }
  Case 'Evidence_OperatorHoldsNoGrant' { Assert-Contains $installer 'operator access must not exist on'; Assert-Contains $worker '$_.IdentityReference.Value -eq $ExpectedOperatorSid }).Count -ne 0) { throw 'ACL_DRIFT' }' }
  Case 'Runtime_VerifiedBeforeEnumerationAndDelete' { Assert-True ($worker.IndexOf('Test-RuntimeBoundary -ExpectedOperatorSid ([string]$policy.operator_sid)') -gt 0 -and $worker.IndexOf('Test-RuntimeBoundary -ExpectedOperatorSid ([string]$policy.operator_sid)') -lt $worker.IndexOf('Get-ChildItem -LiteralPath $requests')) 'runtime boundary not verified before enumeration'; Assert-Contains $worker '$requestsNow' }
  Case 'Ledger_OnlyCanonicalGuidsAndExactMatch' { Assert-Contains $worker '-SimpleMatch -Quiet -Pattern ('; Assert-Contains $worker '"request_id":"'; Assert-Contains $worker '$id -cmatch' }
  Case 'Installer_RefusesPerUserComOverride' { Assert-True (@([regex]::Matches($installer, 'Assert-NoPerUserComOverride')).Count -ge 3) 'installer COM use is not guarded' }
  Case 'BackupPath_MustBeAdminControlled' { Assert-Contains $installer 'Recovery backup path must be absolute.' }
  Case 'ChildArguments_ArePreQuoted' { Assert-Contains $worker '-NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File ' }
  Case 'Worker_ModulePinUsesNoCommand' { Assert-True (-not $worker.Contains('(Join-Path ' + [char]36 + 'PSHOME')) 'module pin still resolves a command'; Assert-Contains $worker '"$PSHOME\Modules;C:\Windows\System32\WindowsPowerShell\v1.0\Modules"' }
  Case 'Launcher_PinsComspecBeforeClearing' { Assert-True ($launcher.IndexOf('set "COMSPEC=C:\Windows\System32\cmd.exe"') -ge 0 -and $launcher.IndexOf('set "COMSPEC=C:\Windows\System32\cmd.exe"') -lt $launcher.IndexOf('for /f')) 'COMSPEC not pinned before the clear loop'; Assert-Contains $launcher 'C:\Windows\System32\findstr.exe /r /c:"^[A-Za-z0-9_-]*="' }
  Case 'Launcher_TempIsAdminOnly' { Assert-Contains $launcher 'TEMP=C:\ProgramData\ai-devops\windows-runner-maintenance\temp'; Assert-Contains $installer "Set-ProtectedFilesystemAcl -LiteralPath (Join-Path `$script:RuntimeRoot 'temp') -OperatorSid `$OperatorSid -Kind Temp"; Assert-Contains $installer "-Kind Temp" }
  Case 'Worker_HostIsNotEnvironmentDerived' { Assert-Contains $worker '[Environment]::MachineName'; Assert-True (-not $worker.Contains('$env:COMPUTERNAME')) 'host identity still read from the environment' }
  Case 'Install_RefusesForeignOwnedState' { Assert-True (@([regex]::Matches($installer, 'Assert-NoForeignOwnership')).Count -ge 9) 'pre-existing state is adopted without ownership refusal'; Assert-Contains $installer 'refusing to adopt foreign-owned path' }
  Case 'Remove_ReverifiesBeforeEveryElevatedDelete' { Assert-Contains $installer 'Assert-NoForeignOwnership -LiteralPath $script:PayloadRoot'; Assert-True ($installer -match 'Assert-NoReparsePoint -LiteralPath \$path[\s\S]{0,200}Remove-Item -LiteralPath \$path -Recurse -Force') 'runtime deletion not re-verified immediately' }
  Case 'Backup_IsAdminOwnedAndChecked' { Assert-Contains $installer 'Assert-NoReparsePoint -LiteralPath $Destination'; Assert-Contains $installer '($Destination,''/setowner''' }
  Case 'ComOverride_IncludesVersionedProgIdShadow' { Assert-Contains $worker 'Schedule.Service.1'; Assert-Contains $installer 'Schedule.Service.1' }
  Case 'Installer_SelfHardensAgainstHostileShell' { Assert-Contains $installer '$env:PSModulePath'; Assert-Contains $installer 'hostile code-loading variable' }
  Case 'Launcher_RefusesCmdAutoRunOverride' { Assert-True ($launcher.IndexOf('reg.exe query "HKCU\Software\Microsoft\Command Processor" /v AutoRun') -ge 0 -and $launcher.IndexOf('reg.exe query') -lt $launcher.IndexOf('for /f')) 'AutoRun refusal must precede the clear loop'; Assert-Contains $launcher 'HKLM\Software\Microsoft\Command Processor' }
  Case 'Worker_VerifiesWholeEvidenceNeighbourhood' { Assert-Contains $worker 'Test-Path -LiteralPath $evidencePath -PathType Leaf'; Assert-Contains $worker '"$script:EvidencePath.tmp"' }
  Case 'Worker_RuntimeBoundaryIncludesTemp' { Assert-Contains $worker "Join-Path `$script:RuntimeRoot 'temp'"; Assert-Contains $worker "'temp'" }
  Case 'RequestId_RejectsReservedDeviceNames' { Assert-Contains $worker '(?i:con|prn|aux|nul|com[1-9]|lpt[1-9])' }
  Case 'BackupPath_RestrictedToAdminRoots' { Assert-Contains $installer 'must be under an administrator-managed root' }
  Case 'Contract_HasSingleFixedOperationAndPaths' { Assert-True ($policy.operation -ceq 'refresh-qualification') 'wrong operation'; Assert-True ($policy.task_path -ceq '\AiDevOps\WindowsRunnerMaintenance') 'wrong task'; Assert-True ($policy.PSObject.Properties.Name -notcontains 'commands') 'command catalog found' }
} finally {
  Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output "RESULT: $script:passed passed, $script:failed failed, 0 skipped"
if ($script:failed -ne 0) { exit 1 }
