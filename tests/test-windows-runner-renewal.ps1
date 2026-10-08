$ErrorActionPreference = 'Stop'
# Offline tests for the automatic security-evidence renewal (#1312). No
# scheduled task, ACL, or elevation is touched: the installer's elevated
# primitives are replaced with recorders and the client with a scriptblock.
$repo = Split-Path -Parent $PSScriptRoot
$renewPath = Join-Path $repo 'bin\renew-windows-runner-qualification.ps1'
$installerPath = Join-Path $repo 'bin\install-windows-runner-renewal.ps1'
$maintenanceInstaller = Get-Content -Raw -LiteralPath (Join-Path $repo 'bin\install-windows-runner-maintenance.ps1')
$renewText = Get-Content -Raw -LiteralPath $renewPath
$installerText = Get-Content -Raw -LiteralPath $installerPath
$script:passed = 0
$script:failed = 0

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Case([string]$Name, [scriptblock]$Body) {
  try { & $Body; $script:passed++; Write-Output "PASS $Name" }
  catch { $script:failed++; Write-Error "FAIL ${Name}: $($_.Exception.Message)" -ErrorAction Continue }
}

$temp = Join-Path ([IO.Path]::GetTempPath()) ('ai-devops-renewal-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp | Out-Null
try {
  . $renewPath -LibraryMode
  . $installerPath -LibraryMode
  $sid = 'S-1-5-21-100-200-300-1001'
  $now = [DateTime]::new(2026, 10, 8, 12, 0, 0, [DateTimeKind]::Utc)
  $clock = { $now }.GetNewClosure()

  function New-Case([string]$Name) {
    $root = Join-Path $temp $Name
    New-Item -ItemType Directory -Path (Join-Path $root 'status') | Out-Null
    return $root
  }
  function Write-Evidence([string]$Path, [datetime]$RecordedUtc) {
    [ordered]@{ schema_version=1; recorded_at_utc=$RecordedUtc.ToString('o'); tpm_present=$true } | ConvertTo-Json | Set-Content -LiteralPath $Path -Encoding utf8
  }

  Case 'Renewal_SuccessRecordsFreshEvidence' {
    $root = New-Case 'success'
    $evidence = Join-Path $root 'evidence.json'
    $runner = { param($t) Write-Evidence $evidence $now.AddMinutes(-1); 0 }.GetNewClosure()
    $r = Invoke-QualificationRenewal -Root (Join-Path $root 'status') -Evidence $evidence -ClientRunner $runner -Clock $clock
    Assert-True ($r.result -eq 'SUCCESS') "result was $($r.result)"
    Assert-True ($r.evidence_fresh_for_ci) 'evidence not reported fresh'
    $last = Get-Content -Raw (Join-Path $root 'status\last-run.json') | ConvertFrom-Json
    Assert-True ($last.result -eq 'SUCCESS') 'last-run.json does not record SUCCESS'
    Assert-True (-not (Test-Path (Join-Path $root 'status\failures.jsonl'))) 'success wrote a failure record'
  }

  Case 'Renewal_TpmAbsentFailureIsRecordedAndEvidenceUntouched' {
    # The worker maps a qualification throw (TPM must be present and ready)
    # to OPERATION_FAILED = 14; the renewal must record it, not hide it.
    $root = New-Case 'tpm'
    $evidence = Join-Path $root 'evidence.json'
    Write-Evidence $evidence $now.AddHours(-20)
    $before = (Get-FileHash $evidence).Hash
    $r = Invoke-QualificationRenewal -Root (Join-Path $root 'status') -Evidence $evidence -ClientRunner { param($t) 14 } -Clock $clock
    Assert-True ($r.result -eq 'OPERATION_FAILED') "result was $($r.result)"
    Assert-True ((Get-FileHash $evidence).Hash -eq $before) 'failed renewal changed evidence'
    $lines = @(Get-Content (Join-Path $root 'status\failures.jsonl'))
    Assert-True ($lines.Count -eq 1) 'failure not appended exactly once'
    $f = $lines[0] | ConvertFrom-Json
    Assert-True ($f.result -eq 'OPERATION_FAILED' -and $f.client_exit_code -eq 14 -and $f.evidence_age_hours -eq 20) 'failure record incomplete'
  }

  Case 'Renewal_SuccessWithoutFreshEvidenceIsFailure' {
    $root = New-Case 'stale'
    $evidence = Join-Path $root 'evidence.json'
    Write-Evidence $evidence $now.AddHours(-30)
    $r = Invoke-QualificationRenewal -Root (Join-Path $root 'status') -Evidence $evidence -ClientRunner { param($t) 0 } -Clock $clock
    Assert-True ($r.result -eq 'EVIDENCE_NOT_REFRESHED') "result was $($r.result)"
    Assert-True (-not $r.evidence_fresh_for_ci) 'stale evidence reported fresh'
    Assert-True (Test-Path (Join-Path $root 'status\failures.jsonl')) 'stale evidence not recorded as failure'
  }

  Case 'Renewal_MissingEvidenceIsFailure' {
    $root = New-Case 'missing'
    $r = Invoke-QualificationRenewal -Root (Join-Path $root 'status') -Evidence (Join-Path $root 'none.json') -ClientRunner { param($t) 0 } -Clock $clock
    Assert-True ($r.result -eq 'EVIDENCE_NOT_REFRESHED' -and $null -eq $r.evidence_recorded_at_utc) "result was $($r.result)"
  }

  Case 'Renewal_UnknownExitOrThrowIsResultInvalid' {
    $root = New-Case 'invalid'
    $evidence = Join-Path $root 'evidence.json'
    $r1 = Invoke-QualificationRenewal -Root (Join-Path $root 'status') -Evidence $evidence -ClientRunner { param($t) 99 } -Clock $clock
    $r2 = Invoke-QualificationRenewal -Root (Join-Path $root 'status') -Evidence $evidence -ClientRunner { param($t) throw 'boom' } -Clock $clock
    Assert-True ($r1.result -eq 'RESULT_INVALID' -and $r2.result -eq 'RESULT_INVALID') 'unknown outcome not RESULT_INVALID'
    Assert-True (@(Get-Content (Join-Path $root 'status\failures.jsonl')).Count -eq 2) 'both failures not recorded'
  }

  Case 'Renewal_EveryClientResultMapsToItsName' {
    $root = New-Case 'map'
    $expected = @{ 10='MISSING_TASK'; 11='STALE_INSTALLATION'; 12='CONCURRENT_EXECUTION'; 13='REQUEST_REJECTED'; 15='RESULT_INVALID'; 16='TIMEOUT' }
    foreach ($code in $expected.Keys) {
      $runner = { param($t) $code }.GetNewClosure()
      $r = Invoke-QualificationRenewal -Root (Join-Path $root 'status') -Evidence (Join-Path $root 'e.json') -ClientRunner $runner -Clock $clock
      Assert-True ($r.result -eq $expected[$code]) "exit $code mapped to $($r.result)"
    }
  }

  Case 'Renewal_FailureLogIsBounded' {
    $root = New-Case 'bounded'
    $status = Join-Path $root 'status'
    $log = Join-Path $status 'failures.jsonl'
    [IO.File]::WriteAllBytes($log, [byte[]]::new($script:MaxFailureLogBytes))
    Invoke-QualificationRenewal -Root $status -Evidence (Join-Path $root 'e.json') -ClientRunner { param($t) 16 } -Clock $clock | Out-Null
    Assert-True (Test-Path (Join-Path $status 'failures.1.jsonl')) 'full log not rotated'
    Assert-True ((Get-Item $log).Length -lt 4096) 'new log not started after rotation'
  }

  Case 'Renewal_RefusesReparseOrMissingStatusRoot' {
    $root = New-Case 'reparse'
    $target = Join-Path $root 'target'; New-Item -ItemType Directory -Path $target | Out-Null
    $link = Join-Path $root 'link'
    New-Item -ItemType Junction -Path $link -Target $target | Out-Null
    $threw = $false
    try { Invoke-QualificationRenewal -Root $link -Evidence (Join-Path $root 'e.json') -ClientRunner { param($t) 0 } -Clock $clock | Out-Null } catch { $threw = $_.Exception.Message -like 'Reparse point refused*' }
    Assert-True $threw 'junction status root accepted'
    $threw = $false
    try { Invoke-QualificationRenewal -Root (Join-Path $root 'absent') -Evidence (Join-Path $root 'e.json') -ClientRunner { param($t) 0 } -Clock $clock | Out-Null } catch { $threw = $true }
    Assert-True $threw 'missing status root accepted'
  }

  Case 'Renewal_UsesOnlyTheFixedClientOperation' {
    Assert-True ($renewText.Contains("-File `$script:ClientPath -Operation refresh-qualification")) 'client not invoked with the fixed operation'
    Assert-True ($renewText.Contains("Join-Path `$PSScriptRoot 'invoke-windows-runner-maintenance.ps1'")) 'client not resolved beside the protected copy'
    foreach ($forbidden in @('-Verb RunAs', 'qualify-windows-runner.ps1', 'Start-Process', 'Invoke-Expression')) {
      Assert-True (-not $renewText.Contains($forbidden)) "renewal script contains $forbidden"
    }
  }

  $good = [ordered]@{
    execute = 'C:\Program Files\PowerShell\7\pwsh.exe'; arguments = (Get-RenewalTaskArguments); action_count = 1
    user_id = $sid; logon_type = 'S4U'; run_level = 'Limited'; trigger_count = 2; startup_trigger = 1
    repetition_interval = 'PT8H'; multiple_instances = 'IgnoreNew'; enabled = $true; sddl = (Get-RenewalTaskSddl -OperatorSid $sid)
  }
  Case 'Task_ExpectedContractPasses' { Assert-RenewalTaskContract -Task $good -ExpectedOperatorSid $sid }
  $drifts = [ordered]@{
    'Task_RefusesHighestRunLevel' = @{ run_level = 'Highest' }
    'Task_RefusesOtherPrincipal' = @{ user_id = 'S-1-5-18' }
    'Task_RefusesInteractiveLogon' = @{ logon_type = 'Interactive' }
    'Task_RefusesExtraAction' = @{ action_count = 2 }
    'Task_RefusesChangedArguments' = @{ arguments = '-NoProfile -Command whoami' }
    'Task_RequiresStartupTrigger' = @{ startup_trigger = 0; trigger_count = 1 }
    'Task_RequiresEightHourRepetition' = @{ repetition_interval = 'P1D' }
    'Task_RefusesOperatorWriteSddl' = @{ sddl = "D:P(A;;FA;;;SY)(A;;FA;;;BA)(A;;FA;;;$sid)" }
    'Task_RefusesParallelInstances' = @{ multiple_instances = 'Parallel' }
    'Task_RefusesDisabledTask' = @{ enabled = $false }
  }
  foreach ($entry in $drifts.GetEnumerator()) {
    $drift = $entry.Value
    Case $entry.Key {
      $task = [ordered]@{}; foreach ($k in $good.Keys) { $task[$k] = $good[$k] }
      foreach ($k in $drift.Keys) { $task[$k] = $drift[$k] }
      $threw = $false
      try { Assert-RenewalTaskContract -Task $task -ExpectedOperatorSid $sid } catch { $threw = $_.Exception.Message -like 'STALE_INSTALLATION*' }
      Assert-True $threw 'drift accepted'
    }.GetNewClosure()
  }

  Case 'Install_RequiresVerifiedMaintenanceBoundaryFirst' {
    $main = $installerText.Substring($installerText.IndexOf('function Invoke-RenewalInstallerMain'))
    $verifyAt = $main.IndexOf('Test-MaintenanceInstallation')
    Assert-True ($verifyAt -gt 0 -and $verifyAt -lt $main.IndexOf('Install-RenewalPayload') -and $main.IndexOf('Assert-Administrator') -lt $verifyAt) 'install does not verify the #262 boundary before changing anything'
    Assert-True ($installerText.Contains('function Test-RenewalInstallation') -and ([regex]::Match($installerText, 'function Test-RenewalInstallation[\s\S]*?\n}').Value.Contains('Test-MaintenanceInstallation'))) 'verify does not re-verify the #262 boundary'
  }

  Case 'Install_PayloadIsHashPinnedAndProtected' {
    $installRoot = Join-Path $temp 'install'; New-Item -ItemType Directory -Path $installRoot | Out-Null
    $script:RenewalPayloadRoot = Join-Path $installRoot 'renewal-payload'
    $script:RenewalStatusRoot = Join-Path $installRoot 'renewal-status'
    $script:aclCalls = @()
    function Set-RenewalAcl { param($LiteralPath, $OperatorSid, $Kind) $script:aclCalls += $Kind }
    function Assert-NoForeignOwnership { param($LiteralPath) }
    Install-RenewalPayload -SourceRoot $repo -OperatorSid $sid
    $manifest = Get-Content -Raw (Join-Path $script:RenewalPayloadRoot 'manifest.json') | ConvertFrom-Json
    foreach ($name in $script:RenewalFiles) {
      $expected = (Get-FileHash -Algorithm SHA256 (Join-Path $repo "bin\$name")).Hash.ToLowerInvariant()
      Assert-True ($manifest.files.$name -ceq $expected) "manifest hash wrong for $name"
      Assert-True ((Get-FileHash -Algorithm SHA256 (Join-Path $script:RenewalPayloadRoot $name)).Hash.ToLowerInvariant() -ceq $expected) "installed copy differs for $name"
    }
    Assert-True ($manifest.operator_sid -ceq $sid -and $manifest.owner -ceq 'popcre/ai-devops#1312') 'manifest identity wrong'
    Assert-True (($script:aclCalls -join ',') -eq 'Payload,Status') "ACL sequence was $($script:aclCalls -join ',')"
    Assert-True (Test-Path $script:RenewalStatusRoot) 'status root not created'
    Install-RenewalPayload -SourceRoot $repo -OperatorSid $sid
    Assert-True (-not (Test-Path "$script:RenewalPayloadRoot.staging")) 'staging left behind on reinstall'
  }

  Case 'Install_RegistersLimitedS4UWithStartupAndRepeat' {
    $register = [regex]::Match($installerText, 'function Register-RenewalTask[\s\S]*?\n}').Value
    foreach ($needle in @('-LogonType S4U -RunLevel Limited', 'New-ScheduledTaskTrigger -AtStartup', '-RepetitionInterval', '-MultipleInstances IgnoreNew', 'SetSecurityDescriptor', 'Assert-NoPerUserComOverride')) {
      Assert-True ($register.Contains($needle)) "registration missing $needle"
    }
    Assert-True (-not $register.Contains('Highest')) 'renewal task requests elevation'
  }

  Case 'Install_TripwireThenDisabledSealThenEnable' {
    $register = [regex]::Match($installerText, 'function Register-RenewalTask[\s\S]*?
}').Value
    $trip = $register.IndexOf('Assert-NoPerUserComOverride'); $reg = $register.IndexOf('Register-ScheduledTask'); $seal = $register.IndexOf('SetSecurityDescriptor'); $enable = $register.IndexOf('.Enabled = $true')
    Assert-True ($trip -ge 0 -and $trip -lt $reg -and $reg -lt $seal -and $seal -lt $enable) 'order is not tripwire, register, seal, enable'
    Assert-True ($register.Contains('New-ScheduledTaskSettingsSet -Disable')) 'task not registered disabled'
    Assert-True ($register -match 'catch \{\s*Unregister-ScheduledTask') 'failed seal does not unregister'
  }

  Case 'Remove_TripwireBeforeAnyTaskAccess' {
    $remove = [regex]::Match($installerText, 'function Remove-RenewalInstallation[\s\S]*?
}').Value
    Assert-True ($remove.IndexOf('Assert-NoPerUserComOverride') -lt $remove.IndexOf('Get-ScheduledTask')) 'remove touches the task before the COM tripwire'
  }

  Case 'Install_StatusParentCheckedAtCreateSite' {
    $install = [regex]::Match($installerText, 'function Install-RenewalPayload[\s\S]*?
}').Value
    Assert-True ($install.IndexOf('Assert-NoForeignOwnership -LiteralPath $statusParent') -lt $install.IndexOf('New-Item -ItemType Directory -Path $script:RenewalStatusRoot')) 'status parent not checked before create'
  }

  Case 'Remove_KeepsFailureHistoryAndIsIdempotent' {
    $remove = [regex]::Match($installerText, 'function Remove-RenewalInstallation[\s\S]*?\n}').Value
    Assert-True ($remove.Contains("return 'ABSENT'") -and $remove.Contains("return 'REMOVED'")) 'remove not idempotent'
    Assert-True (-not $remove.Contains('RenewalStatusRoot')) 'remove deletes the failure history'
  }

  $full = 2032127
  $goodPayload = @(
    [pscustomobject]@{ Sid='S-1-5-32-544'; AccessControlType='Allow'; Rights=$full },
    [pscustomobject]@{ Sid='S-1-5-18'; AccessControlType='Allow'; Rights=$full },
    [pscustomobject]@{ Sid=$sid; AccessControlType='Allow'; Rights=1179817 })
  Case 'Acl_PayloadContractPasses' { Test-RenewalAclRules -OwnerSid 'S-1-5-32-544' -Rules $goodPayload -OperatorSid $sid -Kind Payload }
  Case 'Acl_StatusContractPasses' {
    $rules = @($goodPayload[0], $goodPayload[1], [pscustomobject]@{ Sid=$sid; AccessControlType='Allow'; Rights=1245631 }, [pscustomobject]@{ Sid='S-1-5-32-545'; AccessControlType='Allow'; Rights=1179817 })
    Test-RenewalAclRules -OwnerSid 'S-1-5-32-544' -Rules $rules -OperatorSid $sid -Kind Status
  }
  $aclDrifts = [ordered]@{
    'Acl_RefusesForeignOwner' = @{ owner='S-1-5-21-9-9-9-500'; kind='Payload'; extra=$null }
    'Acl_RefusesUnexpectedIdentity' = @{ owner='S-1-5-32-544'; kind='Payload'; extra=[pscustomobject]@{ Sid='S-1-1-0'; AccessControlType='Allow'; Rights=1179817 } }
    'Acl_RefusesDenyRule' = @{ owner='S-1-5-32-544'; kind='Payload'; extra=[pscustomobject]@{ Sid=$sid; AccessControlType='Deny'; Rights=1 } }
    'Acl_RefusesOperatorTakeOwnershipOnPayload' = @{ owner='S-1-5-32-544'; kind='Payload'; extra=[pscustomobject]@{ Sid=$sid; AccessControlType='Allow'; Rights=0x80000 } }
    'Acl_RefusesOperatorWriteOnPayload' = @{ owner='S-1-5-32-544'; kind='Payload'; extra=[pscustomobject]@{ Sid=$sid; AccessControlType='Allow'; Rights=0x2 } }
    'Acl_RefusesUsersWriteOnStatus' = @{ owner='S-1-5-32-544'; kind='Status'; extra=[pscustomobject]@{ Sid='S-1-5-32-545'; AccessControlType='Allow'; Rights=0x2 } }
    'Acl_RefusesOperatorChangePermissionsOnStatus' = @{ owner='S-1-5-32-544'; kind='Status'; extra=[pscustomobject]@{ Sid=$sid; AccessControlType='Allow'; Rights=0x40000 } }
  }
  foreach ($entry in $aclDrifts.GetEnumerator()) {
    $d = $entry.Value
    Case $entry.Key {
      $rules = @($goodPayload); if ($null -ne $d.extra) { $rules += $d.extra }
      $threw = $false
      try { Test-RenewalAclRules -OwnerSid $d.owner -Rules $rules -OperatorSid $sid -Kind $d.kind } catch { $threw = $_.Exception.Message -like 'STALE_INSTALLATION*' }
      Assert-True $threw 'ACL drift accepted'
    }.GetNewClosure()
  }
  Case 'Acl_VerifyChecksPayloadFilesAndStatus' {
    $verify = [regex]::Match($installerText, 'function Test-RenewalInstallation[\s\S]*?\n}').Value
    Assert-True ($verify.Contains('Get-ChildItem -LiteralPath $script:RenewalPayloadRoot') -and $verify.Contains('-Kind Status')) 'verify skips payload files or status ACL'
  }
  Case 'Installer_PinsModulesAndRefusesHostileEnvBeforeAnyCmdlet' {
    $pin = $installerText.IndexOf('$env:PSModulePath = ')
    $hostile = $installerText.IndexOf('DOTNET_STARTUP_HOOKS')
    $dot = $installerText.IndexOf(". ([IO.Path]::Combine(")
    Assert-True ($pin -gt 0 -and $hostile -gt $pin -and $dot -gt $hostile) 'pin/hostile check not before dot-source'
    $prefix = $installerText.Substring(0, $pin)
    Assert-True ($prefix -notmatch '(?m)^\s*[^#\s].*\b(Join-Path|Get-|Set-|New-|Test-Path)\b') 'a cmdlet runs before the module pin'
    Assert-True ($renewText.IndexOf('$env:PSModulePath = ') -lt $renewText.IndexOf('Join-Path')) 'renewal script resolves a cmdlet before the pin'
  }
  Case 'Remove_SealsTaskBeforeUnregister' {
    $remove = [regex]::Match($installerText, 'function Remove-RenewalInstallation[\s\S]*?\n}').Value
    $seal = $remove.IndexOf("SetSecurityDescriptor('D:P(A;;FA;;;SY)(A;;FA;;;BA)'")
    Assert-True ($seal -gt 0 -and $seal -lt $remove.IndexOf('Unregister-ScheduledTask')) 'task not sealed before unregister'
  }
  Case 'Install_StagingDeleteChecksOwnership' {
    Assert-True ($installerText.Contains('Assert-NoReparsePoint -LiteralPath $staging; Assert-NoForeignOwnership -LiteralPath $staging; Remove-Item')) 'staging deleted without ownership check'
  }
  Case 'Renewal_StatusTempNameIsUnpredictable' { Assert-True ($renewText.Contains("[guid]::NewGuid().ToString('N') + '.tmp'")) 'predictable temp name' }

  Case 'MaintenanceTask_StaysTriggerless' {
    # The elevated #262 task keeps its no-trigger contract; only the
    # unprivileged sibling is scheduled.
    Assert-True ($maintenanceInstaller.Contains('$task.trigger_count -ne 0')) 'maintenance verifier no longer enforces zero triggers'
    Assert-True (-not $installerText.Contains('Register-ScheduledTask -TaskPath $script:TaskFolder -TaskName $script:TaskName')) 'renewal installer re-registers the maintenance task'
  }
} finally {
  Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output "windows runner renewal: $script:passed passed, $script:failed failed"
if ($script:failed -ne 0) { exit 1 }
