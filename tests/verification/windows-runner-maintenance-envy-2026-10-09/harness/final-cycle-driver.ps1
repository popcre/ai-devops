$ErrorActionPreference='Stop'
if ($env:COMPUTERNAME -ne 'EDGE-RUNN-ENVY') { throw 'wrong host' }
$repo='C:\repos\ai-devops'
$pwsh7='C:\Program Files\PowerShell\7\pwsh.exe'
$inst=Join-Path $repo 'bin\install-windows-runner-maintenance.ps1'
$invoke=Join-Path $repo 'bin\invoke-windows-runner-maintenance.ps1'
$evFile='C:\ProgramData\ai-devops\windows-runner-security.json'
$rt='C:\ProgramData\ai-devops\windows-runner-maintenance'
function Assert-Idle([string]$label){
  $w=Get-Process -Name 'Runner.Worker' -ErrorAction SilentlyContinue
  if ($w) { throw "runner busy before $label" }
  $svc=Get-CimInstance Win32_Service -Filter "Name='actions.runner.popcre-ai-devops.EDGE-RUNN-ENVY'"
  if ($svc.State -ne 'Running') { throw "service not running before $label" }
  Write-Output ("IDLE_OK " + $label + " service=" + $svc.State + '/' + $svc.StartMode + '/' + $svc.StartName)
}
# 1. second install (idempotency)
Assert-Idle 'second-install'
$o=& $pwsh7 -NoProfile -File $inst -Install -OperatorUser "$env:COMPUTERNAME\ahazan" 2>&1 | Out-String
Write-Output ("SECOND_INSTALL_RC=" + $LASTEXITCODE + " MSG=" + ((($o -replace '\s+',' ').Trim())))
# 2. update path (identical payload; backup into protected root)
Assert-Idle 'update'
$o=& $pwsh7 -NoProfile -File $inst -Update -BackupPath 'C:\ProgramData\ai-devops\reviewed-maintenance-recovery-ENVY-update' -OperatorUser "$env:COMPUTERNAME\ahazan" 2>&1 | Out-String
Write-Output ("UPDATE_RC=" + $LASTEXITCODE + " MSG=" + ((($o -replace '\s+',' ').Trim())))
if ($LASTEXITCODE -ne 0) {
  $o=& $pwsh7 -NoProfile -File $inst -Update -OperatorUser "$env:COMPUTERNAME\ahazan" 2>&1 | Out-String
  Write-Output ("UPDATE_RETRY_PLAIN_RC=" + $LASTEXITCODE + " MSG=" + ((($o -replace '\s+',' ').Trim())))
}
# 3. verify after update
Assert-Idle 'verify-after-update'
$o=& $pwsh7 -NoProfile -File $inst -Verify -OperatorUser "$env:COMPUTERNAME\ahazan" 2>&1 | Out-String
Write-Output ("VERIFY_AFTER_UPDATE_RC=" + $LASTEXITCODE + " MSG=" + ((($o -replace '\s+',' ').Trim())))
# 4. invoke idempotency (second successful invoke; first was from the non-elevated context)
Assert-Idle 'invoke-2'
$o=& $pwsh7 -NoProfile -File $invoke -Operation refresh-qualification -TimeoutSeconds 150 2>&1 | Out-String
Write-Output ("INVOKE2_RC=" + $LASTEXITCODE + " OUT=" + ((($o -replace '\s+',' ').Trim())))
# 5. hostile timing duplicate: request B injected while A's worker is Running
Assert-Idle 'hostile-duplicate'
$idA=[guid]::NewGuid().ToString(); $idB=[guid]::NewGuid().ToString()
function WriteReq([string]$id){
  $h=[ordered]@{schema_version=1;request_id=$id;operation='refresh-qualification';requested_at=[DateTime]::UtcNow.ToUniversalTime().ToString('o')}
  $json=$h | ConvertTo-Json -Compress
  [IO.File]::WriteAllText((Join-Path $rt ("requests\" + $id + ".json")),$json,[Text.UTF8Encoding]::new($false))
}
WriteReq $idA
& schtasks.exe /run /tn '\AiDevOps\WindowsRunnerMaintenance' *> $null
$sw=[Diagnostics.Stopwatch]::StartNew()
$running=$false
while ($sw.ElapsedMilliseconds -lt 5000) {
  if ((Get-ScheduledTask -TaskPath '\AiDevOps\' -TaskName 'WindowsRunnerMaintenance').State -eq 'Running') { $running=$true; break }
  Start-Sleep -Milliseconds 100
}
WriteReq $idB
& schtasks.exe /run /tn '\AiDevOps\WindowsRunnerMaintenance' *> $null
Write-Output ("MIDRUN_TASK_RUNNING_OBSERVED=" + $running + " delay_ms=" + $sw.ElapsedMilliseconds)
function WaitRes([string]$id,[int]$secs){
  $deadline=(Get-Date).AddSeconds($secs)
  while((Get-Date) -lt $deadline){
    $p=Join-Path $rt ("results\" + $id + ".json")
    if(Test-Path -LiteralPath $p){ return (Get-Content -LiteralPath $p -Raw | ConvertFrom-Json) }
    Start-Sleep -Milliseconds 300
  }
  return $null
}
$rA=WaitRes $idA 120; $rB=WaitRes $idB 120
$ra= if($rA){$rA.result}else{'NONE'}; $rb= if($rB){$rB.result}else{'NONE'}
Write-Output ("HOSTILE_DUP_A=" + $ra + " B=" + $rb)
# 6. evidence content-shape check (structure only; no values printed)
try {
  $j=Get-Content -LiteralPath $evFile -Raw | ConvertFrom-Json
  $expected=@('schema_version','recorded_at_utc','windows_build','tpm_present','tpm_ready','secure_boot','runner_service_automatic','machine_pwsh','git_bash')
  $names=@($j.PSObject.Properties.Name)
  $extra=@($names | Where-Object { $_ -notin $expected }).Count
  $missing=@($expected | Where-Object { $_ -notin $names }).Count
  Write-Output ("EVIDENCE_SHAPE parse=ok fields=" + $names.Count + " missing=" + $missing + " extra=" + $extra + " build_matches_known=" + ([int]$j.windows_build -eq 26200) + " schema_v1=" + ($j.schema_version -eq 1))
} catch { Write-Output ("EVIDENCE_SHAPE parse=FAIL " + $_.Exception.Message) }
# 7. second remove
Assert-Idle 'second-remove'
$o=& $pwsh7 -NoProfile -File $inst -Remove -RequireManifestMatch -BackupPath 'C:\ProgramData\ai-devops\reviewed-maintenance-recovery-ENVY-second' -OperatorUser "$env:COMPUTERNAME\ahazan" 2>&1 | Out-String
Write-Output ("SECOND_REMOVE_RC=" + $LASTEXITCODE + " MSG=" + ((($o -replace '\s+',' ').Trim())))
& schtasks.exe /query /tn '\AiDevOps\WindowsRunnerMaintenance' *> $null
Write-Output ("TASK_ABSENT_AFTER_SECOND_REMOVE_RC=" + $LASTEXITCODE)
# 8. remove idempotency (remove of absent installation)
$o=& $pwsh7 -NoProfile -File $inst -Remove -RequireManifestMatch -BackupPath 'C:\ProgramData\ai-devops\reviewed-maintenance-recovery-ENVY-second' -OperatorUser "$env:COMPUTERNAME\ahazan" 2>&1 | Out-String
Write-Output ("REMOVE_AGAIN_RC=" + $LASTEXITCODE + " MSG=" + ((($o -replace '\s+',' ').Trim())))
# 9. final reinstall + verify
Assert-Idle 'final-reinstall'
$o=& $pwsh7 -NoProfile -File $inst -Install -OperatorUser "$env:COMPUTERNAME\ahazan" 2>&1 | Out-String
Write-Output ("FINAL_REINSTALL_RC=" + $LASTEXITCODE + " MSG=" + ((($o -replace '\s+',' ').Trim())))
$o=& $pwsh7 -NoProfile -File $inst -Verify -OperatorUser "$env:COMPUTERNAME\ahazan" 2>&1 | Out-String
Write-Output ("FINAL_VERIFY_RC=" + $LASTEXITCODE + " MSG=" + ((($o -replace '\s+',' ').Trim())))
& schtasks.exe /query /tn '\AiDevOps\WindowsRunnerMaintenance' *> $null
Write-Output ("FINAL_TASK_PRESENT_RC=" + $LASTEXITCODE)
$svc=Get-CimInstance Win32_Service -Filter "Name='actions.runner.popcre-ai-devops.EDGE-RUNN-ENVY'"
Write-Output ("FINAL_SERVICE=" + $svc.State + '|' + $svc.StartMode + '|' + $svc.StartName)
$w=Get-Process -Name 'Runner.Worker' -ErrorAction SilentlyContinue
Write-Output ("FINAL_RUNNER_WORKER=" + [bool]$w)
Write-Output ("FINAL_EVIDENCE_MTIME=" + (Get-Item -LiteralPath $evFile).LastWriteTimeUtc.ToString('o'))
