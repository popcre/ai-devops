$ErrorActionPreference = 'Continue'
$rt = 'C:\ProgramData\ai-devops\windows-runner-maintenance'
$pl = 'C:\Program Files\ai-devops\windows-runner-maintenance'
Write-Output '---PAYLOAD---'
Get-ChildItem -LiteralPath $pl -File | ForEach-Object {
  $h = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash.ToLowerInvariant()
  Write-Output ("$h $($_.Name)")
}
Write-Output '---RUNTIME---'
Get-ChildItem -LiteralPath $rt -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
  Write-Output ("FILE " + $_.FullName.Substring($rt.Length) + " len=" + $_.Length + " mtime=" + $_.LastWriteTime.ToString('o'))
}
Write-Output '---NEWBACKUP---'
Get-ChildItem -LiteralPath 'C:\ProgramData\ai-devops' -Directory -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -like 'windows-runner-maintenance-recovery*' } |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 3 |
  ForEach-Object { Write-Output ("BACKUP " + $_.Name + " mtime=" + $_.LastWriteTime.ToString('o')) }
Write-Output '---TASK---'
$t = Get-ScheduledTask -TaskPath '\AiDevOps\' -TaskName 'WindowsRunnerMaintenance'
Write-Output ("TASK state=" + $t.State + " user=" + $t.Principal.UserId + " logon=" + $t.Principal.LogonType + " run=" + $t.Principal.RunLevel)
Write-Output ("TASK exec=" + $t.Actions[0].Execute + " args=" + $t.Actions[0].Arguments)
Write-Output '---EVIDENCE---'
$ev = Get-Item 'C:\ProgramData\ai-devops\windows-runner-security.json'
Write-Output ("EVIDENCE len=" + $ev.Length + " mtime=" + $ev.LastWriteTime.ToString('o'))
Write-Output '---SVC---'
Get-CimInstance Win32_Service | Where-Object { $_.Name -like '*runner*' -or $_.Name -like '*actions*' } | ForEach-Object {
  Write-Output ("SVC " + $_.Name + " status=" + $_.State + " start=" + $_.StartMode + " account=" + $_.StartName)
}
Write-Output '---SECUREBOOT---'
try { Write-Output ("SECUREBOOT=" + [string](Confirm-SecureBootUEFI)) } catch { Write-Output ("SECUREBOOT=ERR " + $_.Exception.Message) }
Write-Output '---DONE---'
