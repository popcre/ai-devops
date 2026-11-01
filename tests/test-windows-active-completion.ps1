# Native protocol components only. No source qualification or real workload.
param([string]$SourceRoot=(Split-Path $PSScriptRoot -Parent),[Parameter(Mandatory=$true)][string]$PythonExe)
$ErrorActionPreference='Stop';$ProgressPreference='SilentlyContinue'
if($env:OS -ne 'Windows_NT'){throw 'Native Windows required'}
$supervisor=Join-Path $SourceRoot 'tools/github-requests/source_generation_windows.ps1'
$text=[IO.File]::ReadAllText($supervisor);$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseInput($text,[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'Supervisor syntax invalid'}
foreach($name in @('Assert-StagingParent','New-BootstrapPrivateDirectory','Assert-ActiveArguments','Assert-ReadArguments')){
 $node=$ast.Find({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -ceq $name},$true)
 if($null -eq $node){throw 'Shared native helper missing'};. ([scriptblock]::Create($node.Extent.Text))
}
$root=$null;$failure=$null;$savedTemp=$env:TEMP;$savedTmp=$env:TMP
foreach($candidate in @([Environment]::GetFolderPath('UserProfile'),(Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Temp'),[Environment]::GetFolderPath('ProgramFiles'),'C:/')){
 try{Assert-StagingParent ([IO.DirectoryInfo]::new($candidate));$new=New-BootstrapPrivateDirectory (Join-Path $candidate ('ai-gh-active-test-'+[Guid]::NewGuid().ToString('N')));$root=$new.FullName;break}catch{}
}
if(-not $root){throw 'No existing protected fixture parent; no permissions changed'}
$env:TEMP=$root;$env:TMP=$root;$checks=0
function Check([bool]$Good,[string]$Message){if(-not $Good){throw $Message};$script:checks++}
$source=[regex]::Match($text,"(?s)Add-Type -TypeDefinition @'\r?\n(.*?)\r?\n'@").Groups[1].Value
try{
 Add-Type -TypeDefinition $source
 $rootPin=[GenerationCustody]::Hold($root,$true,$true)
 $beforePrivilege=[GenerationCustody]::PrivilegedContext()
 $beforeToken=(& (Join-Path $env:WINDIR 'System32/whoami.exe') /priv /fo csv|Out-String)
 $controlReader=[IO.Pipes.AnonymousPipeServerStream]::new([IO.Pipes.PipeDirection]::In,[IO.HandleInheritability]::None)
 $controlWriter=[IO.Pipes.AnonymousPipeClientStream]::new([IO.Pipes.PipeDirection]::Out,$controlReader.ClientSafePipeHandle)
 try{
  $lines=[GenerationCustody+ParentLines]::new($controlReader)
  $part=[Text.Encoding]::ASCII.GetBytes('{"schema":1');$controlWriter.Write($part,0,$part.Length);$controlWriter.Flush();[Threading.Thread]::Sleep(10)
  Check (@($lines.Poll()).Count -eq 0) 'Partial control frame cannot ACK'
  $part=[Text.Encoding]::ASCII.GetBytes(',"phase":"ack"}'+"`n");$controlWriter.Write($part,0,$part.Length);$controlWriter.Flush();$ready=@();$clock=[Diagnostics.Stopwatch]::StartNew()
  while($ready.Count -eq 0 -and $clock.ElapsedMilliseconds -lt 1000){$ready=@($lines.Poll());[Threading.Thread]::Sleep(1)}
  Check ($ready.Count -eq 1 -and $ready[0] -ceq '{"schema":1,"phase":"ack"}') 'Native parent control reassembles bounded frames'
  $part=[Text.Encoding]::ASCII.GetBytes(('x'*4097));$controlWriter.Write($part,0,$part.Length);$controlWriter.Flush();$clock.Restart()
  while(-not $lines.Invalid -and $clock.ElapsedMilliseconds -lt 1000){[void]$lines.Poll();[Threading.Thread]::Sleep(1)}
  Check $lines.Invalid 'Oversize parent control invalidates channel'
 }finally{$controlWriter.Dispose();$controlReader.Dispose()}
 foreach($name in @('tick','alarm','links')){Assert-ActiveArguments 'bin/ai-blocker-watch' @($name) $false;Check $true 'Original finite active admission'}
 foreach($name in @('alarm','links')){Assert-ActiveArguments 'bin/ai-blocker-watch' @($name) $true;Check $true 'Named SDK admission'}
 $refused=$false;try{Assert-ActiveArguments 'bin/ai-blocker-watch' @('tick') $true}catch{$refused=$true};Check $refused 'SDK cannot admit provider ticks'
 $refused=$false;try{Assert-ReadArguments 'bin/ai-blocker-watch' @('alarm')}catch{$refused=$true};Check $refused 'Active work cannot masquerade as read profile'
 $bash=Join-Path $env:ProgramFiles 'Git/bin/bash.exe';$actor=Join-Path $PSScriptRoot 'windows_active_actor.py'
 foreach($mode in @('valid','bash-facts','ack-malformed','ack-partial','ack-late','closed','nonpipe','alias','full-event','full-ack','forged-claim','raw-duplicate','raw-overflow','raw-oversize','legacy-pr','provider-exit','provider-uncertain','provider-timeout')){
  $event=$null;$ack=$null;$child=$null
  try{
   $event=if($mode -eq 'legacy-pr'){[GenerationCustody+EventChannel]::new()}else{[GenerationCustody+EventChannel]::new(256)};$ack=[GenerationCustody+EventChannel]::new(1,$true)
   $env:AI_GH_ACTIVE_EVENT_HANDLE=[string]$event.WriteHandle;$env:AI_GH_ACTIVE_ACK_HANDLE=[string]$ack.ReadHandle
   $env:AI_GH_QUALIFICATION_EVENT_HANDLE=[string]$event.WriteHandle;$env:SDK_CONTEXT_SENTINEL='original-context'
   if($mode -eq 'full-event'){for($i=0;$i -lt 256;$i++){if(-not $event.Send([Text.Encoding]::ASCII.GetBytes(('x'*4096)))){break}};Check ($i -gt 0) 'Filled DATA pipe'}
   if($mode -eq 'full-ack'){for($i=0;$i -lt 256;$i++){if(-not $ack.Send([Text.Encoding]::ASCII.GetBytes(('x'*4096)))){break}};Check ($i -gt 0) 'Filled ACK pipe'}
   $runner=Join-Path $root 'actor.sh'
   $pythonPath=$PythonExe.Replace('\','/');$actorPath=$actor.Replace('\','/')
   [IO.File]::WriteAllText($runner,("#!/usr/bin/env bash`nexec `""+$pythonPath+"`" -I -S `""+$actorPath+"`" "+$mode+"`n"),[Text.UTF8Encoding]::new($false))
   if($mode -eq 'bash-facts'){
    $env:AI_GH_ACTIVE_PYTHON=$PythonExe;$env:AI_GH_STATE_DIR=Join-Path $root 'measure-state'
    $telemetry=(Join-Path $SourceRoot 'tools/github-requests/telemetry.sh').Replace('\','/')
    $script="#!/usr/bin/env bash`nset -e`nsource `"$telemetry`"`ngh_measure_active_begin blocker_watch_alarm $('a'*32) '' alarm_scan`n"
    $end='{"schema":3,"measurement":"workflow_outcome","utc":"2026-11-01T00:00:00Z","caller":"ai-blocker-watch","workflow":"blocker_watch_alarm","workflow_id":"'+('a'*32)+'","parent_workflow_id":null,"boundary":"alarm_scan","outcome":"completed","elapsed_ms":1,"attempted_count":1,"succeeded_count":1,"failed_count":0,"skipped_count":0}'
    $script+="gh_measure_active_channel end '$end'`ngh_measure_blocker_evidence blocker_watch_alarm $('a'*32) alarm_stale 2000000000000 2000000001000 2000000002000 alarm_batch_acknowledged`n"
    [IO.File]::WriteAllText($runner,$script,[Text.UTF8Encoding]::new($false))
   }
   $start=[Diagnostics.ProcessStartInfo]::new();$start.FileName=$bash;$start.Arguments=([GenerationCustody]::Quote($runner));$start.WorkingDirectory=$root;$start.UseShellExecute=$false;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true;$start.RedirectStandardInput=$true
   $child=[Diagnostics.Process]::new();$child.StartInfo=$start;Check $child.Start() 'Native actor started';$child.StandardInput.Close()
   $stdout=[IO.MemoryStream]::new();$stderr=[IO.MemoryStream]::new();$output=$child.StandardOutput.BaseStream.CopyToAsync($stdout);$errorOutput=$child.StandardError.BaseStream.CopyToAsync($stderr)
   $watch=[Diagnostics.Stopwatch]::StartNew();$messages=[Collections.Generic.List[string]]::new();$ackSent=$false;$lateAt=-1
   while(-not $child.WaitForExit(5)){
    if($watch.ElapsedMilliseconds -gt 15000){$child.Kill();throw ('Native actor deadline: '+$mode)}
    if($mode -ne 'full-event'){
     foreach($message in $event.TakeMessages()){
      $messages.Add($message)
      if(-not $ackSent -and $message -like '*active_completion_boundary*'){
       if($mode -eq 'ack-late'){$lateAt=$watch.ElapsedMilliseconds+400;$ackSent=$true}
       elseif($mode -notin @('full-ack','raw-duplicate','raw-overflow','raw-oversize')){
        $wire='{"schema":1,"phase":"ack","workflow_id":"'+('a'*32)+'"}'
        if($mode -eq 'ack-malformed'){$wire='{"schema":1,"phase":"ack","workflow_id":"'+('a'*32)+'","extra":1}'}
        if($mode -ne 'ack-partial'){$wire+="`n"};[void]$ack.Send([Text.Encoding]::ASCII.GetBytes($wire));$ackSent=$true
       }
      }
     }
    }
    if($lateAt -ge 0 -and $watch.ElapsedMilliseconds -ge $lateAt){[void]$ack.Send([Text.Encoding]::ASCII.GetBytes(('{"schema":1,"phase":"ack","workflow_id":"'+('a'*32)+'"}'+"`n")));$lateAt=-1}
   }
   $child.WaitForExit();[void]$output.Wait(2000);[void]$errorOutput.Wait(2000)
   foreach($message in $event.TakeMessages()){$messages.Add($message)}
   $expected=if($mode -eq 'provider-timeout'){124}elseif($mode -in @('provider-exit','provider-uncertain')){7}else{0}
   if($child.ExitCode -ne $expected){throw ('Native actor '+$mode+' exit '+$child.ExitCode+': '+[Text.Encoding]::UTF8.GetString($stderr.ToArray()))};Check $true ('Native actor '+$mode)
   if($mode -eq 'valid'){Check ($messages.Count -eq 2) 'Reciprocal BEGIN/END transported'}
   if($mode -eq 'bash-facts'){
    Check ($messages.Count -eq 3 -and $messages[2] -like '*active_event_facts*') 'Actual Bash durable append forwards facts after END'
    Check (@(Get-ChildItem -LiteralPath (Join-Path $root 'measure-state/measurements') -File).Count -gt 0) 'Original durable measurement retained'
   }
   if($mode -in @('raw-overflow','raw-oversize')){Check $event.Invalid 'Oversize/frame-cap invalidates channel'}
   if($mode -eq 'raw-duplicate'){
    $data=Join-Path $root 'data.json';[IO.File]::WriteAllText($data,(ConvertTo-Json -InputObject @($messages.ToArray()) -Compress))
    $reply=& $PythonExe -I -S $actor validate $data;Check ($LASTEXITCODE -eq 0) 'DATA validator completed';$validated=$reply|ConvertFrom-Json;Check (-not $validated.protocol_valid -and -not $validated.qualified) 'Duplicate frames cannot qualify'
   }
   if($mode -eq 'legacy-pr'){Check ($messages.Count -eq 1 -and $messages[0] -like '*pr_wait*') 'Original PR event route preserved'}
   if($mode -in @('provider-exit','provider-uncertain','provider-timeout')){
    $proof=Get-Content -LiteralPath (Join-Path $root 'provider-proof.json') -Raw|ConvertFrom-Json
    Check ($proof.reserved_pipes_absent -and $proof.observer_keys_absent -and -not $proof.forged_end_sent) 'Provider cannot inherit/forge reserved channels'
    Check ($proof.stdin_eof -and $proof.cwd_preserved -and $proof.context_preserved) 'Provider original context/stdin preserved'
    $unicode=([string][char]0x65e5)+[char]0x672c+[char]0x8a9e
    Check (($proof.arguments -join '|') -ceq ('quoted space|quote"backslash\|'+$unicode)) 'Original nonASCII/quoted argv preserved'
    if($mode -ne 'provider-timeout'){
     Check ([Convert]::ToBase64String($stdout.ToArray()) -ceq 'b3JpZ2luYWwtb3V0cHV0AP8K') 'Original stdout bytes preserved'
     Check ([Convert]::ToBase64String($stderr.ToArray()) -ceq 'b3JpZ2luYWwtZXJyb3IA/go=') 'Original stderr bytes preserved'
    }
    Remove-Item -LiteralPath (Join-Path $root 'provider-proof.json') -Force
   }
  }finally{if($child){if(-not $child.HasExited){$child.Kill();[void]$child.WaitForExit(5000)};$child.Dispose()};if($event){$event.Dispose()};if($ack){$ack.Dispose()};if($stdout){$stdout.Dispose()};if($stderr){$stderr.Dispose()}}
 }
 # Original job cancellation must terminate the trampoline AND provider tree.
 $event=[GenerationCustody+EventChannel]::new(256);$ack=[GenerationCustody+EventChannel]::new(1,$true);$job=[GenerationCustody]::Job();$cancelChild=$null;$providerProcess=$null
 try{
  $env:AI_GH_ACTIVE_EVENT_HANDLE=[string]$event.WriteHandle;$env:AI_GH_ACTIVE_ACK_HANDLE=[string]$ack.ReadHandle
  [IO.File]::WriteAllText($runner,("#!/usr/bin/env bash`nexec `""+$pythonPath+"`" -I -S `""+$actorPath+"`" provider-cancel`n"),[Text.UTF8Encoding]::new($false))
  $cancelChild=[GenerationCustody]::Start($job,$bash,([GenerationCustody]::Quote($runner)),$root,$false,$true)
  $until=[Diagnostics.Stopwatch]::StartNew();$proofPath=Join-Path $root 'provider-proof.json'
  while(-not(Test-Path -LiteralPath $proofPath) -and $until.ElapsedMilliseconds -lt 10000){[Threading.Thread]::Sleep(10)}
  Check (Test-Path -LiteralPath $proofPath) 'Provider reached original workload before cancellation'
  $proof=Get-Content -LiteralPath $proofPath -Raw|ConvertFrom-Json;$providerProcess=[Diagnostics.Process]::GetProcessById($proof.pid);$retained=$providerProcess.Handle
  $job.Dispose();$job=$null;Check ($cancelChild.WaitForExit(5000) -and $providerProcess.WaitForExit(5000)) 'Owned cancellation preserves descendant cleanup'
 }finally{if($job){$job.Dispose()};if($cancelChild){$cancelChild.Dispose()};if($providerProcess){$providerProcess.Dispose()};$event.Dispose();$ack.Dispose()}
 Check ([GenerationCustody]::PrivilegedContext() -eq $beforePrivilege) 'Parent original privileges unchanged'
 Check ((& (Join-Path $env:WINDIR 'System32/whoami.exe') /priv /fo csv|Out-String) -ceq $beforeToken) 'Parent privilege attributes unchanged'
 [pscustomobject]@{native_active_component_cases=$checks;component_only=$true;original_active_qualified=$false;real_api_or_notifications=$false}|ConvertTo-Json -Compress
}catch{$failure=$_;throw}finally{
 if($rootPin){$rootPin.Dispose()};$env:TEMP=$savedTemp;$env:TMP=$savedTmp
 if(-not $failure -and $root -and (Test-Path -LiteralPath $root)){Remove-Item -LiteralPath $root -Recurse -Force}
}
