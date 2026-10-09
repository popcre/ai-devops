$ErrorActionPreference='Continue'
$rt='C:\ProgramData\ai-devops\windows-runner-maintenance'
$repo='C:\repos\ai-devops'
$pwsh7='C:\Program Files\PowerShell\7\pwsh.exe'
$invoke=Join-Path $repo 'bin\invoke-windows-runner-maintenance.ps1'
$lines=New-Object System.Collections.Generic.List[string]
function Note([string]$s){ $lines.Add($s) }
function WaitTaskReady([int]$secs){
  $deadline=(Get-Date).AddSeconds($secs)
  while((Get-Date) -lt $deadline){
    $s=(Get-ScheduledTask -TaskPath '\AiDevOps\' -TaskName 'WindowsRunnerMaintenance' -ErrorAction SilentlyContinue).State
    if($s -eq 'Ready'){ Start-Sleep -Milliseconds 700; return $true }
    Start-Sleep -Milliseconds 400
  }
  return $false
}
function ResKeys([string]$path){ try { $r=Get-Content -LiteralPath $path -Raw | ConvertFrom-Json; return (($r.PSObject.Properties.Name | Sort-Object) -join ',') } catch { return 'UNPARSEABLE' } }
function WriteReq([string]$id,[bool]$extra){
  $h=[ordered]@{schema_version=1;request_id=$id;operation='refresh-qualification';requested_at=[DateTime]::UtcNow.ToUniversalTime().ToString('o')}
  if($extra){$h['extra_field']='x'}
  $json=$h | ConvertTo-Json -Compress
  [IO.File]::WriteAllText((Join-Path $rt ("requests\" + $id + ".json")),$json,[Text.UTF8Encoding]::new($false))
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
# 0. context identity and non-elevation proof
$ident=[Security.Principal.WindowsIdentity]::GetCurrent()
$elev=([Security.Principal.WindowsPrincipal]$ident).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
whoami /groups | Set-Content -LiteralPath (Join-Path $env:TEMP 'envy-negproof-groups.txt')
Note ("CTX elevated=" + $elev + " user=" + $ident.Name)
& net.exe session *> $null 2>&1
Note ("NET_SESSION_RC=" + $LASTEXITCODE)
# 1. task privilege negatives (GRGX must not allow change/delete)
& schtasks.exe /query /tn '\AiDevOps\WindowsRunnerMaintenance' *> $null
Note ("QUERY_RC=" + $LASTEXITCODE)
$o1=& schtasks.exe /change /tn '\AiDevOps\WindowsRunnerMaintenance' /disable 2>&1 | Out-String
Note ("CHANGE_DISABLE_RC=" + $LASTEXITCODE + " MSG=" + ((($o1 -replace '\s+',' ').Trim())))
$o2=& schtasks.exe /delete /tn '\AiDevOps\WindowsRunnerMaintenance' /f 2>&1 | Out-String
Note ("DELETE_RC=" + $LASTEXITCODE + " MSG=" + ((($o2 -replace '\s+',' ').Trim())))
& schtasks.exe /query /tn '\AiDevOps\WindowsRunnerMaintenance' *> $null
Note ("TASK_PRESENT_AFTER_ATTEMPTS_RC=" + $LASTEXITCODE)
# 2. unknown operation / unknown argument rejected at the client boundary
$o=& $pwsh7 -NoProfile -File $invoke -Operation not-a-real-op 2>&1 | Out-String
$rc=$LASTEXITCODE; $m=($o -replace '\s+',' ').Trim(); if($m.Length-gt200){$m=$m.Substring(0,200)}
Note ("UNKNOWN_OP_RC=" + $rc + " MSG=" + $m)
$o=& $pwsh7 -NoProfile -File $invoke -Frobnicate 2>&1 | Out-String
$rc=$LASTEXITCODE; $m=($o -replace '\s+',' ').Trim(); if($m.Length-gt200){$m=$m.Substring(0,200)}
Note ("UNKNOWN_ARG_RC=" + $rc + " MSG=" + $m)
# 3. unknown field in request JSON -> REQUEST_REJECTED, bounded schema
$idC=[guid]::NewGuid().ToString()
WriteReq $idC $true
& schtasks.exe /run /tn '\AiDevOps\WindowsRunnerMaintenance' *> $null
Note ("RUN_C_RC=" + $LASTEXITCODE)
$c=WaitRes $idC 40
if($c){ Note ("UNKNOWN_FIELD_RESULT=" + $c.result + " KEYS=" + (($c.PSObject.Properties.Name|Sort-Object)-join',')) } else { Note 'UNKNOWN_FIELD_RESULT=NO_RESULT' }
Remove-Item -LiteralPath (Join-Path $rt ("requests\" + $idC + ".json")) -ErrorAction SilentlyContinue
Note ("WORKER_READY_AFTER_C=" + (WaitTaskReady 30))
# 4. positive invoke from this non-elevated operator context (fresh worker instance)
Note ("WORKER_READY_BEFORE_INVOKE=" + (WaitTaskReady 30))
$evB=(Get-Item -LiteralPath 'C:\ProgramData\ai-devops\windows-runner-security.json').LastWriteTimeUtc.ToString('o')
$o=& $pwsh7 -NoProfile -File $invoke -Operation refresh-qualification -TimeoutSeconds 150 2>&1 | Out-String
$rc=$LASTEXITCODE
$evA=(Get-Item -LiteralPath 'C:\ProgramData\ai-devops\windows-runner-security.json').LastWriteTimeUtc.ToString('o')
$m=($o -replace '\s+',' ').Trim(); if($m.Length-gt400){$m=$m.Substring(0,400)}
Note ("INVOKE_RC=" + $rc + " OUT=" + $m)
Note ("EVIDENCE_MTIME_BEFORE=" + $evB)
Note ("EVIDENCE_MTIME_AFTER=" + $evA)
Note ("EVIDENCE_ADVANCED=" + ($evA -gt $evB))
# 5. concurrency: two valid requests, one start -> one executed, one CONCURRENT_EXECUTION
Note ("WORKER_READY_BEFORE_AB=" + (WaitTaskReady 30))
$idA=[guid]::NewGuid().ToString(); $idB=[guid]::NewGuid().ToString()
WriteReq $idA $false; WriteReq $idB $false
& schtasks.exe /run /tn '\AiDevOps\WindowsRunnerMaintenance' *> $null
Note ("RUN_AB_RC=" + $LASTEXITCODE)
$rA=WaitRes $idA 90; $rB=WaitRes $idB 90
$ra= if($rA){$rA.result}else{'NONE'}; $rb= if($rB){$rB.result}else{'NONE'}
Note ("CONC_A_RESULT=" + $ra + " CONC_B_RESULT=" + $rb)
Remove-Item -LiteralPath (Join-Path $rt ("requests\" + $idA + ".json")) -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $rt ("requests\" + $idB + ".json")) -ErrorAction SilentlyContinue
Note ("WORKER_READY_AFTER_AB=" + (WaitTaskReady 30))
# 6. audit tail (bounded, sid masked)
$audit=Join-Path $rt 'audit.jsonl'
$tail=Get-Content -LiteralPath $audit -Tail 5 -ErrorAction SilentlyContinue
foreach($l in $tail){
  try { $e=$l|ConvertFrom-Json
    $sid=$e.requester_sid -replace 'S-1-5-21-\d+-\d+-\d+','S-1-5-21-***'
    $dur=[math]::Round(([datetime]$e.ended_at_utc - [datetime]$e.started_at_utc).TotalSeconds,1)
    Note ("AUDIT result=" + $e.result + " op=" + $e.operation + " host=" + $e.host + " sid=" + $sid + " dur=" + $dur + "s")
  } catch { Note 'AUDIT_LINE_UNPARSEABLE' }
}
# 7. no-leak: every result file must carry exactly the 9 safe fields
$safeSorted=(('schema_version','request_id','operation','host','started_at_utc','ended_at_utc','result','exit_code','message') | Sort-Object) -join ','
$bad=0; $count=0
Get-ChildItem -LiteralPath (Join-Path $rt 'results') -Filter *.json -ErrorAction SilentlyContinue | ForEach-Object {
  $count++
  if ((ResKeys $_.FullName) -ne $safeSorted) { $bad++ }
}
Note ("RESULT_FILES=" + $count + " SCHEMA_VIOLATIONS=" + $bad)
Set-Content -LiteralPath (Join-Path $env:TEMP 'envy-negproof.txt') -Value ($lines -join [Environment]::NewLine)
exit 0
