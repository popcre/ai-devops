# install-memory-health-task.ps1 - register the weekly READ-ONLY memory health report.
#
# The task runs bin/ai-memory-health, which never edits or deletes a memory. It writes
# the report to ~/.config/ai-devops/memory-health-latest.md and, when there is something
# to review, raises a Windows notification pointing at that file.
#
# Deliberate design note: unattended memory *editing* is not offered. ai-sync-memory's
# tombstones make a deletion propagate to every machine and survive a later pull, so a
# wrong automated delete is not recoverable. A human approves every change.
#
# Requires PowerShell 7 (pwsh). Idempotent - re-running replaces the task.

[CmdletBinding()]
param(
  [string]$RepoPath = (Split-Path -Parent $PSScriptRoot),
  [ValidateSet('Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday')]
  [string]$DayOfWeek = 'Monday',
  [string]$At = '09:00',
  [switch]$Remove
)

$ErrorActionPreference = 'Stop'
function Ok($m)   { Write-Host "[ OK ] $m"   -ForegroundColor Green }
function Warn($m) { Write-Host "[WARN] $m"   -ForegroundColor Yellow }
function Die($m)  { Write-Host "[FAIL] $m"   -ForegroundColor Red; exit 1 }

$taskName = 'ai-memory-health'

if ($Remove) {
  if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Ok "Removed scheduled task '$taskName'."
  } else {
    Ok "No scheduled task '$taskName' to remove."
  }
  exit 0
}

$healthScript = Join-Path $RepoPath 'bin/ai-memory-health'
if (-not (Test-Path -LiteralPath $healthScript)) { Die "Not found: $healthScript" }

$gitBash = @(
  'C:\Program Files\Git\bin\bash.exe',
  'C:\Program Files (x86)\Git\bin\bash.exe'
) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $gitBash) { Die 'Git bash not found. Install Git for Windows first.' }

$cfgDir = Join-Path $env:USERPROFILE '.config\ai-devops'
New-Item -ItemType Directory -Force -Path $cfgDir | Out-Null
$reportPath = Join-Path $cfgDir 'memory-health-latest.md'

# Runner: produce the report, then notify only when there is something to review.
$runner = Join-Path $cfgDir 'memory-health-run.ps1'
$runnerBody = @'
$ErrorActionPreference = 'SilentlyContinue'
$bash   = "__BASH__"
$script = "__SCRIPT__"
$report = "__REPORT__"
$repo   = "__REPO__"

# Convert to the msys path form git-bash expects.
function To-Posix([string]$p) {
  $p = $p -replace '\\','/'
  if ($p -match '^([A-Za-z]):/(.*)$') { return "/$($Matches[1].ToLower())/$($Matches[2])" }
  return $p
}

& $bash -lc "'$(To-Posix $script)' --repo-root '$(To-Posix $repo)' --out '$(To-Posix $report)' >/dev/null 2>&1"
$findings = $LASTEXITCODE -eq 1

if ($findings) {
  $count = (Select-String -Path $report -Pattern '^\s+- \d+ finding' | Select-Object -First 1).Line
  if (-not $count) { $count = 'Findings to review.' }
  try {
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    $xml = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent(
      [Windows.UI.Notifications.ToastTemplateType]::ToastText02)
    $texts = $xml.GetElementsByTagName('text')
    $texts.Item(0).AppendChild($xml.CreateTextNode('AI memory health')) | Out-Null
    $texts.Item(1).AppendChild($xml.CreateTextNode("$($count.Trim()) See $report")) | Out-Null
    $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('AI DevOps').Show($toast)
  } catch {
    # Notification is a convenience, never a requirement. The report file is the record.
  }
}
'@
$runnerBody = $runnerBody.
  Replace('__BASH__',   $gitBash).
  Replace('__SCRIPT__', $healthScript).
  Replace('__REPORT__', $reportPath).
  Replace('__REPO__',   $RepoPath)
Set-Content -LiteralPath $runner -Value $runnerBody -Encoding utf8

$pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $pwsh) { $pwsh = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" }

try {
  $action  = New-ScheduledTaskAction -Execute $pwsh `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$runner`""
  $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $DayOfWeek -At $At
  $settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 10) -StartWhenAvailable
  $principal = New-ScheduledTaskPrincipal `
    -UserId ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name) `
    -LogonType Interactive -RunLevel Limited
  Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
    -Settings $settings -Principal $principal `
    -Description 'Weekly read-only AI memory health report. Never edits or deletes a memory.' `
    -Force -ErrorAction Stop | Out-Null
  Ok "Scheduled task '$taskName' - $DayOfWeek at $At."
  Ok "Report file: $reportPath"
  Ok "Run it now with:  Start-ScheduledTask -TaskName $taskName"
} catch {
  Die "Could not register the task: $($_.Exception.Message)"
}
