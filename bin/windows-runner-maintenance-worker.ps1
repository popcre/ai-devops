[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
# The S4U task runs inside the operator's own logon session, so every
# operator-writable resolution root must leave the process before any
# cmdlet, module, or COM class is touched. Only system-owned module
# directories may remain on the module path; -NoProfile does not stop
# module autoloading by itself. The value is a literal (no cmdlet call)
# so nothing resolves before the pin takes effect; the launcher has
# already stripped the inherited environment to a fixed allowlist.
$env:PSModulePath = "$PSHOME\Modules;C:\Windows\System32\WindowsPowerShell\v1.0\Modules"
$script:PayloadRoot = 'C:\Program Files\ai-devops\windows-runner-maintenance'
$script:RuntimeRoot = 'C:\ProgramData\ai-devops\windows-runner-maintenance'
$script:EvidencePath = 'C:\ProgramData\ai-devops\windows-runner-security.json'
$script:AllowedRequestFields = @('schema_version', 'request_id', 'operation', 'requested_at')
$script:SafeResultFields = @('schema_version', 'request_id', 'operation', 'host', 'started_at_utc', 'ended_at_utc', 'result', 'exit_code', 'message')
$script:ResultEnums = @('SUCCESS', 'MISSING_TASK', 'STALE_INSTALLATION', 'CONCURRENT_EXECUTION', 'REQUEST_REJECTED', 'OPERATION_FAILED', 'RESULT_INVALID', 'TIMEOUT')

function Read-BoundedBytes {
  param([Parameter(Mandatory)][string]$LiteralPath, [Parameter(Mandatory)][int]$MaximumBytes)
  $item = Get-Item -LiteralPath $LiteralPath -Force
  if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'REPARSE_POINT' }
  if ($item.Length -gt $MaximumBytes) { throw 'OVERSIZE' }
  return [IO.File]::ReadAllBytes($item.FullName)
}

function Read-ValidatedRequest {
  param(
    [Parameter(Mandatory)][string]$LiteralPath,
    [Parameter(Mandatory)][string]$ExpectedOwnerSid,
    [int]$MaximumBytes = 2048,
    [int]$MaximumAgeSeconds = 300,
    [scriptblock]$OwnerSidReader = { param($Path) ([Security.AccessControl.FileSecurity]::new($Path, [Security.AccessControl.AccessControlSections]::Owner)).GetOwner([Security.Principal.SecurityIdentifier]).Value },
    [datetime]$NowUtc = [DateTime]::UtcNow
  )
  $bytes = Read-BoundedBytes -LiteralPath $LiteralPath -MaximumBytes $MaximumBytes
  $actualOwner = & $OwnerSidReader $LiteralPath
  if ($actualOwner -ne $ExpectedOwnerSid) { throw 'WRONG_OWNER' }
  try { $request = [Text.Encoding]::UTF8.GetString($bytes) | ConvertFrom-Json -ErrorAction Stop } catch { throw 'MALFORMED_JSON' }
  $fields = @($request.PSObject.Properties.Name)
  if (@($fields | Where-Object { $_ -notin $script:AllowedRequestFields }).Count -ne 0 -or $fields.Count -ne 4) { throw 'UNKNOWN_FIELDS' }
  if ($request.schema_version -ne 1 -or $request.operation -cne 'refresh-qualification') { throw 'INVALID_OPERATION' }
  $requestId = [guid]::Empty
  if (-not [guid]::TryParse([string]$request.request_id, [ref]$requestId) -or $requestId -eq [guid]::Empty) { throw 'INVALID_REQUEST_ID' }
  # Canonicalize: TryParse accepts N/B/P/X GUID spellings, so the raw string
  # is replaced by the one canonical D-format spelling before it reaches the
  # replay ledger, the result file, or the audit trail.
  $request.request_id = $requestId.ToString('D')
  $requestedAt = [datetime]::MinValue
  if ($request.requested_at -is [datetime]) {
    $requestedAt = [datetime]$request.requested_at
  } elseif (-not [datetime]::TryParseExact([string]$request.requested_at, 'o', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind, [ref]$requestedAt)) {
    throw 'INVALID_TIMESTAMP'
  }
  $age = ($NowUtc.ToUniversalTime() - $requestedAt.ToUniversalTime()).TotalSeconds
  if ($age -lt -30 -or $age -gt $MaximumAgeSeconds) { throw 'STALE_TIMESTAMP' }
  return $request
}

