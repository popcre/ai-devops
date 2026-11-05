param(
    [string]$Installer,
    [string]$RepoPath,
    [string]$ClaudeHome,
    [string]$CodexHome,
    [string]$ZCodeHome,
    [string]$MimoHome,
    [switch]$TestLockContract
)
$ErrorActionPreference = 'Stop'

# Test-only serialization around the genuine installer's unchanged mutex.
# Running it in this process lets the installer re-enter that same mutex.
function Invoke-ParityLockedAction {
    param($Mutex, [scriptblock]$Action, [int]$WaitMilliseconds = 600000)
    $held = $false
    try {
        try { $held = $Mutex.WaitOne($WaitMilliseconds) }
        catch [Threading.AbandonedMutexException] { $held = $true }
        if (-not $held) { throw 'Installer parity timed out waiting for the installation lock.' }
        & $Action
    } finally {
        if ($held) { $Mutex.ReleaseMutex() }
    }
}

if ($TestLockContract) {
    # An in-memory fake exercises refusal and release without touching the
    # production mutex or launching an installer.
    $failureFixture = Join-Path ([IO.Path]::GetTempPath()) (([guid]::NewGuid().ToString()) + '.ps1')
    [IO.File]::WriteAllText($failureFixture, 'exit 7')
    try {
    foreach ($mode in @('success', 'timeout', 'failure', 'installer-exit')) {
        $fake = New-Object PSObject -Property @{ Mode = $mode; Releases = 0; Wait = 0 }
        $fake | Add-Member ScriptMethod WaitOne { param($milliseconds) $this.Wait = $milliseconds; return $this.Mode -ne 'timeout' }
        $fake | Add-Member ScriptMethod ReleaseMutex { $this.Releases++ }
        $script:called = $false
        $threw = $false
        try {
            Invoke-ParityLockedAction $fake {
                $script:called = $true
                if ($mode -eq 'failure') { throw 'fixture installer failure' }
                if ($mode -eq 'installer-exit') {
                    & $failureFixture
                    if (-not $?) { throw 'Fixture installer failed' }
                }
            }
        } catch { $threw = $true }
        if ($fake.Wait -ne 600000) { throw 'parity wait is not bounded to 600 seconds' }
        if ($mode -eq 'timeout') {
            if (-not $threw -or $script:called -or $fake.Releases -ne 0) { throw 'timeout admitted installation or released an unowned lock' }
        } elseif (-not $script:called -or $fake.Releases -ne 1 -or ($threw -ne ($mode -in @('failure', 'installer-exit')))) {
            throw 'owned lock release or installer failure propagation was lost'
        }
    }
    } finally { Remove-Item -LiteralPath $failureFixture -Force }
    Write-Output 'PASS: parity lock admission and balanced release'
    exit 0
}

$mutex = [Threading.Mutex]::new($false, 'Global\AiDevOpsToolkitInstall')
try {
    Invoke-ParityLockedAction $mutex {
        & $Installer -RepoPath $RepoPath -ClaudeHome $ClaudeHome -CodexHome $CodexHome `
            -ZCodeHome $ZCodeHome -MimoHome $MimoHome -SkipGitInstall
        if (-not $?) { throw 'Fixture installer failed' }
    }
} finally {
    $mutex.Dispose()
}
