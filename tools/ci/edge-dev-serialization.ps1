function Invoke-EdgeDevSerialized {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Body,
        [int]$WaitMinutes = 90,
        [Parameter(Mandatory)]
        [int]$BodyMinutes,
        [string]$MutexName = 'Global\ai-devops-edge-dev-ci',
        [int]$TestWaitSeconds = 0,
        [int]$TestBodySeconds = 0
    )

    if (($TestWaitSeconds -gt 0 -or $TestBodySeconds -gt 0) -and
        $MutexName -eq 'Global\ai-devops-edge-dev-ci') {
        throw 'Second-level limits are reserved for an isolated test mutex.'
    }
    $waitLimit = if ($TestWaitSeconds -gt 0) {
        [TimeSpan]::FromSeconds($TestWaitSeconds)
    } else {
        [TimeSpan]::FromMinutes($WaitMinutes)
    }
    $bodyLimit = if ($TestBodySeconds -gt 0) {
        [TimeSpan]::FromSeconds($TestBodySeconds)
    } else {
        [TimeSpan]::FromMinutes($BodyMinutes)
    }

    $mutex = [System.Threading.Mutex]::new($false, $MutexName)
    $acquired = $false
    try {
        try {
            $acquired = $mutex.WaitOne($waitLimit)
        }
        catch [System.Threading.AbandonedMutexException] {
            $acquired = $true
            Write-Warning 'Recovered the EDGE-DEV CI lock after its prior owner exited.'
        }
        if (-not $acquired) {
            throw "Timed out waiting for the EDGE-DEV CI lock."
        }
        $env:AI_EDGE_DEV_WORKING_DIRECTORY = (Get-Location).Path
        $scriptPath = Join-Path ([System.IO.Path]::GetTempPath()) "ai-edge-dev-ci-$PID-$([guid]::NewGuid().ToString('N')).ps1"
        $stdoutPath = "$scriptPath.stdout"
        $stderrPath = "$scriptPath.stderr"
        @"
`$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath `$env:AI_EDGE_DEV_WORKING_DIRECTORY
& {
$($Body.ToString())
}
if (`$null -ne `$LASTEXITCODE -and `$LASTEXITCODE -ne 0) { exit `$LASTEXITCODE }
"@ | Set-Content -LiteralPath $scriptPath -Encoding utf8
        $process = Start-Process -FilePath (Get-Command pwsh).Source -ArgumentList @(
            '-NoProfile', '-File', $scriptPath
        ) -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -PassThru
        try {
            $deadline = (Get-Date).Add($bodyLimit)
            $timedOut = $false
            while (-not $process.HasExited) {
                if ((Get-Date) -ge $deadline) {
                    $timedOut = $true
                    & taskkill.exe /PID $process.Id /T /F | Out-Null
                    # Never release the host mutex until the owned process tree
                    # has been terminated. The outer workflow timeout remains
                    # the final fail-closed bound if Windows cannot kill it.
                    $process.WaitForExit()
                    break
                }
                Start-Sleep -Seconds 5
            }
            if (Test-Path -LiteralPath $stdoutPath) { Get-Content -LiteralPath $stdoutPath }
            if (Test-Path -LiteralPath $stderrPath) { Get-Content -LiteralPath $stderrPath | Write-Host }
            if ($timedOut) { throw 'Serialized EDGE-DEV command exceeded its execution limit.' }
            if ($process.ExitCode -ne 0) { throw "Serialized EDGE-DEV command failed with exit code $($process.ExitCode)." }
        }
        finally {
            $process.Dispose()
            Remove-Item -LiteralPath $scriptPath, $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
        }
    }
    finally {
        if ($acquired) { $mutex.ReleaseMutex() }
        $mutex.Dispose()
    }
}