function Enter-MaintenanceLock {
  param([string]$Name = 'Global\AiDevOpsWindowsRunnerMaintenance')
  $mutex = [Threading.Mutex]::new($false, $Name)
  if (-not $mutex.WaitOne(0)) { $mutex.Dispose(); return $null }
  return $mutex
}

function Test-PayloadManifest {
  param([Parameter(Mandatory)][string]$Root)
  $manifestPath = Join-Path $Root 'manifest.json'
  if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw 'STALE_INSTALLATION' }
  $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
  if ($manifest.owner -cne 'popcre/ai-devops#262' -or $manifest.task_path -cne '\AiDevOps\WindowsRunnerMaintenance') { throw 'STALE_INSTALLATION' }
  foreach ($entry in $manifest.files.PSObject.Properties) {
    $path = Join-Path $Root $entry.Name
    $item = Get-Item -LiteralPath $path -Force
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'REPARSE_POINT' }
    if ((Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant() -cne [string]$entry.Value) { throw 'HASH_DRIFT' }
  }
  $acl = Get-Acl -LiteralPath $Root
  $ownerSid = ([Security.Principal.NTAccount]$acl.Owner).Translate([Security.Principal.SecurityIdentifier]).Value
  if ($ownerSid -notin @('S-1-5-32-544','S-1-5-18')) { throw 'ACL_DRIFT' }
  $rules = @($acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]))
  # Group-granted rights count as drift: the allowlist admits only
  # Administrators, SYSTEM and the manifest operator, and only Allow rules,
  # so write access arriving through Users/INTERACTIVE never passes.
  $unexpected = @($rules | Where-Object { $_.AccessControlType -ne 'Allow' -or $_.IdentityReference.Value -notin @('S-1-5-32-544','S-1-5-18',[string]$manifest.operator_sid) })
  if ($unexpected.Count -ne 0) { throw 'ACL_DRIFT' }
  foreach ($required in @('S-1-5-32-544','S-1-5-18')) {
    if (-not ($rules | Where-Object { $_.IdentityReference.Value -eq $required -and ($_.FileSystemRights -band [Security.AccessControl.FileSystemRights]::FullControl) })) { throw 'ACL_DRIFT' }
  }
  $operatorRules = @($rules | Where-Object { $_.IdentityReference.Value -eq [string]$manifest.operator_sid })
  if ($operatorRules.Count -eq 0 -or @($operatorRules | Where-Object { ($_.FileSystemRights -band [Security.AccessControl.FileSystemRights]::Write) -or ($_.FileSystemRights -band [Security.AccessControl.FileSystemRights]::Delete) -or ($_.FileSystemRights -band [Security.AccessControl.FileSystemRights]::ChangePermissions) }).Count -ne 0) { throw 'ACL_DRIFT' }
}

function Test-RuntimeBoundary {
  # The runtime contract is verified with the same group-blind allowlist as
  # the payload: the worker refuses to run when any runtime path carries an
  # unexpected identity, a non-Allow rule, foreign ownership, a reparse
  # point, or operator rights beyond the documented shape.
  param([Parameter(Mandatory)][string]$ExpectedOperatorSid)
  $parts = @(
    @{ Path = $script:RuntimeRoot; Kind = 'root' },
    @{ Path = (Join-Path $script:RuntimeRoot 'requests'); Kind = 'requests' },
    @{ Path = (Join-Path $script:RuntimeRoot 'results'); Kind = 'results' },
    @{ Path = (Join-Path $script:RuntimeRoot 'audit.jsonl'); Kind = 'audit' },
    @{ Path = (Join-Path $script:RuntimeRoot 'processed-requests.jsonl'); Kind = 'ledger' }
  )
  foreach ($part in $parts) {
    $item = Get-Item -LiteralPath $part.Path -Force
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'REPARSE_POINT' }
    $acl = Get-Acl -LiteralPath $part.Path
    $ownerSid = ([Security.Principal.NTAccount]$acl.Owner).Translate([Security.Principal.SecurityIdentifier]).Value
    if ($ownerSid -notin @('S-1-5-32-544','S-1-5-18')) { throw 'ACL_DRIFT' }
    $rules = @($acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]))
    $unexpected = @($rules | Where-Object { $_.AccessControlType -ne 'Allow' -or $_.IdentityReference.Value -notin @('S-1-5-32-544','S-1-5-18',$ExpectedOperatorSid) })
    if ($unexpected.Count -ne 0) { throw 'ACL_DRIFT' }
    foreach ($required in @('S-1-5-32-544','S-1-5-18')) {
      if (-not ($rules | Where-Object { $_.IdentityReference.Value -eq $required -and ($_.FileSystemRights -band [Security.AccessControl.FileSystemRights]::FullControl) })) { throw 'ACL_DRIFT' }
    }
    $operatorRules = @($rules | Where-Object { $_.IdentityReference.Value -eq $ExpectedOperatorSid })
    if ($part.Kind -eq 'ledger') { if ($operatorRules.Count -ne 0) { throw 'ACL_DRIFT' }; continue }
    if ($operatorRules.Count -eq 0) { throw 'ACL_DRIFT' }
    $operatorRights = $operatorRules | ForEach-Object FileSystemRights
    $mayWrite = @($operatorRights | Where-Object { ($_ -band [Security.AccessControl.FileSystemRights]::Write) -or ($_ -band [Security.AccessControl.FileSystemRights]::Delete) -or ($_ -band [Security.AccessControl.FileSystemRights]::ChangePermissions) }).Count -ne 0
    if ($part.Kind -eq 'requests') { if (-not $mayWrite) { throw 'ACL_DRIFT' } }
    elseif ($mayWrite) { throw 'ACL_DRIFT' }
  }
}

