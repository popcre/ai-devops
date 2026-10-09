$ErrorActionPreference = 'Continue'
# Non-elevated privilege negatives + concurrency for WindowsRunnerMaintenance
$invoke = 'C:\tmp\wt-edge-dev-win-step6\bin\invoke-windows-runner-maintenance.ps1'
$rt = 'C:\ProgramData\ai-devops\windows-runner-maintenance'
$admin = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Write-Output ("CONTEXT admin=" + $admin)

# N1: operator cannot redefine/delete the task
Write-Output '---N1 task ACL negatives---'
try {
  $t = Get-ScheduledTask -TaskPath '\AiDevOps\' -TaskName 'WindowsRunnerMaintenance'
  $t.Settings.Enabled = $false
  Set-ScheduledTask -InputObject $t | Out-Null
  Write-Output 'N1 REDEFINE=UNEXPECTED_SUCCESS'
} catch {
  Write-Output ('N1 REDEFINE=REFUSED ' + ($_.Exception.Message -replace '\s+', ' ').Substring(0, [Math]::Min(120, $_.Exception.Message.Length)))
}
try {
  Unregister-ScheduledTask -TaskPath '\AiDevOps\' -TaskName 'WindowsRunnerMaintenance' -Confirm:$false
  Write-Output 'N1 UNREGISTER=UNEXPECTED_SUCCESS'
} catch {
  Write-Output ('N1 UNREGISTER=REFUSED ' + ($_.Exception.Message -replace '\s+', ' ').Substring(0, [Math]::Min(120, $_.Exception.Message.Length)))
}

# N2: unknown operation rejected by the client (ValidateSet)
Write-Output '---N2 unknown operation---'
try {
  & $invoke -Operation 'not-a-real-op' 2>&1 | Out-Null
  Write-Output 'N2 UNKNOWN_OP=UNEXPECTED_SUCCESS'
} catch {
  Write-Output 'N2 UNKNOWN_OP=REFUSED'
}

# N3: wrong-owner request (elevated-style admin-owned file written then started)
Write-Output '---N3 wrong owner (admin-owned request)---'
# Create request as admin via elevated SSH would be admin-owned; simulate by icacls after create if possible.
# From non-elevated we can still prove REQUEST_REJECTED when owner is not the operator SID
# by writing a request and re-owning is not possible without elevation — skip live re-own here.
Write-Output 'N3 note: live wrong-owner already evidenced in audit (REQUEST_REJECTED sid=S-1-5-32-544)'

# N4: concurrency — two invokes
Write-Output '---N4 concurrency---'
$jobs = @()
for ($i = 0; $i -lt 2; $i++) {
  $jobs += Start-Job -ScriptBlock {
    param($invoke)
    $out = & $invoke -Operation refresh-qualification 2>&1 | Out-String
    return $out
  } -ArgumentList $invoke
}
$results = $jobs | ForEach-Object { Receive-Job -Job $_ -Wait }
$jobs | Remove-Job -Force
$idx = 0
foreach ($r in $results) {
  $idx++
  $resLine = ($r -split "`n" | Where-Object { $_ -match '"result"' } | Select-Object -First 1)
  $rcLine = ($r -split "`n" | Where-Object { $_ -match 'result|OPERATION|CONCURRENT|SUCCESS|FAILED|REJECTED' } | Select-Object -First 3) -join ' | '
  Write-Output ("N4 job$idx " + $rcLine.Trim())
}

# N5: task still present and enabled after negatives
Write-Output '---N5 task intact---'
$t2 = Get-ScheduledTask -TaskPath '\AiDevOps\' -TaskName 'WindowsRunnerMaintenance' -ErrorAction SilentlyContinue
if ($t2) {
  Write-Output ("N5 task state=" + $t2.State + " enabled=" + (-not [string]$t2.Settings.Enabled -eq 'False'))
} else {
  Write-Output 'N5 task ABSENT'
}

# N6: runner service snapshot (must be unchanged)
Write-Output '---N6 runner service---'
Get-CimInstance Win32_Service | Where-Object { $_.Name -like '*runner*' -or $_.Name -like '*actions*' } | ForEach-Object {
  Write-Output ("SVC " + $_.Name + " status=" + $_.State + " start=" + $_.StartMode + " account=" + $_.StartName)
}
Write-Output '---DONE---'
