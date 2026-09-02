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
        New-Item -ItemType File -Path $stdoutPath, $stderrPath -Force | Out-Null
        $process = Start-Process -FilePath (Get-Command pwsh).Source -ArgumentList @(
            '-NoProfile', '-File', $scriptPath
        ) -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -PassThru

        # The child's output is streamed while it runs. A silent 75-minute
        # redirect that only flushed at exit made a timeout unattributable:
        # the log named the aggregate cutoff but never the suite that was
        # running. Live output plus a recorded progress marker means the
        # fail-closed limit reports what it interrupted.
        $started = Get-Date
        $readers = @{}
        $lastMarker = $null
        $script:AiEdgeDevLastMarker = $null
        $openReader = {
            param($path)
            $stream = [System.IO.FileStream]::new(
                $path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read,
                [System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete)
            [System.IO.StreamReader]::new($stream)
        }
        $readers['out'] = & $openReader $stdoutPath
        $readers['err'] = & $openReader $stderrPath
        $drain = {
            foreach ($key in @('out', 'err')) {
                while ($null -ne ($line = $readers[$key].ReadLine())) {
                    Write-Host $line
                    if ($line -match '^\s*(=====|-----)\s*\S') {
                        $script:AiEdgeDevLastMarker = $line.Trim()
                    }
                }
            }
        }
        try {
            $deadline = $started.Add($bodyLimit)
            $timedOut = $false
            while (-not $process.HasExited) {
                & $drain
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
            & $drain
            $lastMarker = $script:AiEdgeDevLastMarker
            if ($timedOut) {
                $elapsed = [int]((Get-Date) - $started).TotalMinutes
                $where = if ($lastMarker) { "Last progress marker: $lastMarker." }
                         else { 'The command produced no progress marker.' }
                throw ("Serialized EDGE-DEV command exceeded its execution limit " +
                       "after ${elapsed}m of a $([int]$bodyLimit.TotalMinutes)m bound. $where")
            }
            if ($process.ExitCode -ne 0) { throw "Serialized EDGE-DEV command failed with exit code $($process.ExitCode)." }
        }
        finally {
            foreach ($reader in $readers.Values) { $reader.Dispose() }
            $process.Dispose()
            Remove-Item -LiteralPath $scriptPath, $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
        }
    }
    finally {
        if ($acquired) { $mutex.ReleaseMutex() }
        $mutex.Dispose()
    }
}
