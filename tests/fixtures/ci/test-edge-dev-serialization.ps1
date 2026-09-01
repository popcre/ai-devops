$ErrorActionPreference = 'Stop'
$helper = (Resolve-Path (Join-Path $PSScriptRoot '../../../tools/ci/edge-dev-serialization.ps1')).Path
$mutexName = "Local\ai-devops-edge-dev-ci-test-$PID"
$log = Join-Path ([System.IO.Path]::GetTempPath()) "edge-dev-ci-test-$PID.log"

function Start-LockJob([int]$SleepSeconds, [int]$BodyLimit = 10, [int]$WaitLimit = 10, [string]$ChildPidFile = '') {
    Start-Job -ScriptBlock {
        param($Helper, $MutexName, $Log, $SleepSeconds, $BodyLimit, $WaitLimit, $ChildPidFile)
        . $Helper
        $env:AI_TEST_EDGE_DEV_LOG = $Log
        $env:AI_TEST_EDGE_DEV_SLEEP = [string]$SleepSeconds
        $env:AI_TEST_EDGE_DEV_CHILD_PID = $ChildPidFile
        Invoke-EdgeDevSerialized -MutexName $MutexName -BodyMinutes 1 `
            -TestWaitSeconds $WaitLimit -TestBodySeconds $BodyLimit -Body {
                Add-Content -LiteralPath $env:AI_TEST_EDGE_DEV_LOG -Value "start $PID $([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())"
                if ($env:AI_TEST_EDGE_DEV_CHILD_PID) {
                    $child = Start-Process -FilePath (Get-Command pwsh).Source `
                        -ArgumentList '-NoProfile', '-Command', 'Start-Sleep -Seconds 30' -PassThru
                    Set-Content -LiteralPath $env:AI_TEST_EDGE_DEV_CHILD_PID -Value $child.Id
                }
                Start-Sleep -Seconds ([int]$env:AI_TEST_EDGE_DEV_SLEEP)
                Add-Content -LiteralPath $env:AI_TEST_EDGE_DEV_LOG -Value "end $PID $([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())"
            }
    } -ArgumentList $helper, $mutexName, $log, $SleepSeconds, $BodyLimit, $WaitLimit, $ChildPidFile
}

try {
    $first = Start-LockJob 2
    Start-Sleep -Milliseconds 250
    $second = Start-LockJob 2
    Wait-Job -Job $first, $second -Timeout 12 | Out-Null
    Receive-Job -Job $first, $second
    if ($first.State -ne 'Completed' -or $second.State -ne 'Completed') {
        throw 'Two serialized processes did not complete.'
    }
    $entries = @(Get-Content -LiteralPath $log)
    if ($entries.Count -ne 4) { throw 'The serialization log is incomplete.' }
    $firstEnd = [long](($entries[1] -split ' ')[2])
    $secondStart = [long](($entries[2] -split ' ')[2])
    if ($secondStart -lt $firstEnd) { throw 'Two EDGE-DEV bodies overlapped.' }

    $held = [System.Threading.Mutex]::new($false, $mutexName)
    [void]$held.WaitOne()
    try {
        $waiter = Start-LockJob 0 10 1
        Wait-Job -Job $waiter -Timeout 4 | Out-Null
        Receive-Job -Job $waiter -ErrorAction SilentlyContinue
        if ($waiter.State -ne 'Failed') { throw 'Lock-wait timeout did not fail.' }
    }
    finally {
        $held.ReleaseMutex()
        $held.Dispose()
    }

    $childPidFile = "$log.child-pid"
    $hung = Start-LockJob 8 1 10 $childPidFile
    Wait-Job -Job $hung -Timeout 10 | Out-Null
    Receive-Job -Job $hung -ErrorAction SilentlyContinue
    if ($hung.State -ne 'Failed') { throw 'Execution timeout did not stop a hung body.' }
    $childPid = [int](Get-Content -LiteralPath $childPidFile)
    if (Get-Process -Id $childPid -ErrorAction SilentlyContinue) {
        throw 'Execution timeout left a descendant process running.'
    }

    $after = Start-LockJob 0
    Wait-Job -Job $after -Timeout 8 | Out-Null
    Receive-Job -Job $after
    if ($after.State -ne 'Completed') { throw 'Mutex was not released after timeout.' }
    Write-Host 'PASS: EDGE-DEV lock serializes processes, kills timed-out process trees, and releases after failure'
}
finally {
    Get-Job | Where-Object Name -like 'Job*' | Remove-Job -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $log -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath "$log.child-pid" -Force -ErrorAction SilentlyContinue
}
