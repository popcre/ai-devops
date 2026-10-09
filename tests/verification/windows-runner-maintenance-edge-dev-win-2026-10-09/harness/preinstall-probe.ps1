$ErrorActionPreference = 'Continue'
Write-Output ("HOST=" + $env:COMPUTERNAME)
Write-Output ("BOOT=" + (Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToString('o'))
$sb = 'unknown'
try { $sb = [string](Confirm-SecureBootUEFI) } catch { $sb = 'ERR:' + $_.Exception.Message }
Write-Output ("SECUREBOOT=" + $sb)
Write-Output ("ADMIN=" + [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
$wi = [Security.Principal.WindowsIdentity]::GetCurrent()
foreach ($g in $wi.Groups) { if ($g.Value -like 'S-1-16-*') { Write-Output ("IL=" + $g.Value) } }
Write-Output '---SERVICES---'
Get-CimInstance Win32_Service | Where-Object { $_.Name -like '*runner*' -or $_.Name -like '*actions*' } | ForEach-Object {
  Write-Output ("SVC " + $_.Name + " status=" + $_.State + " start=" + $_.StartMode + " account=" + $_.StartName)
}
Write-Output '---TASK---'
$t = Get-ScheduledTask -TaskPath '\AiDevOps\' -TaskName 'WindowsRunnerMaintenance' -ErrorAction SilentlyContinue
if ($t) {
  Write-Output ("TASK state=" + $t.State)
  Write-Output ("TASK user=" + $t.Principal.UserId + " logon=" + $t.Principal.LogonType + " run=" + $t.Principal.RunLevel)
  Write-Output ("TASK triggerCount=" + @($t.Triggers).Count + " actionCount=" + @($t.Actions).Count)
  foreach ($tr in @($t.Triggers)) { Write-Output ("TASK trigger type=" + $tr.CimClass.CimClassName) }
  Write-Output ("TASK exec=" + $t.Actions[0].Execute + " args=" + $t.Actions[0].Arguments)
  $info = Get-ScheduledTaskInfo -TaskPath '\AiDevOps\' -TaskName 'WindowsRunnerMaintenance'
  Write-Output ("TASK last=" + $info.LastRunTime.ToString('o') + " result=" + $info.LastTaskResult)
  $sd = $t.SecurityDescriptor
  if ($sd) { Write-Output ("TASK sddl=" + $sd) } else { Write-Output 'TASK sddl=EMPTY' }
} else {
  Write-Output 'TASK ABSENT'
}
Write-Output '---EVIDENCE---'
$ev = 'C:\ProgramData\ai-devops\windows-runner-security.json'
if (Test-Path $ev) {
  $i = Get-Item $ev
  Write-Output ("EVIDENCE len=" + $i.Length + " mtime=" + $i.LastWriteTime.ToString('o'))
} else { Write-Output 'EVIDENCE ABSENT' }
Write-Output '---RUNTIME---'
$rt = 'C:\ProgramData\ai-devops\windows-runner-maintenance'
Get-ChildItem -LiteralPath $rt -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
  Write-Output ("FILE " + $_.FullName.Substring($rt.Length) + " len=" + $_.Length + " mtime=" + $_.LastWriteTime.ToString('o'))
}
Write-Output '---BACKUPS---'
Get-ChildItem -LiteralPath 'C:\ProgramData\ai-devops' -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'windows-runner-maintenance-recovery*' } | ForEach-Object {
  Write-Output ("BACKUP " + $_.Name + " mtime=" + $_.LastWriteTime.ToString('o'))
}
Write-Output '---TPM---'
try {
  $tpm = Get-Tpm
  Write-Output ("TPM present=" + $tpm.TpmPresent + " ready=" + $tpm.TpmReady)
} catch { Write-Output ("TPM ERR " + $_.Exception.Message) }
Write-Output '---SID---'
$op = Get-LocalUser -Name 'ahazan' -ErrorAction SilentlyContinue
if ($op) { Write-Output ("OPERATOR sid=" + $op.SID.Value + " enabled=" + $op.Enabled) }
Write-Output '---DONE---'
