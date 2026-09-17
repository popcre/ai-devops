[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
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
  $actualOwner = & $OwnerSidReader $LiteralPath
  if ($actualOwner -ne $ExpectedOwnerSid) { throw 'WRONG_OWNER' }
  $bytes = Read-BoundedBytes -LiteralPath $LiteralPath -MaximumBytes $MaximumBytes
  try { $request = [Text.Encoding]::UTF8.GetString($bytes) | ConvertFrom-Json -ErrorAction Stop } catch { throw 'MALFORMED_JSON' }
  $fields = @($request.PSObject.Properties.Name)
  if (@($fields | Where-Object { $_ -notin $script:AllowedRequestFields }).Count -ne 0 -or $fields.Count -ne 4) { throw 'UNKNOWN_FIELDS' }
  if ($request.schema_version -ne 1 -or $request.operation -cne 'refresh-qualification') { throw 'INVALID_OPERATION' }
  $requestId = [guid]::Empty
  if (-not [guid]::TryParse([string]$request.request_id, [ref]$requestId) -or $requestId -eq [guid]::Empty) { throw 'INVALID_REQUEST_ID' }
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
  $operatorRules = @($acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]) | Where-Object { $_.IdentityReference.Value -eq [string]$manifest.operator_sid })
  if ($operatorRules.Count -eq 0 -or @($operatorRules | Where-Object { ($_.FileSystemRights -band [Security.AccessControl.FileSystemRights]::Write) -or ($_.FileSystemRights -band [Security.AccessControl.FileSystemRights]::Delete) -or ($_.FileSystemRights -band [Security.AccessControl.FileSystemRights]::ChangePermissions) }).Count -ne 0) { throw 'ACL_DRIFT' }
}

