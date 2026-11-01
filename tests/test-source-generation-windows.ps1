# Focused native custody tests; writes only a newly-created private directory.
param([string]$Supervisor=(Join-Path $PSScriptRoot '..\tools\github-requests\source_generation_windows.ps1'),
      [string]$EventHelper=(Join-Path $PSScriptRoot '..\tools\github-requests\windows_event.py'),
      [string]$CounterManifest,[string]$ExpectedCounterManifestSha256)
$ErrorActionPreference='Stop'
if ($env:OS -ne 'Windows_NT') { throw 'Native Windows required' }
$text=[IO.File]::ReadAllText($Supervisor)
$source=[regex]::Match($text,"(?s)Add-Type -TypeDefinition @'\r?\n(.*?)\r?\n'@").Groups[1].Value
if (-not $source) { throw 'Supervisor native custody class missing' }
Add-Type -TypeDefinition $source
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
public static class FixtureDacl {
 [DllImport("advapi32.dll",SetLastError=true)] static extern bool GetSecurityDescriptorDacl(IntPtr descriptor,out bool present,out IntPtr acl,out bool defaulted);
 [DllImport("advapi32.dll",SetLastError=true)] static extern uint SetSecurityInfo(SafeFileHandle handle,uint kind,uint flags,IntPtr owner,IntPtr group,IntPtr dacl,IntPtr sacl);
 public static void Apply(SafeFileHandle handle,byte[] descriptor){
  if(handle==null||handle.IsInvalid||handle.IsClosed||descriptor==null||descriptor.Length==0||descriptor.Length>65536)throw new IOException("Invalid owned fixture DACL");
  GCHandle pinned=GCHandle.Alloc(descriptor,GCHandleType.Pinned);
  try{bool present,defaulted;IntPtr dacl;if(!GetSecurityDescriptorDacl(pinned.AddrOfPinnedObject(),out present,out dacl,out defaulted)||!present||dacl==IntPtr.Zero)throw new IOException("Owned fixture DACL required");
   uint error=SetSecurityInfo(handle,1,0x80000004,IntPtr.Zero,IntPtr.Zero,dacl,IntPtr.Zero);if(error!=0)throw new IOException("Owned fixture DACL update failed; Win32="+error);
  }finally{pinned.Free();}
 }
}
'@
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseInput($text,[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'Supervisor PowerShell syntax invalid'}
$guard=$ast.Find({param($node)$node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Assert-ReadArguments'},$true)
. ([scriptblock]::Create($guard.Extent.Text))
foreach($name in @('Hash-Bytes','Read-LockedBytes','Local-OnlyProbe','Capture-Counter','Bash-Path','Config-Directory','Assert-ConfigMetadata')){
    $guard=$ast.Find({param($node)$node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name},$true)
    . ([scriptblock]::Create($guard.Extent.Text))
}
$guard=$ast.Find({param($node)$node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Assert-CounterContext'},$true)
. ([scriptblock]::Create($guard.Extent.Text))
$guard=$ast.Find({param($node)$node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Test-ObserverEvent'},$true)
. ([scriptblock]::Create($guard.Extent.Text))
$root=$null
$fixtureParentPins=[Collections.Generic.List[Microsoft.Win32.SafeHandles.SafeFileHandle]]::new()
# Synthetic config fixtures need the same trusted ancestry their guard tests.
# Runner TEMP/profile ancestry can legitimately be foreign-writable for a
# service account. Verify and pin existing standard parents; never repair them.
# The final local-volume candidate uses only existing create-new-folder rights.
$candidates=@([Environment]::GetFolderPath('UserProfile'),(Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Temp'),'C:\')
foreach($candidate in $candidates){
    if(-not $candidate){continue}
    $pins=[Collections.Generic.List[Microsoft.Win32.SafeHandles.SafeFileHandle]]::new()
    try{
        $parent=[IO.DirectoryInfo]::new($candidate)
        if(-not $parent.Exists){throw 'Existing fixture parent required'}
        if($parent.Parent -eq $null -and [IO.DriveInfo]::new($parent.FullName).DriveType -ne [IO.DriveType]::Fixed){throw 'Local fixed volume required'}
        $ancestors=@();$cursor=$parent
        while($null -ne $cursor){$ancestors+=$cursor;$cursor=$cursor.Parent}
        foreach($ancestor in ($ancestors|Sort-Object {$_.FullName.Length})){
            $pin=[GenerationCustody]::Metadata($ancestor.FullName,$true)
            if($null -eq $pin){throw 'Fixture ancestor unavailable'}
            try{[GenerationCustody]::AssertProtectedParent($pin,($null -eq $ancestor.Parent));$pins.Add($pin)}
            catch{$pin.Dispose();throw}
        }
    }catch{foreach($pin in $pins){$pin.Dispose()};continue}
    $root=Join-Path $parent.FullName ('ai-gh-generation-test-'+[Guid]::NewGuid().ToString('N'))
    try{[GenerationCustody]::PrivateDirectory($root)}
    catch{foreach($pin in $pins){$pin.Dispose()};throw}
    $fixtureParentPins=$pins
    break
}
if(-not $root){throw 'No verified existing fixture parent; no permissions changed'}
foreach($name in @('Invoke-OwnedCleanupStep','Close-OwnedGeneration')){
    $cleanupAst=$ast.Find({param($node)$node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name},$true)
    if($null -eq $cleanupAst){throw 'Owned cleanup function missing'}
    . ([scriptblock]::Create($cleanupAst.Extent.Text))
}
$passed=0
function Assert([bool]$Condition,[string]$Name){if(-not $Condition){throw $Name};$script:passed++}
function Refuses([scriptblock]$Operation,[string]$Name){$refused=$false;try{& $Operation}catch{$refused=$true};Assert $refused $Name}
function Get-FixtureDacl([string]$Path,[bool]$Directory){
    $sddl=(Get-Acl -LiteralPath $Path).GetSecurityDescriptorSddlForm([Security.AccessControl.AccessControlSections]::Access)
    $acl=if($Directory){[Security.AccessControl.DirectorySecurity]::new()}else{[Security.AccessControl.FileSecurity]::new()}
    $acl.SetSecurityDescriptorSddlForm($sddl,[Security.AccessControl.AccessControlSections]::Access)
    return $acl
}
function Set-FixtureDirectoryDacl([string]$Path,[Security.AccessControl.DirectorySecurity]$Acl){
    # Only the two fresh PrivateDirectory negative fixtures call this helper.
    # Retain no-follow control and identity pins; never request owner/group/SACL.
    $pin=[GenerationCustody]::Hold($Path,$true,$false)
    $control=$null
    try{
        $control=[GenerationCustody]::DirectoryControl($Path)
        Assert ([GenerationCustody]::Same($pin,$control)) 'Owned DACL control binds its pinned directory'
        [FixtureDacl]::Apply($control,$Acl.GetSecurityDescriptorBinaryForm())
    }finally{if($null -ne $control){$control.Dispose()};$pin.Dispose()}
}
$file=Join-Path $root 'sealed.sh'
$ordinary=Join-Path $root 'canonical.sh'
[IO.File]::WriteAllText($file,'sealed bytes')
[IO.File]::WriteAllText($ordinary,'canonical bytes')
$directory=[GenerationCustody]::Hold($root,$true,$false)
$held=[GenerationCustody]::Hold($file,$false,$true)
$primaryFailure=$null
$cleanupFailure=$null
$fileControls=[Collections.Generic.List[Microsoft.Win32.SafeHandles.SafeFileHandle]]::new()
$control=$null
try {
    Refuses { [IO.File]::WriteAllText($file,'altered') } 'Held source must reject writes'
    Refuses { [IO.File]::Move($file,(Join-Path $root 'renamed.sh')) } 'Held source must reject rename'
    Refuses { [IO.File]::Delete($file) } 'Held source must reject delete'
    Refuses { [IO.Directory]::Move($root,($root+'-renamed')) } 'Held ancestor must reject rename'
    [IO.File]::WriteAllText($ordinary,'canonical still writable')
    Assert (([IO.File]::ReadAllText($ordinary)) -eq 'canonical still writable') 'Canonical remains writable'
    Assert (([IO.File]::ReadAllText($file)) -eq 'sealed bytes') 'Held source remains readable'
    $again=[GenerationCustody]::Hold($file,$false,$true)
    try { Assert ([GenerationCustody]::Same($held,$again)) 'Identity binds same bytes' } finally { $again.Dispose() }
    $other=[GenerationCustody]::Hold($ordinary,$false,$true)
    try { Assert (-not [GenerationCustody]::Same($held,$other)) 'Different identity refuses' } finally { $other.Dispose() }
    Assert ([GenerationCustody]::Quote('') -eq '""') 'Empty argument preserved'
    Assert ([GenerationCustody]::Quote('plain') -eq 'plain') 'Plain argument preserved'
    Assert ([GenerationCustody]::Quote('two words') -eq '"two words"') 'Spaced argument preserved'
    Assert ([GenerationCustody]::Quote('a"b') -eq '"a\"b"') 'Quote argument preserved'
    $injected=Join-Path $root 'unexpected_module.py'
    [IO.File]::WriteAllText($injected,'unexpected module')
    Refuses {[GenerationCustody]::AssertClosure($root,@('sealed.sh','canonical.sh'))} 'Pre-seal helper insertion refuses qualification'
    [IO.File]::Delete($injected)
    [GenerationCustody]::AssertClosure($root,@('sealed.sh','canonical.sh'))
    $attack=Join-Path $root 'attack.ps1'
    [IO.File]::WriteAllText($attack,@'
$ErrorActionPreference='Stop'
$root=$args[0]
if([Security.Principal.WindowsIdentity]::GetCurrent().User.Value -ne $args[1]){exit 10}
Add-Type -TypeDefinition 'using System;using System.Runtime.InteropServices;public static class ParentIsolationProbe{[DllImport("kernel32.dll")]public static extern IntPtr OpenProcess(uint access,bool inherit,int pid);[DllImport("kernel32.dll")]public static extern bool CloseHandle(IntPtr handle);[DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)]public static extern IntPtr CreateFileW(string path,uint access,uint share,IntPtr attributes,uint disposition,uint flags,IntPtr template);}'
$parentHandle=[ParentIsolationProbe]::OpenProcess(0x68,$false,[int]$args[2])
if($parentHandle -ne [IntPtr]::Zero){[ParentIsolationProbe]::CloseHandle($parentHandle)|Out-Null;if($args[3] -eq '1'){exit 16}}
try{[IO.File]::WriteAllText((Join-Path $root 'unexpected_module.py'),'attack');exit 11}catch{}
try{[IO.Directory]::CreateDirectory((Join-Path $root 'newmodule'))|Out-Null;exit 12}catch{}
$dac=[ParentIsolationProbe]::CreateFileW($root,0x40000,7,[IntPtr]::Zero,3,0x02200000,[IntPtr]::Zero)
if($dac -ne [IntPtr]::new(-1)){[ParentIsolationProbe]::CloseHandle($dac)|Out-Null;exit 13}
if([Runtime.InteropServices.Marshal]::GetLastWin32Error() -ne 5){exit 18}
$dac=[ParentIsolationProbe]::CreateFileW((Join-Path $root 'sealed.sh'),0x40000,7,[IntPtr]::Zero,3,0x02200000,[IntPtr]::Zero)
if($dac -ne [IntPtr]::new(-1)){[ParentIsolationProbe]::CloseHandle($dac)|Out-Null;exit 17}
if([Runtime.InteropServices.Marshal]::GetLastWin32Error() -ne 5){exit 19}
try{[IO.File]::WriteAllText((Join-Path $root 'sealed.sh'),'attack');exit 14}catch{}
if([IO.File]::ReadAllText((Join-Path $root 'sealed.sh')) -ne 'sealed bytes'){exit 15}
exit 0
'@)
    $attackHold=$null
    $control=[GenerationCustody]::DirectoryControl($root)
    $sealedFailure=$null
    try {
        foreach($path in @($file,$ordinary,$attack)){$fileControls.Add([GenerationCustody]::FileControl($path))}
        Assert ([GenerationCustody]::Same($held,$fileControls[0])) 'File cleanup control binds the held source identity'
        $attackHold=[GenerationCustody]::Hold($attack,$false,$true)
        Assert ([GenerationCustody]::Same($attackHold,$fileControls[2])) 'Attack helper control binds its held identity'
        foreach($fileControl in $fileControls){[GenerationCustody]::FileAccess($fileControl,$false)}
        [GenerationCustody]::DirectoryAccess($control,$false)
        $beforePrivileges=[GenerationCustody]::PrivilegedContext()
        $beforePrivilegeState=[GenerationCustody]::PrivilegeState()
        Assert ([GenerationCustody]::DisabledBypassStillDetected()) 'Present disabled bypass privileges remain unqualified'
        $job=[GenerationCustody]::Job()
        $executable=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        # Only this owned test child uses a process-scoped script policy. The
        # restricted token and sealed source/ACL attack checks stay unchanged.
        $arguments='-NoProfile -NonInteractive -ExecutionPolicy Bypass -File '+[GenerationCustody]::Quote($attack)+' '+[GenerationCustody]::Quote($root)+' '+$sid+' '+$PID+' '+[int]$beforePrivileges
        $process=$null
        try {
            $process=[GenerationCustody]::Start($job,$executable,$arguments,$root,$true)
            Assert ($process.WaitForExit(30000)) 'Restricted attack child must terminate within its deadline'
            Assert ($process.ExitCode -eq 0) ('Restricted child helper/ACL attacks denied; exit='+$process.ExitCode)
        } finally {try {$job.Dispose()} finally {if($null -ne $process){$process.Dispose()}}}
        $job=[GenerationCustody]::Job()
        $process=$null
        try {
            $process=[GenerationCustody]::Start($job,$executable,'-NoProfile -Command "Start-Sleep -Seconds 30"',$root,$true)
            $job.Dispose();Assert ($process.WaitForExit(10000)) 'Restricted cancellation returns to parent cleanup'
        } finally {try {$job.Dispose()} finally {if($null -ne $process){$process.Dispose()}}}
        Assert ([GenerationCustody]::PrivilegedContext() -eq $beforePrivileges) 'Parent privileges remain unchanged'
        Assert ([GenerationCustody]::PrivilegeState() -eq $beforePrivilegeState) 'Parent privilege attributes remain unchanged'
        Assert (([IO.File]::ReadAllText($file)) -eq 'sealed bytes') 'Sealed directory remains readable'
    } catch {$sealedFailure=$_}
    finally {
        $sealedCleanup=Close-OwnedGeneration @{DirectoryControls=@($control);FileControls=$fileControls;
            Locks=@($attackHold);CaptureLocks=@();Job=$null;Child=$null;EventChannel=$null;CounterChannel=$null;
            Receipt=$null;Ack=$null;Snapshot=$null;Bootstrap=$null}
    }
    if($sealedFailure -or $sealedCleanup.Count){
        $exceptions=@();if($sealedFailure){$exceptions+=$sealedFailure.Exception}
        $exceptions+=@($sealedCleanup|ForEach-Object{$_.error.Exception})
        throw [AggregateException]::new('Restricted fixture or explicit file restoration failed',[Exception[]]$exceptions)
    }
    [IO.File]::WriteAllText($injected,'parent restoration works')
    Assert ([IO.File]::Exists($injected)) 'Retained parent control restores cleanup access'
    [IO.File]::Delete($injected)
    $faultRoot=Join-Path $root 'cleanup-fault'
    $firstDirectory=Join-Path $faultRoot 'first';$secondDirectory=Join-Path $faultRoot 'second'
    [GenerationCustody]::PrivateDirectory($faultRoot)
    [GenerationCustody]::PrivateDirectory($firstDirectory);[GenerationCustody]::PrivateDirectory($secondDirectory)
    $ownedFile=Join-Path $secondDirectory 'owned-file'
    [IO.File]::WriteAllText($ownedFile,'owned cleanup fixture')
    $invalidFile=Join-Path $firstDirectory 'owned-file'
    [IO.File]::WriteAllText($invalidFile,'owned cleanup fixture')
    $invalidFileControl=[GenerationCustody]::FileControl($invalidFile);$invalidFileControl.Dispose()
    $laterFileControl=[GenerationCustody]::FileControl($ownedFile)
    [GenerationCustody]::FileAccess($laterFileControl,$false)
    $invalidControl=[GenerationCustody]::DirectoryControl($firstDirectory);$invalidControl.Dispose()
    $laterControl=[GenerationCustody]::DirectoryControl($secondDirectory)
    [GenerationCustody]::DirectoryAccess($laterControl,$false)
    $throwing=[pscustomobject]@{}
    $throwing|Add-Member ScriptMethod Dispose {throw 'Expected first capture cleanup failure'}
    $recording=[pscustomobject]@{Count=0}
    $recording|Add-Member ScriptMethod Dispose {$this.Count++}
    $cleanupBootstrap=Join-Path $root 'cleanup-bootstrap'
    [GenerationCustody]::PrivateDirectory($cleanupBootstrap)
    $cleanupFailures=Close-OwnedGeneration @{Job=$recording;Child=$null;EventChannel=$recording;CounterChannel=$recording;
        CaptureLocks=@($throwing,$recording);DirectoryControls=@($invalidControl,$laterControl);
        FileControls=@($invalidFileControl,$laterFileControl);Locks=@($recording);
        Receipt=$recording;Ack=$recording;Snapshot=$faultRoot;Bootstrap=$cleanupBootstrap}
    if($cleanupFailures.Count -ne 3){
        foreach($failure in $cleanupFailures){[Console]::Error.WriteLine(('OWNED_CLEANUP_PHASE '+$failure.phase+' '+$failure.error.Exception.GetType().Name+' '+$failure.error.Exception.HResult))}
    }
    Assert ($cleanupFailures.Count -eq 3) 'Every injected cleanup failure remains visible'
    Assert (@($cleanupFailures|Where-Object {$_.phase -eq 'directory_unseal'}).Count -eq 1) 'First failed native unseal is retained'
    Assert (@($cleanupFailures|Where-Object {$_.phase -eq 'capture_handle'}).Count -eq 1) 'First failed capture disposal is retained'
    Assert (@($cleanupFailures|Where-Object {$_.phase -eq 'file_unseal'}).Count -eq 1) 'First failed file unseal is retained'
    Assert ($laterControl.IsClosed -and $laterFileControl.IsClosed -and $recording.Count -eq 7) 'Later controls, custody, receipt and ACK still close'
    Assert (-not (Test-Path -LiteralPath $faultRoot) -and -not (Test-Path -LiteralPath $cleanupBootstrap)) 'Later native unseal permits actual owned directory cleanup'
    Assert-ReadArguments 'bin/ai-pr-wait' @('658','--repo','popcre/ai-devops','--timeout-minutes','1')
    Assert-ReadArguments 'bin/ai-gh' @('issue','view','658','--repo','popcre/ai-devops','--json','number,state,title')
    Assert $true 'Finite public read arguments accepted'
    Refuses {Assert-ReadArguments 'bin/ai-gh' @('issue','close','658','--repo','popcre/ai-devops','--json','number')} 'Write command denied by explicit read profile'
    Refuses {Assert-ReadArguments 'bin/ai-gh' @('--version')} 'Local version fixture does not authorize managed admission'
    Refuses {Assert-ReadArguments 'bin/ai-pr-wait' @('658','--repo','other/private')} 'Other repository denied by explicit read profile'
    Refuses {Assert-ReadArguments 'bin/ai-pr-wait' @('658','--repo','popcre/ai-devops','--reviewer-approval','unbound-file')} 'Unbound helper argument denied by read profile'
    $wireProbe=Join-Path $root 'wire_probe.py'
    [IO.File]::WriteAllText($wireProbe,@'
import ctypes,importlib.util,msvcrt,os,subprocess,sys,tempfile,time
s=importlib.util.spec_from_file_location('wire',sys.argv[1]);m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
h=int(os.environ['AI_GH_QUALIFICATION_EVENT_HANDLE']);mode=sys.argv[2];start=time.monotonic()
if mode=='watchdog':
 for i in range(128):
  if not m._write_once(h,b'x'*4096):break
 k=m._kernel();k.SetNamedPipeHandleState.argtypes=[ctypes.c_void_p,ctypes.POINTER(ctypes.c_ulong),ctypes.c_void_p,ctypes.c_void_p]
 state=ctypes.c_ulong(0)
 if not k.SetNamedPipeHandleState(h,ctypes.byref(state),None,None):raise SystemExit(30)
 # ONLY this fresh test pipe is changed. The disposable helper below sees a
 # raced false NOWAIT report and must self-expire rather than block its caller.
 p=subprocess.Popen([sys.executable,'-I',__file__,sys.argv[1],'blockedwriter'],stdin=subprocess.PIPE,close_fds=False)
 p.communicate(b'x'*4096,timeout=2)
 if p.returncode!=2 or time.monotonic()-start>2.5:raise SystemExit(31)
elif mode=='blockedwriter':
 actual=m._kernel()
 class Raced:
  def GetNamedPipeHandleStateW(self,handle,state,*rest):
   ctypes.cast(state,ctypes.POINTER(ctypes.c_ulong))[0]=1;return 1
  def __getattr__(self,name):return getattr(actual,name)
 m._kernel=lambda:Raced();sys.argv=[sys.argv[1],'--write-once'];raise SystemExit(m.main())
elif mode=='invalid':
 with tempfile.TemporaryFile(dir=os.getcwd()) as f:
  f.write(b'unchanged');f.flush()
  if m._write_once(msvcrt.get_osfhandle(f.fileno()),b'altered'):raise SystemExit(32)
  f.seek(0)
  if f.read()!=b'unchanged':raise SystemExit(33)
elif mode=='closed':
 k=m._kernel();k.CloseHandle(h)
 if m._write_once(h,b'x'):raise SystemExit(34)
elif mode=='full':
 for i in range(128):
  if not m._write_once(h,b'x'*4096):break
 else:raise SystemExit(21)
 if time.monotonic()-start>1:raise SystemExit(22)
elif mode=='counter':
 for value in (b'{"schema":1,"started":true}\n',b'{"schema":1,"finished":true}\n'):
  if not m._write_once(h,value):raise SystemExit(35)
elif mode=='duplicate':
 if not m._write_once(h,b'{}') or not m._write_once(h,b'{}'):raise SystemExit(24)
elif mode=='malformed':
 if not m._write_once(h,b'\xff'):raise SystemExit(25)
else:
 if not m._write_once(h,b'{"native_chain":"ok"}'):raise SystemExit(26)
'@)
    $wireShell=Join-Path $root 'wire_probe.sh'
    [IO.File]::WriteAllText($wireShell,"exec `"`$1`" `"`$2`" `"`$3`" `"`$4`"`n")
    $bash=Join-Path $env:ProgramFiles 'Git\bin\bash.exe'
    $python=(Get-Command python.exe -ErrorAction Stop).Source
    function Posix([string]$p){return '/'+$p.Substring(0,1)+'/'+$p.Substring(3).Replace('\','/')}
    foreach($mode in @('basic','full','duplicate','malformed','invalid','closed','watchdog','counter')){
        $channel=if($mode -eq 'counter'){[GenerationCustody+EventChannel]::new(128)}else{[GenerationCustody+EventChannel]::new()};$job=[GenerationCustody]::Job()
        $saved=[Environment]::GetEnvironmentVariable('AI_GH_QUALIFICATION_EVENT_HANDLE','Process')
        try{
            [Environment]::SetEnvironmentVariable('AI_GH_QUALIFICATION_EVENT_HANDLE',[string]$channel.WriteHandle,'Process')
            $args=@((Posix $wireShell),(Posix $python),(Posix $wireProbe),(Posix $EventHelper),$mode)
            $command=($args|ForEach-Object{[GenerationCustody]::Quote($_)}) -join ' '
            $process=[GenerationCustody]::Start($job,$bash,$command,$root,$true)
            try{Assert ($process.WaitForExit(5000)) 'Native event write is bounded';Assert ($process.ExitCode -eq 0) ('Git Bash/native Python event pipe '+$mode+' exit='+$process.ExitCode)}finally{$process.Dispose()}
            if($mode -eq 'basic'){Assert ($channel.EventText() -eq '{"native_chain":"ok"}') 'Raw handle survives actual Bash/native Python chain'}
            elseif($mode -eq 'counter'){Assert ($channel.CounterText() -ceq "{`"schema`":1,`"started`":true}`n{`"schema`":1,`"finished`":true}`n") 'Separate numeric pipe retains sequential complete messages'}
            elseif($mode -eq 'duplicate' -or $mode -eq 'malformed'){Assert ($null -eq $channel.EventText() -and $channel.Status -eq 'invalid') 'Duplicate or malformed event stays unknown'}
        }finally{[Environment]::SetEnvironmentVariable('AI_GH_QUALIFICATION_EVENT_HANDLE',$saved,'Process');$job.Dispose();$channel.Dispose()}
    }
    foreach($key in @('AI_GH_REAL_GH','GH_PATH','GH_DEBUG','GH_PAGER','AI_GH_HTTP_COUNTER_HANDLE','AI_GH_HTTP_COUNTER_FD','MSYS2_ARG_CONV_EXCL')){
        $saved=[Environment]::GetEnvironmentVariable($key,'Process')
        try{[Environment]::SetEnvironmentVariable($key,'unsupported-test-context','Process');Refuses {Assert-CounterContext} ('Ambient counter context refused: '+$key);Assert ([Environment]::GetEnvironmentVariable($key,'Process') -ceq 'unsupported-test-context') 'Counter guard preserves original environment'}finally{[Environment]::SetEnvironmentVariable($key,$saved,'Process')}
    }
    $savedConfigEnvironment=@{}
    foreach($key in @('GH_CONFIG_DIR','XDG_CONFIG_HOME','APPDATA','USERPROFILE','GH_TOKEN','GITHUB_TOKEN','SSH_CONNECTION')){$savedConfigEnvironment[$key]=[Environment]::GetEnvironmentVariable($key,'Process')}
    $savedConfigLocks=$script:locks;$script:locks=[Collections.Generic.List[IDisposable]]::new()
    try{
        foreach($key in $savedConfigEnvironment.Keys){[Environment]::SetEnvironmentVariable($key,$null,'Process')}
        $config=Join-Path $root 'metadata-config';[GenerationCustody]::PrivateDirectory($config)
        $env:USERPROFILE=$root
        Assert ((Config-Directory) -ceq (Join-Path $root '.config\gh')) 'Pinned Windows default uses USERPROFILE'
        $env:APPDATA=$root
        Assert ((Config-Directory) -ceq (Join-Path $root 'GitHub CLI')) 'Pinned Windows APPDATA precedence'
        $env:XDG_CONFIG_HOME=$root
        Assert ((Config-Directory) -ceq (Join-Path $root 'gh')) 'Pinned XDG precedence'
        $env:GH_CONFIG_DIR=$config
        Assert ((Config-Directory) -ceq $config) 'Explicit original config precedence'
        Refuses {Assert-ConfigMetadata} 'Missing auth config without original token refuses'
        [IO.File]::WriteAllText((Join-Path $config 'hosts.yml'),'owned synthetic fixture, not credentials')
        Assert-ConfigMetadata;Assert $true 'Safe metadata-only configuration admitted'
        $meta=[GenerationCustody]::Metadata((Join-Path $config 'hosts.yml'),$false)
        try{Refuses {[GenerationCustody]::Read($meta)} 'Metadata handle cannot read credential bytes'}finally{$meta.Dispose()}
        foreach($lock in $script:locks){$lock.Dispose()};$script:locks.Clear()
        $hostFile=Join-Path $config 'hosts.yml';$originalAcl=(Get-Acl -LiteralPath $hostFile).GetSecurityDescriptorSddlForm([Security.AccessControl.AccessControlSections]::Access)
        $acl=Get-FixtureDacl $hostFile $false
        $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new('S-1-5-32-545'),[Security.AccessControl.FileSystemRights]::Write,[Security.AccessControl.AccessControlType]::Allow))
        Set-Acl -LiteralPath $hostFile -AclObject $acl
        Refuses {Assert-ConfigMetadata} 'Foreign-writable config file refused'
        foreach($lock in $script:locks){$lock.Dispose()};$script:locks.Clear()
        $acl=[Security.AccessControl.FileSecurity]::new();$acl.SetSecurityDescriptorSddlForm($originalAcl,[Security.AccessControl.AccessControlSections]::Access);Set-Acl -LiteralPath $hostFile -AclObject $acl
        $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new('S-1-1-0'),[Security.AccessControl.FileSystemRights]::ReadData,[Security.AccessControl.AccessControlType]::Allow))
        Set-Acl -LiteralPath $hostFile -AclObject $acl
        Refuses {Assert-ConfigMetadata} 'Foreign credential file reader refused without reading bytes'
        foreach($lock in $script:locks){$lock.Dispose()};$script:locks.Clear()
        $acl=[Security.AccessControl.FileSecurity]::new();$acl.SetSecurityDescriptorSddlForm($originalAcl,[Security.AccessControl.AccessControlSections]::Access);Set-Acl -LiteralPath $hostFile -AclObject $acl
        $unsafe=Join-Path $root 'metadata-unsafe';[GenerationCustody]::PrivateDirectory($unsafe)
        $acl=Get-FixtureDacl $unsafe $true
        $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new('S-1-5-32-545'),[Security.AccessControl.FileSystemRights]::Modify,[Security.AccessControl.AccessControlType]::Allow))
        Set-FixtureDirectoryDacl $unsafe $acl;$env:GH_CONFIG_DIR=$unsafe
        Refuses {Assert-ConfigMetadata} 'Foreign-writable config namespace refused'
        foreach($lock in $script:locks){$lock.Dispose()};$script:locks.Clear()
        $env:GH_CONFIG_DIR=$config
        $alias=Join-Path $config 'config.yml'
        New-Item -ItemType HardLink -Path $alias -Value (Join-Path $config 'hosts.yml') -ErrorAction Stop|Out-Null
        Refuses {Assert-ConfigMetadata} 'Config file alias refused without reading'
        foreach($lock in $script:locks){$lock.Dispose()};$script:locks.Clear();Remove-Item -LiteralPath $alias
        $junction=Join-Path $root 'metadata-junction';New-Item -ItemType Junction -Path $junction -Target $config|Out-Null;$env:GH_CONFIG_DIR=$junction
        Refuses {Assert-ConfigMetadata} 'Config directory alias refused'
        foreach($lock in $script:locks){$lock.Dispose()};$script:locks.Clear();[IO.Directory]::Delete($junction)
        $env:GH_CONFIG_DIR=Join-Path $root 'metadata-missing'
        Refuses {Assert-ConfigMetadata} 'Missing directory cannot invent authentication'
        foreach($lock in $script:locks){$lock.Dispose()};$script:locks.Clear()
        $env:GH_TOKEN='owned-test-presence-only'
        Assert-ConfigMetadata;Assert $true 'Missing config only admitted with existing token presence'
        foreach($lock in $script:locks){$lock.Dispose()};$script:locks.Clear()
    }finally{
        foreach($lock in $script:locks){$lock.Dispose()};$script:locks=$savedConfigLocks
        foreach($key in $savedConfigEnvironment.Keys){[Environment]::SetEnvironmentVariable($key,$savedConfigEnvironment[$key],'Process')}
    }
    if($CounterManifest){
        # Optional owned native integration: direct local --version only. Never
        # enter ai-gh admission here: even --version can refresh its quota.
        $script:locks=[Collections.Generic.List[IDisposable]]::new()
        $script:installedBash=$bash
        $capsule=Join-Path $root 'counter-capsule'
        [GenerationCustody]::PrivateDirectory($capsule)
        $capsuleHold=[GenerationCustody]::Hold($capsule,$true,$false)
        $capsuleControl=[GenerationCustody]::DirectoryControl($capsule)
        $channel=[GenerationCustody+EventChannel]::new(128);$job=[GenerationCustody]::Job();$imageHold=$null
        $savedHandle=$env:AI_GH_HTTP_COUNTER_HANDLE;$savedHost=$env:AI_GH_HTTP_COUNTER_HOST
        try{
            Refuses {Capture-Counter $CounterManifest ('0'*64)} 'Wrong approved manifest refused before image execution'
            $captured=Capture-Counter $CounterManifest $ExpectedCounterManifestSha256
            # Metadata attacks use a fresh private copy, never the approved
            # frozen source/image. Every case must fail before any execution.
            $negative=Join-Path $root 'counter-negative';[GenerationCustody]::PrivateDirectory($negative)
            $negativeSource=Join-Path $negative 'source';[void][IO.Directory]::CreateDirectory($negativeSource)
            $originalStage=Split-Path $CounterManifest -Parent
            foreach($sourceFile in (Get-ChildItem -LiteralPath (Join-Path $originalStage 'source') -File)){
                [IO.File]::WriteAllBytes((Join-Path $negativeSource $sourceFile.Name),[IO.File]::ReadAllBytes($sourceFile.FullName))
            }
            [IO.File]::WriteAllBytes((Join-Path $negative 'gh-instrumented.exe'),$captured.bytes)
            foreach($attackCase in @('target','installed','version','compiled-binding','extra-helper')){
                $metadata=[IO.File]::ReadAllText($CounterManifest)|ConvertFrom-Json
                switch($attackCase){
                    target {$metadata.target='linux-amd64'}
                    installed {$metadata.installed=$true}
                    version {$metadata.pins.upstream_version='2.101.0'}
                    compiled-binding {$metadata.compiled_counter_source_binding.files.'channel_windows.go'='0'*64}
                    extra-helper {[IO.File]::WriteAllText((Join-Path $negativeSource 'unexpected.go'),'not approved')}
                }
                $negativeManifest=Join-Path $negative 'build.json'
                [IO.File]::WriteAllText($negativeManifest,($metadata|ConvertTo-Json -Depth 20 -Compress),[Text.UTF8Encoding]::new($false))
                $savedLocks=$script:locks;$script:locks=[Collections.Generic.List[IDisposable]]::new()
                try{Refuses {Capture-Counter $negativeManifest (Hash-Bytes ([IO.File]::ReadAllBytes($negativeManifest)))} ('Counter metadata/helper attack refused: '+$attackCase)}finally{foreach($lock in $script:locks){$lock.Dispose()};$script:locks=$savedLocks}
            }
            Remove-Item -LiteralPath $negative -Recurse -Force
            $image=Join-Path $capsule 'counter.exe';[IO.File]::WriteAllBytes($image,$captured.bytes)
            $imageHold=[GenerationCustody]::Hold($image,$false,$true)
            [GenerationCustody]::DirectoryAccess($capsuleControl,$false)
            [GenerationCustody]::AssertClosure($capsule,@('counter.exe'))
            Refuses {[IO.File]::WriteAllBytes($image,[byte[]]@(0))} 'Held copied counter image mutation refused'
            $env:AI_GH_HTTP_COUNTER_HANDLE=[string]$channel.WriteHandle;$env:AI_GH_HTTP_COUNTER_HOST='api.github.com'
            $command=(@('-c','exec "$1" --version','owned-counter-fixture',(Bash-Path $image))|ForEach-Object{[GenerationCustody]::Quote($_)}) -join ' '
            $process=[GenerationCustody]::Start($job,$bash,$command,$root,$true,$true)
            try{Assert ($process.WaitForExit(5000)) 'Native instrumented local version is bounded';Assert ($process.ExitCode -eq 0) 'Native local version preserves original success'}finally{$process.Dispose()}
            $wire=$channel.CounterText();$rows=@($wire -split "`n"|Where-Object{$_}|ForEach-Object{$_|ConvertFrom-Json})
            Assert ($rows.Count -eq 2 -and $rows[0].started -eq $true -and $rows[1].finished -eq $true) 'Actual Bash to native counter handle retains complete invocation'
            Assert ($rows[1].observed_completed_writes -eq 0 -and $rows[1].failed_write_attempts -eq 0 -and $rows[1].observed_external_writes -eq 0 -and $rows[1].incomplete -eq $false -and $null -eq $rows[1].http_requests) 'Direct local native version emits complete zero writes without global HTTP claim'
        }finally{
            $env:AI_GH_HTTP_COUNTER_HANDLE=$savedHandle;$env:AI_GH_HTTP_COUNTER_HOST=$savedHost;$job.Dispose();$channel.Dispose()
            try{[GenerationCustody]::DirectoryAccess($capsuleControl,$true)}finally{$capsuleControl.Dispose();if($imageHold){$imageHold.Dispose()};$capsuleHold.Dispose();foreach($lock in $script:locks){$lock.Dispose()};Remove-Item -LiteralPath $capsule -Recurse -Force}
        }
    }
    $fixture=@{schema=4;utc='2026-10-31T00:00:00Z';measurement='workflow_evidence';caller='ai-pr-wait';workflow='pr_wait';workflow_id=('a'*32);cohort_id=$null;target_ordinal=$null;source_verified='unknown';source_fingerprint_start=$null;source_fingerprint_end=$null;install_generation_binding=$null;event_kind='pr_merged';eligible_utc_ms=1750000000000L;observed_utc_ms=1750000001000L;delivered_utc_ms=1750000001000L;delivery_boundary='terminal_report';clock_quality='unknown';clock_error_bound_ms=$null;latency_ms=$null;unknown_reason='source_unknown'}
    $json=$fixture|ConvertTo-Json -Compress
    Assert (Test-ObserverEvent $json) 'Exact unqualified event schema accepted'
    foreach($value in @('4.0','"4"','true')){
        Assert (-not (Test-ObserverEvent ($json.Replace('"schema":4',('"schema":'+$value))))) 'Noninteger JSON schema stays refused'
    }
    Assert (-not (Test-ObserverEvent ($json.Replace('2026-10-31T00:00:00Z','2026-10-31T00:00:00+00:00')))) 'Noncanonical UTC string stays refused'
    Assert (-not (Test-ObserverEvent ($json -replace '"schema":4','"schema":4,"schema":4'))) 'Duplicate JSON event keys refused'
    $fixture.source_verified='verified'
    Assert (-not (Test-ObserverEvent ($fixture|ConvertTo-Json -Compress))) 'Child source claim refused'
    Assert (-not (Test-ObserverEvent ('x'*4097))) 'Oversized event refused'
    $unsafeParent=Join-Path $root 'unsafe-parent'
    [GenerationCustody]::PrivateDirectory($unsafeParent)
    $parentHandle=[GenerationCustody]::Hold($unsafeParent,$true,$false)
    try{
        [GenerationCustody]::AssertProtectedParent($parentHandle,$false)
        $a=Get-FixtureDacl $unsafeParent $true
        $a.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new('S-1-1-0'),'Modify','None','None','Allow'))
        Set-FixtureDirectoryDacl $unsafeParent $a
        $candidate=Join-Path $unsafeParent 'candidate'
        Refuses {[GenerationCustody]::AssertProtectedParent($parentHandle,$false);[GenerationCustody]::PrivateDirectory($candidate)} 'Unsafe parent refused BEFORE snapshot creation'
        Assert (-not [IO.Directory]::Exists($candidate)) 'Unsafe namespace never materialized'
        # Demonstrate the pre-lock replacement the parent check prevents;
        # every fixture object is fresh and owned, no foreign ACL is repaired.
        [GenerationCustody]::PrivateDirectory($candidate)
        $replacement=Join-Path $unsafeParent 'replacement'
        [GenerationCustody]::PrivateDirectory($replacement)
        [IO.Directory]::Move($candidate,($candidate+'-original'))
        [IO.Directory]::Move($replacement,$candidate)
        Refuses {[GenerationCustody]::AssertProtectedParent($parentHandle,$false)} 'Pre-seal replacement cannot acquire qualified custody'
    }finally{$parentHandle.Dispose()}
    $powershell=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $job=[GenerationCustody]::Job()
    $process=$null
    try {
        $process=[GenerationCustody]::Start($job,$powershell,'-NoProfile -Command "exit 17"',$root)
        Assert ($process.WaitForExit(30000)) 'Ordinary child must terminate within its deadline'
        Assert ($process.ExitCode -eq 17) 'Original child exit preserved'
    } finally {try {$job.Dispose()} finally {if($null -ne $process){$process.Dispose()}}}
    $job=[GenerationCustody]::Job()
    $process=$null
    try {
        $process=[GenerationCustody]::Start($job,$powershell,'-NoProfile -Command "Start-Sleep -Seconds 30"',$root)
        $job.Dispose();Assert ($process.WaitForExit(10000)) 'Cancellation closes child job'
    } finally {try {$job.Dispose()} finally {if($null -ne $process){$process.Dispose()}}}
    $junction=Join-Path $root 'junction'
    New-Item -ItemType Junction -Path $junction -Target $root | Out-Null
    try { Refuses {$h=[GenerationCustody]::Hold($junction,$true,$false);$h.Dispose()} 'Reparse directory refuses' } finally {[IO.Directory]::Delete($junction)}
    $link=Join-Path $root 'hardlink.sh'
    New-Item -ItemType HardLink -Path $link -Value $file -ErrorAction Stop | Out-Null
    Refuses { $h=[GenerationCustody]::Hold($link,$false,$true);$h.Dispose() } 'Hardlinked source refuses'
    Remove-Item -LiteralPath $link
} catch { $primaryFailure=$_ }
finally {
    try {
        $remainingFiles=@($fileControls|Where-Object{-not $_.IsClosed})
        $remainingDirectories=@();if($control -and -not $control.IsClosed){$remainingDirectories=@($control)}
        $outerCleanup=Close-OwnedGeneration @{DirectoryControls=$remainingDirectories;FileControls=$remainingFiles;
            Locks=(@($fixtureParentPins.ToArray())+@($directory,$held));CaptureLocks=@();Job=$null;Child=$null;EventChannel=$null;CounterChannel=$null;
            Receipt=$null;Ack=$null;Snapshot=$root;Bootstrap=$null}
        if($outerCleanup.Count){throw [AggregateException]::new('Owned fixture cleanup failed',[Exception[]]@($outerCleanup|ForEach-Object{$_.error.Exception}))}
    } catch { $cleanupFailure=$_ }
}
if($null -ne $primaryFailure){
    if($null -ne $cleanupFailure){
        throw [AggregateException]::new('Native source fixture and cleanup both failed',
            [Exception[]]@($primaryFailure.Exception,$cleanupFailure.Exception))
    }
    throw $primaryFailure
}
if($null -ne $cleanupFailure){throw $cleanupFailure}
Write-Output "PASS $passed native Windows source custody cases"