function Assert-NoPerUserComOverride {
  # HKCU Classes registrations resolve BEFORE HKLM, so operator-writable
  # overrides would load operator code into this elevated process. Both
  # resolution channels are refused: the ProgID key that New-Object
  # resolves first, and the CLSID key it resolves through (whose subtree
  # also carries any per-user TreatAs redirect). A legitimate installation
  # has neither.
  $scheduleServiceClsid = '{148BD52A-A2AB-11CE-B07F-00AA006C7A83}'
  if (Test-Path -LiteralPath 'HKCU:\Software\Classes\Schedule.Service') { throw 'PER_USER_COM_OVERRIDE' }
  if (Test-Path -LiteralPath 'HKCU:\Software\Classes\Schedule.Service.1') { throw 'PER_USER_COM_OVERRIDE' }
  if (Test-Path -LiteralPath "HKCU:\Software\Classes\CLSID\$scheduleServiceClsid") { throw 'PER_USER_COM_OVERRIDE' }
}

function Test-EvidenceBoundary {
  # The qualification evidence is the TPM/Secure Boot gate consumed by CI,
  # so the worker refuses to refresh it through any path it does not own
  # outright: a plain file, owned by Administrators/SYSTEM, whose DACL is
  # exactly the pinned contract. The operator holds NO grant on this file:
  # the elevated worker and qualification child write through their
  # Administrators membership, so any operator ACE is treated as drift.
  param([Parameter(Mandatory)][string]$ExpectedOperatorSid)
  if (-not (Test-Path -LiteralPath $script:EvidencePath -PathType Leaf)) { throw 'ACL_DRIFT' }
  $item = Get-Item -LiteralPath $script:EvidencePath -Force
  if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'REPARSE_POINT' }
  $acl = Get-Acl -LiteralPath $script:EvidencePath
  $owner = $acl.GetOwner([Security.Principal.SecurityIdentifier]).Value
  if ($owner -notin @('S-1-5-32-544','S-1-5-18')) { throw 'ACL_DRIFT' }
  $rules = @($acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]))
  $unexpected = @($rules | Where-Object { $_.AccessControlType -ne 'Allow' -or $_.IdentityReference.Value -notin @('S-1-5-32-544','S-1-5-18','S-1-1-0') })
  if ($unexpected.Count -ne 0) { throw 'ACL_DRIFT' }
  foreach ($required in @('S-1-5-32-544','S-1-5-18')) {
    if (-not ($rules | Where-Object { $_.IdentityReference.Value -eq $required -and ($_.FileSystemRights -band [Security.AccessControl.FileSystemRights]::FullControl) })) { throw 'ACL_DRIFT' }
  }
  $worldRules = @($rules | Where-Object { $_.IdentityReference.Value -eq 'S-1-1-0' })
  if ($worldRules.Count -eq 0 -or @($worldRules | Where-Object { ($_.FileSystemRights -band [Security.AccessControl.FileSystemRights]::Write) -or ($_.FileSystemRights -band [Security.AccessControl.FileSystemRights]::Delete) }).Count -ne 0) { throw 'ACL_DRIFT' }
  if (@($rules | Where-Object { $_.IdentityReference.Value -eq $ExpectedOperatorSid }).Count -ne 0) { throw 'ACL_DRIFT' }
}