function Test-TaskBoundary {
  param([Parameter(Mandatory)][string]$ExpectedOperatorSid)
  $task = Get-ScheduledTask -TaskPath '\AiDevOps\' -TaskName 'WindowsRunnerMaintenance' -ErrorAction Stop
  $expectedArguments = '-NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File "C:\Program Files\ai-devops\windows-runner-maintenance\windows-runner-maintenance-worker.ps1"'
  if ([string]$task.Actions[0].Execute -cne 'C:\Program Files\PowerShell\7\pwsh.exe' -or [string]$task.Actions[0].Arguments -cne $expectedArguments -or [string]$task.Principal.UserId -cne $ExpectedOperatorSid -or [string]$task.Principal.LogonType -cne 'S4U' -or [string]$task.Principal.RunLevel -cne 'Highest' -or @($task.Triggers).Count -ne 0 -or [string]$task.Settings.MultipleInstances -cne 'IgnoreNew') { throw 'STALE_INSTALLATION' }
  $service = New-Object -ComObject 'Schedule.Service'
  $service.Connect()
  $actualSddl = $service.GetFolder('\AiDevOps\').GetTask('WindowsRunnerMaintenance').GetSecurityDescriptor(0)
  if ($actualSddl -cne "D:P(A;;FA;;;SY)(A;;FA;;;BA)(A;;GRGX;;;$ExpectedOperatorSid)") { throw 'ACL_DRIFT' }
}

function Invoke-RefreshQualification {
  param([Parameter(Mandatory)][string]$ProtectedQualificationScript, [ValidateRange(1,300)][int]$TimeoutSeconds = 270)
  Test-PayloadManifest -Root $script:PayloadRoot
  $arguments = @('-NoProfile','-NonInteractive','-ExecutionPolicy','RemoteSigned','-File',$ProtectedQualificationScript,'-EvidencePath',$script:EvidencePath)
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
  $policy = Get-Content -Raw -LiteralPath (Join-Path $script:PayloadRoot 'windows-runner-maintenance-policy.json') | ConvertFrom-Json
  $requests = Join-Path $script:RuntimeRoot 'requests'
  $results = Join-Path $script:RuntimeRoot 'results'
  $ledgerPath = Join-Path $script:RuntimeRoot 'processed-requests.jsonl'
  $auditPath = Join-Path $script:RuntimeRoot 'audit.jsonl'
  $mutex = Enter-MaintenanceLock
  $firstRequest = $true
  $hardDeadline = [DateTime]::UtcNow.AddSeconds([int]$policy.hard_timeout_seconds)
  $quietDeadline = [DateTime]::UtcNow.AddSeconds(2)
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
        $resultCode = if ($null -eq $mutex -or -not $firstRequest) { 'CONCURRENT_EXECUTION' } else { 'REQUEST_REJECTED' }
        $exitCode = 1
        $message = if ($resultCode -eq 'CONCURRENT_EXECUTION') { 'Another maintenance request is already running.' } else { 'The request was rejected.' }
        $ownerSid = 'UNKNOWN'
        try {
          $ownerSid = ([Security.AccessControl.FileSecurity]::new($file.FullName, [Security.AccessControl.AccessControlSections]::Owner)).GetOwner([Security.Principal.SecurityIdentifier]).Value
          $request = Read-ValidatedRequest -LiteralPath $file.FullName -ExpectedOwnerSid ([string]$policy.operator_sid) -MaximumBytes ([int]$policy.max_request_bytes) -MaximumAgeSeconds ([int]$policy.request_max_age_seconds)
          $id = [string]$request.request_id
          if (Select-String -LiteralPath $ledgerPath -SimpleMatch -Quiet -Pattern $id -ErrorAction SilentlyContinue) { throw 'REUSED_UUID' }
          if ($null -eq $mutex -or -not $firstRequest) { throw 'CONCURRENT_EXECUTION' }
          Test-PayloadManifest -Root $script:PayloadRoot
          Test-TaskBoundary -ExpectedOperatorSid ([string]$policy.operator_sid)
          Invoke-RefreshQualification -ProtectedQualificationScript (Join-Path $script:PayloadRoot 'qualify-windows-runner.ps1')
          $resultCode = 'SUCCESS'; $exitCode = 0; $message = 'Windows runner qualification evidence was refreshed.'
        } catch {
          switch -Regex ($_.Exception.Message) {
            'CONCURRENT_EXECUTION' { $resultCode = 'CONCURRENT_EXECUTION'; $message = 'Another maintenance request is already running.' }
            'STALE_INSTALLATION|HASH_DRIFT|ACL_DRIFT|REPARSE_POINT' { $resultCode = 'STALE_INSTALLATION'; $message = 'The protected maintenance installation failed verification.' }
            '^TIMEOUT$' { $resultCode = 'TIMEOUT'; $message = 'Qualification exceeded its bounded execution time.' }
            'QUALIFICATION_FAILED' { $resultCode = 'OPERATION_FAILED'; $message = 'Qualification did not complete successfully.' }
            default { $resultCode = 'REQUEST_REJECTED'; $message = 'The request was rejected.' }
          }
        }
        $ended = [DateTime]::UtcNow
        $safe = [ordered]@{ schema_version=1; request_id=$id; operation='refresh-qualification'; host=$env:COMPUTERNAME; started_at_utc=$started.ToString('o'); ended_at_utc=$ended.ToString('o'); result=$resultCode; exit_code=$exitCode; message=$message }
        Write-SafeResult -Result $safe -LiteralPath (Join-Path $results "$id.json") -MaximumBytes ([int]$policy.max_result_bytes)
        Write-AuditEvent -Event ([ordered]@{ schema_version=1; request_id=$id; requester_sid=$ownerSid; host=$env:COMPUTERNAME; operation='refresh-qualification'; started_at_utc=$started.ToString('o'); ended_at_utc=$ended.ToString('o'); result=$resultCode }) -LiteralPath $auditPath -MaximumFileBytes ([int]$policy.max_audit_bytes)
        Write-ReplayLedgerEntry -RequestId $id -LiteralPath $ledgerPath -MaximumFileBytes ([int]$policy.max_ledger_bytes)
        Remove-Item -LiteralPath $file.FullName -Force
        $firstRequest = $false
      }
      $quietDeadline = [DateTime]::UtcNow.AddSeconds(2)
    } while ([DateTime]::UtcNow -lt $quietDeadline -and [DateTime]::UtcNow -lt $hardDeadline)
  } finally {
    if ($null -ne $mutex) { $mutex.ReleaseMutex(); $mutex.Dispose() }
  }
}

if ($MyInvocation.InvocationName -ne '.') { Invoke-MaintenanceWorker }
