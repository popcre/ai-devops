$ErrorActionPreference='Stop'
if ($env:COMPUTERNAME -ne 'EDGE-RUNN-ENVY') { throw 'wrong host' }
$repo='C:\repos\ai-devops'
$pwsh7='C:\Program Files\PowerShell\7\pwsh.exe'
$inst=Join-Path $repo 'bin\install-windows-runner-maintenance.ps1'
$evFile='C:\ProgramData\ai-devops\windows-runner-security.json'
$evBefore=(Get-Item -LiteralPath $evFile).LastWriteTimeUtc.ToString('o')
Write-Output ("EVIDENCE_MTIME_START=" + $evBefore)
# R1. refused-safe: backup path inside a user profile must be refused, nothing removed
$r1=& $pwsh7 -NoProfile -File $inst -Remove -RequireManifestMatch -BackupPath (Join-Path $env:TEMP 'should-refuse-bundle') -OperatorUser "$env:COMPUTERNAME\ahazan" 2>&1 | Out-String
$r1rc=$LASTEXITCODE
$m=(($r1 -replace '\s+',' ').Trim()); if($m.Length-gt300){$m=$m.Substring(0,300)}
Write-Output ("R1_REMOVE_BADPATH_RC=" + $r1rc + " MSG=" + $m)
& schtasks.exe /query /tn '\AiDevOps\WindowsRunnerMaintenance' *> $null
Write-Output ("R1_TASK_STILL_PRESENT_RC=" + $LASTEXITCODE)
# R2. full rollback with reviewed protected backup
$backup='C:\ProgramData\ai-devops\reviewed-maintenance-recovery-ENVY'
$r2=& $pwsh7 -NoProfile -File $inst -Remove -RequireManifestMatch -BackupPath $backup -OperatorUser "$env:COMPUTERNAME\ahazan" 2>&1 | Out-String
$r2rc=$LASTEXITCODE
$m=(($r2 -replace '\s+',' ').Trim()); if($m.Length-gt300){$m=$m.Substring(0,300)}
Write-Output ("R2_REMOVE_RC=" + $r2rc + " MSG=" + $m)
& schtasks.exe /query /tn '\AiDevOps\WindowsRunnerMaintenance' *> $null
Write-Output ("R2_TASK_ABSENT_RC=" + $LASTEXITCODE)
$pf='C:\Program Files\ai-devops\windows-runner-maintenance'
Write-Output ("R2_PAYLOAD_ROOT_PRESENT=" + (Test-Path -LiteralPath $pf))
$rt='C:\ProgramData\ai-devops\windows-runner-maintenance'
if (Test-Path -LiteralPath $rt) {
  $left=@(Get-ChildItem -LiteralPath $rt -Force | ForEach-Object Name)
  Write-Output ("R2_RUNTIME_LEFT=" + ($left -join ','))
} else { Write-Output 'R2_RUNTIME_LEFT=<root-absent>' }
$evAfter=(Get-Item -LiteralPath $evFile).LastWriteTimeUtc.ToString('o')
Write-Output ("EVIDENCE_MTIME_AFTER_REMOVE=" + $evAfter + " UNCHANGED=" + ($evAfter -eq $evBefore))
if (Test-Path -LiteralPath $backup) {
  $b=@(Get-ChildItem -LiteralPath $backup -Force | ForEach-Object { $_.Name })
  Write-Output ("R2_BACKUP_ENTRIES=" + ($b -join ','))
  $acl=(Get-Acl -LiteralPath $backup).Access | Where-Object { $_.IdentityReference -notmatch 'Administrators|SYSTEM' }
  Write-Output ("R2_BACKUP_NONADMIN_ACES=" + @($acl).Count)
}
$svc=Get-CimInstance Win32_Service -Filter "Name='actions.runner.popcre-ai-devops.EDGE-RUNN-ENVY'"
Write-Output ("R2_SERVICE=" + $svc.State + '|' + $svc.StartMode + '|' + $svc.StartName)
# R3. reinstall + verify (end state: installed and proven)
$r3=& $pwsh7 -NoProfile -File $inst -Install -OperatorUser "$env:COMPUTERNAME\ahazan" 2>&1 | Out-String
Write-Output ("R3_REINSTALL_RC=" + $LASTEXITCODE + " MSG=" + ((($r3 -replace '\s+',' ').Trim())))
$r4=& $pwsh7 -NoProfile -File $inst -Verify -OperatorUser "$env:COMPUTERNAME\ahazan" 2>&1 | Out-String
Write-Output ("R4_REVERIFY_RC=" + $LASTEXITCODE + " MSG=" + ((($r4 -replace '\s+',' ').Trim())))
& schtasks.exe /query /tn '\AiDevOps\WindowsRunnerMaintenance' *> $null
Write-Output ("FINAL_TASK_PRESENT_RC=" + $LASTEXITCODE)
$svc2=Get-CimInstance Win32_Service -Filter "Name='actions.runner.popcre-ai-devops.EDGE-RUNN-ENVY'"
Write-Output ("FINAL_SERVICE=" + $svc2.State + '|' + $svc2.StartMode + '|' + $svc2.StartName)
$evFinal=(Get-Item -LiteralPath $evFile).LastWriteTimeUtc.ToString('o')
Write-Output ("FINAL_EVIDENCE_MTIME=" + $evFinal + " PRESERVED=" + ($evFinal -eq $evBefore))
# no temporary proof tasks remain
$tp=Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -like '*limproof*' -or $_.TaskName -like '__*' }
Write-Output ("TEMP_TASKS_REMAINING=" + @($tp).Count)
