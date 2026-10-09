$ErrorActionPreference='Stop'
$rt='C:\ProgramData\ai-devops\windows-runner-maintenance'
$mySid=[Security.Principal.WindowsIdentity]::GetCurrent().User
function WriteReq([string]$id){
  $h=[ordered]@{schema_version=1;request_id=$id;operation='refresh-qualification';requested_at=[DateTime]::UtcNow.ToUniversalTime().ToString('o')}
  $json=$h | ConvertTo-Json -Compress
  $p=Join-Path $rt ("requests\" + $id + ".json")
  [IO.File]::WriteAllText($p,$json,[Text.UTF8Encoding]::new($false))
  # elevated admins get Administrators-owned files; re-own to the caller SID exactly like the client does
  $info=[IO.FileInfo]::new($p)
  $sec=[IO.FileSystemAclExtensions]::GetAccessControl($info,[Security.AccessControl.AccessControlSections]::Owner)
  if ($sec.GetOwner([Security.Principal.SecurityIdentifier]).Value -cne $mySid.Value) {
    $sec.SetOwner([Security.Principal.SecurityIdentifier]::new($mySid.Value))
    [IO.FileSystemAclExtensions]::SetAccessControl($info,$sec)
  }
  $own=([Security.AccessControl.FileSecurity]::new($p,[Security.AccessControl.AccessControlSections]::Owner)).GetOwner([Security.Principal.SecurityIdentifier]).Value
  Write-Output ("WROTE " + $id + " owner_is_caller=" + ($own -ceq $mySid.Value))
}
function WaitRes([string]$id,[int]$secs){
  $deadline=(Get-Date).AddSeconds($secs)
  while((Get-Date) -lt $deadline){
    $p=Join-Path $rt ("results\" + $id + ".json")
    if(Test-Path -LiteralPath $p){ return (Get-Content -LiteralPath $p -Raw | ConvertFrom-Json) }
    Start-Sleep -Milliseconds 300
  }
  return $null
}
$w=Get-Process -Name 'Runner.Worker' -ErrorAction SilentlyContinue
if ($w) { throw 'runner busy' }
# wait for task Ready (no live worker from prior phases)
$deadline=(Get-Date).AddSeconds(30)
while ((Get-Date) -lt $deadline) {
  if ((Get-ScheduledTask -TaskPath '\AiDevOps\' -TaskName 'WindowsRunnerMaintenance').State -eq 'Ready') { Start-Sleep -Milliseconds 700; break }
  Start-Sleep -Milliseconds 300
}
$idA=[guid]::NewGuid().ToString(); $idB=[guid]::NewGuid().ToString()
WriteReq $idA
& schtasks.exe /run /tn '\AiDevOps\WindowsRunnerMaintenance' *> $null
$sw=[Diagnostics.Stopwatch]::StartNew()
$running=$false
while ($sw.ElapsedMilliseconds -lt 5000) {
  if ((Get-ScheduledTask -TaskPath '\AiDevOps\' -TaskName 'WindowsRunnerMaintenance').State -eq 'Running') { $running=$true; break }
  Start-Sleep -Milliseconds 50
}
WriteReq $idB
& schtasks.exe /run /tn '\AiDevOps\WindowsRunnerMaintenance' *> $null
Write-Output ("MIDRUN_TASK_RUNNING_OBSERVED=" + $running + " delay_ms=" + $sw.ElapsedMilliseconds)
$rA=WaitRes $idA 120; $rB=WaitRes $idB 120
$ra= if($rA){$rA.result}else{'NONE'}; $rb= if($rB){$rB.result}else{'NONE'}
Write-Output ("HOSTILE_DUP_A=" + $ra + " B=" + $rb)
Write-Output ("A_MSG=" + $(if($rA){$rA.message}else{'-'}))
Write-Output ("B_MSG=" + $(if($rB){$rB.message}else{'-'}))
# cleanup request files
Remove-Item -LiteralPath (Join-Path $rt ("requests\" + $idA + ".json")) -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $rt ("requests\" + $idB + ".json")) -ErrorAction SilentlyContinue
$svc=Get-CimInstance Win32_Service -Filter "Name='actions.runner.popcre-ai-devops.EDGE-RUNN-ENVY'"
Write-Output ("SERVICE=" + $svc.State + '|' + $svc.StartMode + '|' + $svc.StartName)