function Set-EvidenceContractAcl {
  # Pure .NET descriptor application: the worker never resolves a helper
  # executable through a caller-influenced PATH. No operator grant exists;
  # the elevated writer works through its Administrators membership.
  param([Parameter(Mandatory)][string]$LiteralPath)
  $acl = Get-Acl -LiteralPath $LiteralPath
  $acl.SetAccessRuleProtection($true, $false)
  foreach ($grant in @(
    @{ Identity = [Security.Principal.SecurityIdentifier]::new('S-1-5-32-544'); Rights = [Security.AccessControl.FileSystemRights]::FullControl },
    @{ Identity = [Security.Principal.SecurityIdentifier]::new('S-1-5-18'); Rights = [Security.AccessControl.FileSystemRights]::FullControl },
    @{ Identity = [Security.Principal.SecurityIdentifier]::new('S-1-1-0'); Rights = [Security.AccessControl.FileSystemRights]::ReadAndExecute }
  )) {
    $acl.ResetAccessRule([Security.AccessControl.FileSystemAccessRule]::new($grant.Identity, $grant.Rights, [Security.AccessControl.AccessControlType]::Allow))
  }
  Set-Acl -LiteralPath $LiteralPath -AclObject $acl
}

function Test-IntegrityCapacity {
  param([Parameter(Mandatory)][string]$AuditPath, [Parameter(Mandatory)][string]$LedgerPath, [Parameter(Mandatory)][int]$MaxAuditBytes, [Parameter(Mandatory)][int]$MaxLedgerBytes)
  # Refuse BEFORE the operation runs: once the audit or replay ledger is
  # full, executing further unrecorded operations is fail-open. One line of
  # headroom (bounded by the audit line cap) is reserved for this decision.
  if ((Test-Path -LiteralPath $AuditPath) -and (Get-Item -LiteralPath $AuditPath).Length -ge ($MaxAuditBytes - 8192)) { throw 'AUDIT_FULL' }
  if ((Test-Path -LiteralPath $LedgerPath) -and (Get-Item -LiteralPath $LedgerPath).Length -ge ($MaxLedgerBytes - 8192)) { throw 'LEDGER_FULL' }
}

