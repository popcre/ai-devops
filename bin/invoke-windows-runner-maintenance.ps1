[CmdletBinding()]
param(
  [ValidateSet('refresh-qualification')][string]$Operation = 'refresh-qualification',
  [ValidateRange(1,300)][int]$TimeoutSeconds = 180
)

$ErrorActionPreference = 'Stop'
$script:RuntimeRoot = 'C:\ProgramData\ai-devops\windows-runner-maintenance'
$script:TaskPath = '\AiDevOps\WindowsRunnerMaintenance'
$script:SafeFields = @('schema_version', 'request_id', 'operation', 'host', 'started_at_utc', 'ended_at_utc', 'result', 'exit_code', 'message')
$script:ResultExitCodes = @{ SUCCESS=0; MISSING_TASK=10; STALE_INSTALLATION=11; CONCURRENT_EXECUTION=12; REQUEST_REJECTED=13; OPERATION_FAILED=14; RESULT_INVALID=15; TIMEOUT=16 }

function New-MaintenanceRequest {
  param([string]$OperationName = 'refresh-qualification', [datetime]$NowUtc = [DateTime]::UtcNow)
  if ($OperationName -cne 'refresh-qualification') { throw 'REQUEST_REJECTED' }
  $id = [guid]::NewGuid().ToString()
  $request = [ordered]@{ schema_version=1; request_id=$id; operation='refresh-qualification'; requested_at=$NowUtc.ToUniversalTime().ToString('o') }
  $path = Join-Path (Join-Path $script:RuntimeRoot 'requests') "$id.json"
  $bytes = [Text.UTF8Encoding]::new($false).GetBytes(($request | ConvertTo-Json -Compress))
  $stream = [IO.File]::Open($path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
  try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
  return [pscustomobject]@{ Id=$id; Path=$path }
}

function Start-MaintenanceTask {
  try { Start-ScheduledTask -TaskPath '\AiDevOps\' -TaskName 'WindowsRunnerMaintenance' -ErrorAction Stop } catch { throw 'MISSING_TASK' }
}

function Read-BoundedMaintenanceResult {
  param([Parameter(Mandatory)][string]$LiteralPath, [Parameter(Mandatory)][string]$ExpectedRequestId)
  $item = Get-Item -LiteralPath $LiteralPath -Force
  if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $item.Length -gt 8192) { throw 'RESULT_INVALID' }
  try { $result = [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($item.FullName)) | ConvertFrom-Json -ErrorAction Stop } catch { throw 'RESULT_INVALID' }
  $fields = @($result.PSObject.Properties.Name)
  if ($fields.Count -ne $script:SafeFields.Count -or @($fields | Where-Object { $_ -notin $script:SafeFields }).Count -ne 0) { throw 'RESULT_INVALID' }
  if ([string]$result.request_id -cne $ExpectedRequestId -or -not $script:ResultExitCodes.ContainsKey([string]$result.result)) { throw 'RESULT_INVALID' }
  return $result
}

function Wait-MaintenanceResult {
  param([Parameter(Mandatory)][string]$RequestId, [ValidateRange(1,300)][int]$Timeout = 180)
  $resultPath = Join-Path (Join-Path $script:RuntimeRoot 'results') "$RequestId.json"
  $deadline = [DateTime]::UtcNow.AddSeconds([Math]::Min($Timeout, 300))
  while ([DateTime]::UtcNow -lt $deadline) {
    if (Test-Path -LiteralPath $resultPath -PathType Leaf) { return Read-BoundedMaintenanceResult -LiteralPath $resultPath -ExpectedRequestId $RequestId }
    Start-Sleep -Milliseconds 250
  }
  throw 'TIMEOUT'
}

if ($MyInvocation.InvocationName -ne '.') {
  try {
    $request = New-MaintenanceRequest -OperationName $Operation
    Start-MaintenanceTask
    $result = Wait-MaintenanceResult -RequestId $request.Id -Timeout $TimeoutSeconds
    $result | Select-Object $script:SafeFields | ConvertTo-Json
    exit ([int]$script:ResultExitCodes[[string]$result.result])
  } catch {
    $code = [string]$_.Exception.Message
    if (-not $script:ResultExitCodes.ContainsKey($code)) { $code = 'RESULT_INVALID' }
    [Console]::Error.WriteLine($code)
    exit ([int]$script:ResultExitCodes[$code])
  }
}
