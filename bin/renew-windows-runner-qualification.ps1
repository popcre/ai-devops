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
# failures.jsonl and reported as a comment on popcre/ai-devops#1312 (the
# existing owner issue) through the pop-ai-watchers GitHub App identity that
# scheduled background work already uses (bin/ai-gh-app-auth key file), so a
# lapse reaches a person instead of sitting in a local file. A repeat of the
# same result is re-posted at most once a day. The task itself exits non-zero
# on failure, so Task Scheduler's Last Run Result shows it too.

$ErrorActionPreference = 'Stop'
# Pin module resolution to system-owned directories before any cmdlet runs.
$env:PSModulePath = "$PSHOME\Modules;C:\Windows\System32\WindowsPowerShell\v1.0\Modules"
$script:ClientPath = Join-Path $PSScriptRoot 'invoke-windows-runner-maintenance.ps1'
$script:PowerShellPath = 'C:\Program Files\PowerShell\7\pwsh.exe'
$script:ResultNames = @{ 0='SUCCESS'; 10='MISSING_TASK'; 11='STALE_INSTALLATION'; 12='CONCURRENT_EXECUTION'; 13='REQUEST_REJECTED'; 14='OPERATION_FAILED'; 15='RESULT_INVALID'; 16='TIMEOUT' }
$script:MaxFailureLogBytes = 1048576
$script:FreshnessHours = 24
$script:AlertRepo = 'popcre/ai-devops'
$script:AlertIssue = 1312
$script:AlertRepeatHours = 24
$script:AppId = 5112061
$script:AppKeyPath = [IO.Path]::Combine($(if ($env:AI_GH_APP_DIR) { $env:AI_GH_APP_DIR } else { [IO.Path]::Combine($env:USERPROFILE, '.ai-devops', 'github-app') }), 'pop-ai-watchers.pem')

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
  $temporary = "$LiteralPath." + [guid]::NewGuid().ToString('N') + '.tmp'
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

function ConvertTo-Base64Url([byte[]]$Bytes) { [Convert]::ToBase64String($Bytes).TrimEnd('=').Replace('+','-').Replace('/','_') }

function Get-AppInstallationToken {
  # Same identity and key file as bin/ai-gh-app-auth, minted in-process so
  # the token never reaches a command line, log, or another script.
  if (-not (Test-Path -LiteralPath $script:AppKeyPath)) { throw 'APP_KEY_MISSING' }
  $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  $enc = [Text.Encoding]::UTF8
  $head = ConvertTo-Base64Url $enc.GetBytes('{"alg":"RS256","typ":"JWT"}')
  $body = ConvertTo-Base64Url $enc.GetBytes("{`"iat`":$($now - 60),`"exp`":$($now + 540),`"iss`":`"$script:AppId`"}")
  $rsa = [Security.Cryptography.RSA]::Create()
  try {
    $rsa.ImportFromPem([IO.File]::ReadAllText($script:AppKeyPath))
    $sig = $rsa.SignData($enc.GetBytes("$head.$body"), [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1)
  } finally { $rsa.Dispose() }
  $h = @{ Authorization = "Bearer $head.$body.$(ConvertTo-Base64Url $sig)"; Accept = 'application/vnd.github+json' }
  $owner = $script:AlertRepo.Split('/')[0]
  $inst = Invoke-RestMethod -TimeoutSec 20 -Headers $h -Uri "https://api.github.com/orgs/$owner/installation"
  return (Invoke-RestMethod -TimeoutSec 20 -Method Post -Headers $h -Uri "https://api.github.com/app/installations/$($inst.id)/access_tokens").token
}

function Send-IssueComment {
  param([Parameter(Mandatory)][string]$Body)
  $h = @{ Authorization = 'Bearer ' + (Get-AppInstallationToken); Accept = 'application/vnd.github+json' }
  $null = Invoke-RestMethod -TimeoutSec 20 -Method Post -Headers $h -ContentType 'application/json' `
    -Uri "https://api.github.com/repos/$script:AlertRepo/issues/$script:AlertIssue/comments" -Body (@{ body = $Body } | ConvertTo-Json -Compress)
}

function Send-FailureAlert {
  # Returns POSTED, SUPPRESSED_REPEAT, or ALERT_FAILED:<reason>. An alert
  # problem never changes the renewal result; it is recorded beside it.
  param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)]$Record, [Parameter(Mandatory)][scriptblock]$Sender, [Parameter(Mandatory)][datetime]$Now)
  $statePath = Join-Path $Root 'alert-state.json'
  try {
    $state = Get-Content -Raw -LiteralPath $statePath -ErrorAction Stop | ConvertFrom-Json
    $last = [DateTime]::Parse([string]$state.posted_at_utc, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AdjustToUniversal -bor [Globalization.DateTimeStyles]::AssumeUniversal)
    if ([string]$state.result -ceq [string]$Record.result -and ($Now - $last).TotalHours -lt $script:AlertRepeatHours) { return 'SUPPRESSED_REPEAT' }
  } catch {}
  $fence = '```'
  $body = "**Windows runner security-evidence renewal failed on $($Record.host): ``$($Record.result)``**`n`n" +
    "The scheduled task ``\AiDevOps\WindowsRunnerQualificationRenewal`` did not refresh the evidence. Evidence still fresh for CI: **$($Record.evidence_fresh_for_ci)** (age $($Record.evidence_age_hours) h). " +
    "Full history: ``C:\ProgramData\ai-devops\windows-runner-renewal\failures.jsonl``. A repeat of the same result is posted at most once a day.`n`n" +
    "${fence}json`n$($Record | ConvertTo-Json -Compress)`n${fence}`n`nPosted by WindowsRunnerQualificationRenewal on $($Record.host)"
  try { $null = & $Sender $body } catch {
    $reason = ($_.Exception.Message -replace '\s+', ' ')
    return 'ALERT_FAILED:' + $reason.Substring(0, [Math]::Min(120, $reason.Length))
  }
  Write-StatusFile -LiteralPath $statePath -Json (@{ result = [string]$Record.result; posted_at_utc = $Now.ToString('o') } | ConvertTo-Json -Compress)
  return 'POSTED'
}

function Invoke-QualificationRenewal {
  param(
    [Parameter(Mandatory)][string]$Root,
    [Parameter(Mandatory)][string]$Evidence,
    [int]$Timeout = 240,
    [scriptblock]$ClientRunner = { param($t) Invoke-MaintenanceClient -Timeout $t },
    [scriptblock]$Clock = { [DateTime]::UtcNow },
    [scriptblock]$AlertSender = { param($b) Send-IssueComment -Body $b }
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
  if ($result -ne 'SUCCESS') {
    Add-FailureRecord -Root $Root -Line ($record | ConvertTo-Json -Compress)
    try { $record.alert = Send-FailureAlert -Root $Root -Record $record -Sender $AlertSender -Now $ended }
    catch { $record.alert = 'ALERT_FAILED:alert bookkeeping error' }
  }
  Write-StatusFile -LiteralPath (Join-Path $Root 'last-run.json') -Json ($record | ConvertTo-Json -Compress)
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