function Test-TaskBoundary {
  param([Parameter(Mandatory)][string]$ExpectedOperatorSid)
  $task = Get-ScheduledTask -TaskPath '\AiDevOps\' -TaskName 'WindowsRunnerMaintenance' -ErrorAction Stop
  $expectedExecute = 'C:\Windows\System32\cmd.exe'
  $expectedArguments = '/d /c "C:\Program Files\ai-devops\windows-runner-maintenance\launch-worker.cmd"'
  if (@($task.Actions).Count -ne 1 -or [string]$task.Actions[0].Execute -cne $expectedExecute -or [string]$task.Actions[0].Arguments -cne $expectedArguments -or [string]$task.Principal.UserId -cne $ExpectedOperatorSid -or [string]$task.Principal.LogonType -cne 'S4U' -or [string]$task.Principal.RunLevel -cne 'Highest' -or @($task.Triggers).Count -ne 0 -or [string]$task.Settings.MultipleInstances -cne 'IgnoreNew') { throw 'STALE_INSTALLATION' }
  Assert-NoPerUserComOverride
  $service = New-Object -ComObject 'Schedule.Service'
  $service.Connect()
  $actualSddl = $service.GetFolder('\AiDevOps\').GetTask('WindowsRunnerMaintenance').GetSecurityDescriptor(0)
  if ($actualSddl -cne "D:P(A;;FA;;;SY)(A;;FA;;;BA)(A;;GRGX;;;$ExpectedOperatorSid)") { throw 'ACL_DRIFT' }
}

function Invoke-RefreshQualification {
  param([Parameter(Mandatory)][string]$ProtectedQualificationScript, [ValidateRange(1,300)][int]$TimeoutSeconds = 270)
  Test-PayloadManifest -Root $script:PayloadRoot
  # One pre-quoted argument string: Start-Process joins ArgumentList arrays
  # without quoting on Windows, so space-bearing payload paths must never
  # travel as separate elements.
  $arguments = '-NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File "{0}" -EvidencePath "{1}"' -f $ProtectedQualificationScript, $script:EvidencePath
  $process = Start-Process -FilePath 'C:\Program Files\PowerShell\7\pwsh.exe' -ArgumentList $arguments -WindowStyle Hidden -PassThru
  try { Wait-Process -Id $process.Id -Timeout $TimeoutSeconds -ErrorAction Stop } catch { Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue; throw 'TIMEOUT' }
  $process.Refresh()
  if ($process.ExitCode -ne 0) { throw 'QUALIFICATION_FAILED' }
}

function Write-SafeResult {
  param([Parameter(Mandatory)]$Result, [Parameter(Mandatory)][string]$LiteralPath, [int]$MaximumBytes = 8192)
  $unexpected = @($Result.Keys | Where-Object { $_ -notin $script:SafeResultFields })
  if ($unexpected.Count -ne 0) { throw 'UNSAFE_RESULT_FIELD' }
  if ($Result.result -notin $script:ResultEnums) { throw 'INVALID_RESULT_ENUM' }
  $json = $Result | ConvertTo-Json -Compress
  $bytes = [Text.UTF8Encoding]::new($false).GetBytes($json)
  if ($bytes.Length -gt $MaximumBytes) { throw 'RESULT_OVERSIZE' }
  $temporary = "$LiteralPath.tmp.$([guid]::NewGuid().ToString('N'))"
  [IO.File]::WriteAllBytes($temporary, $bytes)
  Move-Item -LiteralPath $temporary -Destination $LiteralPath -Force
}

function Write-AuditEvent {
  param([Parameter(Mandatory)]$Event, [Parameter(Mandatory)][string]$LiteralPath, [int]$MaximumFileBytes = 8388608)
  $allowed = @('schema_version', 'request_id', 'requester_sid', 'host', 'operation', 'started_at_utc', 'ended_at_utc', 'result')
  if (@($Event.Keys | Where-Object { $_ -notin $allowed }).Count -ne 0) { throw 'UNSAFE_AUDIT_FIELD' }
  $line = ($Event | ConvertTo-Json -Compress) + [Environment]::NewLine
  $lineBytes = [Text.UTF8Encoding]::new($false).GetByteCount($line)
  $currentBytes = if (Test-Path -LiteralPath $LiteralPath) { (Get-Item -LiteralPath $LiteralPath).Length } else { 0 }
  if ($lineBytes -gt 8192 -or ($currentBytes + $lineBytes) -gt $MaximumFileBytes) { throw 'AUDIT_FULL' }
  [IO.File]::AppendAllText($LiteralPath, $line, [Text.UTF8Encoding]::new($false))
}

function Write-ReplayLedgerEntry {
  param([Parameter(Mandatory)][string]$RequestId, [Parameter(Mandatory)][string]$LiteralPath, [int]$MaximumFileBytes = 1048576)
  $line = (([ordered]@{ request_id=$RequestId } | ConvertTo-Json -Compress) + [Environment]::NewLine)
  $lineBytes = [Text.UTF8Encoding]::new($false).GetByteCount($line)
  $currentBytes = if (Test-Path -LiteralPath $LiteralPath) { (Get-Item -LiteralPath $LiteralPath).Length } else { 0 }
  if (($currentBytes + $lineBytes) -gt $MaximumFileBytes) { throw 'LEDGER_FULL' }
  [IO.File]::AppendAllText($LiteralPath, $line, [Text.UTF8Encoding]::new($false))
}

function Invoke-MaintenanceWorker {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  if (-not [Security.Principal.WindowsPrincipal]::new($identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Administrator elevation is required.' }
  # Verify the payload first: the manifest pins every payload hash including
  # the policy file, so a drifted policy can never decide who is authorized
  # or what the limits are. Only then is the policy loaded and trusted.
  Test-PayloadManifest -Root $script:PayloadRoot
  $policy = Get-Content -Raw -LiteralPath (Join-Path $script:PayloadRoot 'windows-runner-maintenance-policy.json') | ConvertFrom-Json
  $requests = Join-Path $script:RuntimeRoot 'requests'
  $results = Join-Path $script:RuntimeRoot 'results'
  $ledgerPath = Join-Path $script:RuntimeRoot 'processed-requests.jsonl'
  $auditPath = Join-Path $script:RuntimeRoot 'audit.jsonl'
  $mutex = Enter-MaintenanceLock
  $firstRequest = $true
  $hardDeadline = [DateTime]::UtcNow.AddSeconds([int]$policy.hard_timeout_seconds)
  $quietDeadline = [DateTime]::UtcNow.AddSeconds(2)
  # Verify the runtime boundary BEFORE any enumeration: Modify rights on
  # the (empty) requests directory let the operator plant a junction there
  # in place, and enumerating through it would turn the per-file cleanup
  # delete into arbitrary elevated deletion.
  Test-RuntimeBoundary -ExpectedOperatorSid ([string]$policy.operator_sid)
  try {
    do {
      $requestFiles = @(Get-ChildItem -LiteralPath $requests -Filter '*.json' -File | Sort-Object Name)
      if ($requestFiles.Count -eq 0) {
        Start-Sleep -Milliseconds 250
        continue
      }
      foreach ($file in $requestFiles) {
        $started = [DateTime]::UtcNow
        $id = [IO.Path]::GetFileNameWithoutExtension($file.Name)
        if ($id -notmatch '^[A-Za-z0-9-]{1,80}$') { $id = 'REJECTED' }
        $resultCode = if ($null -eq $mutex -or -not $firstRequest) { 'CONCURRENT_EXECUTION' } else { 'REQUEST_REJECTED' }
        $exitCode = 1
        $message = if ($resultCode -eq 'CONCURRENT_EXECUTION') { 'Another maintenance request is already running.' } else { 'The request was rejected.' }
        $ownerSid = 'UNKNOWN'
        try {
          $ownerSid = ([Security.AccessControl.FileSecurity]::new($file.FullName, [Security.AccessControl.AccessControlSections]::Owner)).GetOwner([Security.Principal.SecurityIdentifier]).Value
          $request = Read-ValidatedRequest -LiteralPath $file.FullName -ExpectedOwnerSid ([string]$policy.operator_sid) -MaximumBytes ([int]$policy.max_request_bytes) -MaximumAgeSeconds ([int]$policy.request_max_age_seconds)
          $id = [string]$request.request_id
          $reused = $false
          if (Test-Path -LiteralPath $ledgerPath -PathType Leaf) {
            try { $reused = [bool](Select-String -LiteralPath $ledgerPath -SimpleMatch -Quiet -Pattern ('"request_id":"' + $id + '"') -ErrorAction Stop) } catch { throw 'LEDGER_UNREADABLE' }
          }
          if ($reused) { throw 'REUSED_UUID' }
          if ($null -eq $mutex -or -not $firstRequest) { throw 'CONCURRENT_EXECUTION' }
          Test-PayloadManifest -Root $script:PayloadRoot
          Test-RuntimeBoundary -ExpectedOperatorSid ([string]$policy.operator_sid)
          Test-TaskBoundary -ExpectedOperatorSid ([string]$policy.operator_sid)
          Test-EvidenceBoundary -ExpectedOperatorSid ([string]$policy.operator_sid)
          Test-IntegrityCapacity -AuditPath $auditPath -LedgerPath $ledgerPath -MaxAuditBytes ([int]$policy.max_audit_bytes) -MaxLedgerBytes ([int]$policy.max_ledger_bytes)
          Invoke-RefreshQualification -ProtectedQualificationScript (Join-Path $script:PayloadRoot 'qualify-windows-runner.ps1')
          # The atomic refresh consumed the pinned tmp sibling and moved its
          # descriptor onto the evidence file. Re-apply the contract to both
          # so no refresh can leave a foreign-owned or inherit-only gate and
          # no later pre-creation race can start from a missing sibling.
          $tmpSibling = "$script:EvidencePath.tmp"
          if (-not (Test-Path -LiteralPath $tmpSibling -PathType Leaf)) { [IO.File]::WriteAllBytes($tmpSibling, [byte[]]@()) }
          Set-EvidenceContractAcl -LiteralPath $tmpSibling
          Set-EvidenceContractAcl -LiteralPath $script:EvidencePath
          $resultCode = 'SUCCESS'; $exitCode = 0; $message = 'Windows runner qualification evidence was refreshed.'
        } catch {
          switch -Regex ($_.Exception.Message) {
            'CONCURRENT_EXECUTION' { $resultCode = 'CONCURRENT_EXECUTION'; $message = 'Another maintenance request is already running.' }
            'STALE_INSTALLATION|HASH_DRIFT|ACL_DRIFT|REPARSE_POINT|PER_USER_COM_OVERRIDE|LEDGER_UNREADABLE' { $resultCode = 'STALE_INSTALLATION'; $message = 'The protected maintenance installation failed verification.' }
            '^TIMEOUT$' { $resultCode = 'TIMEOUT'; $message = 'Qualification exceeded its bounded execution time.' }
            'QUALIFICATION_FAILED' { $resultCode = 'OPERATION_FAILED'; $message = 'Qualification did not complete successfully.' }
            'AUDIT_FULL|LEDGER_FULL' { $resultCode = 'REQUEST_REJECTED'; $message = 'Audit or replay capacity is exhausted; an administrator must archive the logs.' }
            default { $resultCode = 'REQUEST_REJECTED'; $message = 'The request was rejected.' }
          }
        }
        $ended = [DateTime]::UtcNow
        $safe = [ordered]@{ schema_version=1; request_id=$id; operation='refresh-qualification'; host=[Environment]::MachineName; started_at_utc=$started.ToString('o'); ended_at_utc=$ended.ToString('o'); result=$resultCode; exit_code=$exitCode; message=$message }
        try {
          Write-SafeResult -Result $safe -LiteralPath (Join-Path $results "$id.json") -MaximumBytes ([int]$policy.max_result_bytes)
          Write-AuditEvent -Event ([ordered]@{ schema_version=1; request_id=$id; requester_sid=$ownerSid; host=[Environment]::MachineName; operation='refresh-qualification'; started_at_utc=$started.ToString('o'); ended_at_utc=$ended.ToString('o'); result=$resultCode }) -LiteralPath $auditPath -MaximumFileBytes ([int]$policy.max_audit_bytes)
          # Only canonical GUID spellings may enter the replay ledger: a
          # rejected filename stem (or any non-GUID id) would substring-match
          # future request ids through the exact-value lookup and poison the
          # ledger into a permanent lockout the operator cannot undo.
          if ($id -cmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') {
            Write-ReplayLedgerEntry -RequestId $id -LiteralPath $ledgerPath -MaximumFileBytes ([int]$policy.max_ledger_bytes)
          }
        } catch {
          # The bounded decision already happened; an integrity-write failure
          # must neither lose the result nor leave the request behind to be
          # re-executed on every later task start. Record through whichever
          # channels still work, then always drop the request file.
          $safe.result = 'OPERATION_FAILED'; $safe.exit_code = 1
          $safe.message = 'The request was processed but its integrity record could not be written; administrator attention is required.'
          try { Write-SafeResult -Result $safe -LiteralPath (Join-Path $results "$id.json") -MaximumBytes ([int]$policy.max_result_bytes) } catch { }
          try { Write-AuditEvent -Event ([ordered]@{ schema_version=1; request_id=$id; requester_sid=$ownerSid; host=[Environment]::MachineName; operation='refresh-qualification'; started_at_utc=$started.ToString('o'); ended_at_utc=$ended.ToString('o'); result='OPERATION_FAILED' }) -LiteralPath $auditPath -MaximumFileBytes ([int]$policy.max_audit_bytes) } catch { }
        } finally {
          # Re-verify the parent immediately before the elevated delete: the
          # operator can replace the requests directory with a junction in
          # place at any time, and this cleanup must never delete through it.
          $requestsNow = Get-Item -LiteralPath $requests -Force
          if (($requestsNow.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or -not $file.FullName.StartsWith($requestsNow.FullName, [StringComparison]::OrdinalIgnoreCase)) { throw 'REPARSE_POINT' }
          Remove-Item -LiteralPath $file.FullName -Force
        }
        $firstRequest = $false
      }
      $quietDeadline = [DateTime]::UtcNow.AddSeconds(2)
    } while ([DateTime]::UtcNow -lt $quietDeadline -and [DateTime]::UtcNow -lt $hardDeadline)
  } finally {
    if ($null -ne $mutex) { $mutex.ReleaseMutex(); $mutex.Dispose() }
  }
}

if ($MyInvocation.InvocationName -ne '.') { Invoke-MaintenanceWorker }
