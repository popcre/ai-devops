$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$setupPath = Join-Path $root 'bin\setup-machine.ps1'
$setup = Get-Content -Raw -LiteralPath $setupPath

function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
}

Assert ($setup -match 'ai-memory-sync-hidden\.vbs') 'setup must create the hidden launcher'
Assert ($setup -match 'wscript\.exe') 'scheduled task must use the windowless script host'
Assert ($setup -match 'shell\.Run[\s\S]*, 0, True') 'launcher must hide the window and wait for completion'
Assert ($setup -match 'ExecutionTimeLimit \(New-TimeSpan -Minutes 15\)') 'task must stop stalled runs after 15 minutes'
Assert ($setup -match 'MultipleInstances IgnoreNew') 'task must prevent overlapping sync runs'
Assert ($setup -match 'Register-ScheduledTask -TaskName "ai-memory-sync"') 'setup must register the managed task'
Assert ($setup -notmatch 'schtasks /Create /TN "ai-memory-sync"') 'setup must not restore the visible bash task'

$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile($setupPath, [ref]$tokens, [ref]$errors) | Out-Null
Assert ($errors.Count -eq 0) "setup-machine.ps1 must parse cleanly: $($errors.Message -join '; ')"

Write-Host 'PASS: Windows memory sync scheduled task is hidden and bounded'
