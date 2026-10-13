# Asserts the daily AiDevOps-Housekeeping Scheduled Task is registered
# correctly from bin/setup-machine.ps1 (plan step 7).
# Mirrors tests/test-memory-sync-scheduled-task.ps1. Pure ASCII.
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$setupPath = Join-Path $root 'bin\setup-machine.ps1'
$setup = Get-Content -Raw -LiteralPath $setupPath
$toolPath = Join-Path $root 'bin\ai-housekeeping'
$tool = Get-Content -Raw -LiteralPath $toolPath

function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
}

Assert ($setup -match 'ai-housekeeping-hidden\.vbs') 'setup must create the hidden housekeeping launcher'
Assert ($setup -match 'wscript\.exe') 'scheduled task must use the windowless script host'
Assert ($setup -match 'shell\.Run[\s\S]*, 0, True') 'launcher must hide the window and wait for completion'
Assert ($setup -match 'WScript\.Quit exitCode') 'launcher must return the exit status to Task Scheduler'
Assert ($setup -match 'ExecutionTimeLimit \(New-TimeSpan -Minutes 15\)') 'task must stop stalled runs after 15 minutes'
Assert ($setup -match 'MultipleInstances IgnoreNew') 'task must prevent overlapping runs'
Assert ($setup -match 'Register-ScheduledTask -TaskName "AiDevOps-Housekeeping"') 'setup must register the AiDevOps-Housekeeping task'
Assert ($setup -match 'New-ScheduledTaskTrigger -Daily') 'trigger must be daily (decision b)'
Assert ($setup -notmatch '-WakeToRun\b') 'task must never wake a sleeping machine'
Assert ($setup -match '--log --quiet') 'task must run the log-and-quiet report form'
# The housekeeping block must use the same escaped backslash as the memory-sync
# block: -replace '\\','/' not -replace '\','/' (invalid regex).
$hkBlock = $setup.Substring($setup.IndexOf('Housekeeping schedule'))
Assert ($hkBlock -match "-replace '\\\\','/'") 'housekeeping posix path must escape the backslash like memory-sync'
Assert ($hkBlock -notmatch "-replace '\\','/'") 'housekeeping must not use an unescaped backslash replace'

Assert ($tool -match 'AI_HOUSEKEEPING_LOG') 'log path must be environment-overridable'
Assert ($tool -match 'retain_log_blocks') 'tool must retain a bounded number of log blocks'
Assert ($tool -match 'AiDevOps-Housekeeping') 'tool must know the scheduled task name'

$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile($setupPath, [ref]$tokens, [ref]$errors) | Out-Null
Assert ($errors.Count -eq 0) "setup-machine.ps1 must parse cleanly: $($errors.Message -join '; ')"

Write-Host 'PASS: AiDevOps-Housekeeping scheduled task is daily, hidden, bounded, and never wakes the machine'
