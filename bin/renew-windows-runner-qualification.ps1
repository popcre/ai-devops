[CmdletBinding()]
param(
  [string]$StatusRoot = 'C:\ProgramData\ai-devops\windows-runner-renewal',
  [string]$EvidencePath = 'C:\ProgramData\ai-devops\windows-runner-security.json',
  [ValidateRange(1,300)][int]$TimeoutSeconds = 240,
  [switch]$LibraryMode
)

# Scheduled, unprivileged renewal of the Administrator security evidence
# (popcre/ai-devops#1312). This script never elevates anything itself: it
# runs as the operator's own non-elevated (Limited) S4U token and asks the
# existing hardened \AiDevOps\WindowsRunnerMaintenance task (#262) for its
# one fixed `refresh-qualification` operation through the unchanged client.
# Every protection of that boundary - hash-pinned payload, sanitized launch,
# TPM / Secure Boot / runner-service checks - stays where it is, so a host
# whose TPM has disappeared still FAILS and the evidence is left untouched.
#
# Each run writes last-run.json; each non-SUCCESS run is also appended to
# failures.jsonl so a lapse is durable and visible, not silent. The task
# itself exits non-zero on failure, so Task Scheduler's Last Run Result
# shows it too.

$ErrorActionPreference = 'Stop'
$script:ClientPath = Join-Path $PSScriptRoot 'invoke-windows-runner-maintenance.ps1'
$script:PowerShellPath = 'C:\Program Files\PowerShell\7\pwsh.exe'
$script:ResultNames = @{ 0='SUCCESS'; 10='MISSING_TASK'; 11='STALE_INSTALLATION'; 12='CONCURRENT_EXECUTION'; 13='REQUEST_REJECTED'; 14='OPERATION_FAILED'; 15='RESULT_INVALID'; 16='TIMEOUT' }
$script:MaxFailureLogBytes = 1048576
$script:FreshnessHours = 24

function Invoke-MaintenanceClient {
  param([int]$Timeout)
  # The unchanged client runs in its own process so its exit code - the
  # bounded result vocabulary of #262 - is the only thing this script trusts.
  $null = & $script:PowerShellPath -NoProfile -NonInteractive -File $script:ClientPath -Operation refresh-qualification -TimeoutSeconds $Timeout 2>$null
  return [int]$LASTEXITCODE
}

function Read-EvidenceTimestamp {
  param([Parameter(Mandatory)][string]$LiteralPath)
  try {
    $item = Get-Item -LiteralPath $LiteralPath -Force -ErrorAction Stop
    if ($item.Length -gt 8192) { return $null }
    $evidence = Get-Content -Raw -LiteralPath $LiteralPath | ConvertFrom-Json -ErrorAction Stop
    return ([DateTime]::Parse([string]$evidence.recorded_at_utc, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AdjustToUniversal -bor [Globalization.DateTimeStyles]::AssumeUniversal))
  } catch { return $null }
}

function Write-StatusFile {
  param([Parameter(Mandatory)][string]$LiteralPath, [Parameter(Mandatory)][string]$Json)
  $temporary = "$LiteralPath.tmp"
  [IO.File]::WriteAllText($temporary, $Json, [Text.UTF8Encoding]::new($false))
  Move-Item -LiteralPath $temporary -Destination $LiteralPath -Force
}

function Add-FailureRecord {
  param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$Line)
  $log = Join-Path $Root 'failures.jsonl'
  if ((Test-Path -LiteralPath $log) -and (Get-Item -LiteralPath $log).Length -ge $script:MaxFailureLogBytes) {
    Move-Item -LiteralPath $log -Destination (Join-Path $Root 'failures.1.jsonl') -Force
  }
  [IO.File]::AppendAllText($log, $Line + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
}

function Invoke-QualificationRenewal {
  param(
    [Parameter(Mandatory)][string]$Root,
    [Parameter(Mandatory)][string]$Evidence,
    [int]$Timeout = 240,
    [scriptblock]$ClientRunner = { param($t) Invoke-MaintenanceClient -Timeout $t },
    [scriptblock]$Clock = { [DateTime]::UtcNow }
  )
  if (-not (Test-Path -LiteralPath $Root -PathType Container)) { throw "Renewal status directory is missing: $Root" }
  $item = Get-Item -LiteralPath $Root -Force
  if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Reparse point refused: $Root" }
  $started = & $Clock
  $exit = -1
  try { $exit = [int](& $ClientRunner $Timeout) } catch { $exit = 15 }
  $result = if ($script:ResultNames.ContainsKey($exit)) { $script:ResultNames[$exit] } else { 'RESULT_INVALID' }
  $ended = & $Clock
  $recorded = Read-EvidenceTimestamp -LiteralPath $Evidence
  $ageHours = if ($null -ne $recorded) { [Math]::Round(($ended - $recorded).TotalHours, 2) } else { $null }
  # SUCCESS alone is not enough: the evidence the CI gate reads must really
  # be fresh afterwards, or this run is recorded as a failure too.
  if ($result -eq 'SUCCESS' -and ($null -eq $ageHours -or $ageHours -gt 1)) { $result = 'EVIDENCE_NOT_REFRESHED' }
  $record = [ordered]@{
    schema_version = 1
    host = [Environment]::MachineName
    operation = 'refresh-qualification'
    started_at_utc = $started.ToString('o')
    ended_at_utc = $ended.ToString('o')
    result = $result
    client_exit_code = $exit
    evidence_recorded_at_utc = if ($null -ne $recorded) { $recorded.ToString('o') } else { $null }
    evidence_age_hours = $ageHours
    evidence_fresh_for_ci = ($null -ne $ageHours -and $ageHours -lt $script:FreshnessHours)
  }
  $json = $record | ConvertTo-Json -Compress
  Write-StatusFile -LiteralPath (Join-Path $Root 'last-run.json') -Json $json
  if ($result -ne 'SUCCESS') { Add-FailureRecord -Root $Root -Line $json }
  return [pscustomobject]$record
}

if (-not $LibraryMode -and $MyInvocation.InvocationName -ne '.') {
  try {
    $outcome = Invoke-QualificationRenewal -Root $StatusRoot -Evidence $EvidencePath -Timeout $TimeoutSeconds
    $outcome | ConvertTo-Json -Compress
    if ($outcome.result -ne 'SUCCESS') { exit 1 }
    exit 0
  } catch {
    [Console]::Error.WriteLine('RENEWAL_FAILED: ' + $_.Exception.Message)
    exit 2
  }
}
