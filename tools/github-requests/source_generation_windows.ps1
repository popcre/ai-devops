# Explicit #658 parent supervisor. Ordinary waiters never trust environment claims.
# Windows PowerShell 5.1 compatible; no installation or machine-policy changes.
param(
    [Parameter(Mandatory=$true)][string]$SourceRoot,
    [Parameter(Mandatory=$true)][ValidateSet('bin/ai-pr-wait','bin/ai-gh')][string]$EntryPoint,
    [Parameter(Mandatory=$true)][string]$ArgumentsFile,
    [Parameter(Mandatory=$true)][long]$ReceiptHandle,
    [Parameter(Mandatory=$true)][long]$ReceiptAckHandle,
    [string]$BashExe
)
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'Native Windows required' }
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Text;
using System.Runtime.InteropServices;
using System.Security.Principal;
using Microsoft.Win32.SafeHandles;
using System.Diagnostics;
public static class GenerationCustody {
 [StructLayout(LayoutKind.Sequential)] public struct Info {
  public uint Attributes; public System.Runtime.InteropServices.ComTypes.FILETIME Created,Access,Written;
  public uint Volume,SizeHigh,SizeLow,Links,IndexHigh,IndexLow;
 }
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)]
 static extern SafeFileHandle CreateFileW(string path,uint access,uint share,IntPtr security,uint disposition,uint flags,IntPtr template);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool GetFileInformationByHandle(SafeFileHandle h,out Info info);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool SetHandleInformation(IntPtr h,uint mask,uint flags);
 [DllImport("kernel32.dll")] static extern uint GetFileType(IntPtr h);
 [DllImport("advapi32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool ConvertStringSecurityDescriptorToSecurityDescriptorW(string s,uint revision,out IntPtr descriptor,out uint size);
 [StructLayout(LayoutKind.Sequential)] struct SecurityAttributes { public uint Length; public IntPtr Descriptor; public bool Inherit; }
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool CreateDirectoryW(string path,ref SecurityAttributes security);
 [DllImport("kernel32.dll")] static extern IntPtr LocalFree(IntPtr p);
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode)] static extern SafeFileHandle CreateJobObjectW(IntPtr security,string name);
 [DllImport("kernel32.dll")] static extern bool SetInformationJobObject(SafeFileHandle job,int kind,ref JobLimits limits,uint size);
 [DllImport("kernel32.dll")] static extern bool AssignProcessToJobObject(SafeFileHandle job,IntPtr process);
 [DllImport("kernel32.dll")] static extern uint ResumeThread(IntPtr thread);
 [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
 [DllImport("kernel32.dll")] static extern bool TerminateProcess(IntPtr handle,uint code);
 [DllImport("kernel32.dll")] static extern IntPtr GetStdHandle(int kind);
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool CreateProcessW(string app,StringBuilder command,IntPtr processSecurity,IntPtr threadSecurity,bool inherit,uint flags,IntPtr environment,string cwd,ref Startup startup,out ProcessInfo process);
 [StructLayout(LayoutKind.Sequential)] struct BasicLimits {public long ProcessTime,JobTime;public uint Flags;public UIntPtr MinWorking,MaxWorking;public uint Active;public UIntPtr Affinity;public uint Priority,Scheduling;}
 [StructLayout(LayoutKind.Sequential)] struct IoCounters {public ulong A,B,C,D,E,F;}
 [StructLayout(LayoutKind.Sequential)] struct JobLimits {public BasicLimits Basic;public IoCounters Io;public UIntPtr ProcessMemory,JobMemory,PeakProcessMemory,PeakJobMemory;}
 [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)] struct Startup {public uint Size;public string Reserved,Desktop,Title;public uint X,Y,Width,Height,CharsX,CharsY,Fill,Flags;public ushort Show,ReservedSize;public IntPtr ReservedData,Input,Output,Error;}
 [StructLayout(LayoutKind.Sequential)] struct ProcessInfo {public IntPtr Process,Thread;public uint ProcessId,ThreadId;}
 public static SafeFileHandle Job(){SafeFileHandle j=CreateJobObjectW(IntPtr.Zero,null);JobLimits l=new JobLimits();l.Basic.Flags=0x2000;if(j.IsInvalid||!SetInformationJobObject(j,9,ref l,(uint)Marshal.SizeOf(typeof(JobLimits)))){j.Dispose();throw new IOException("Cancellation job unavailable");}return j;}
 public static Process Start(SafeFileHandle job,string executable,string arguments,string cwd){
  Startup s=new Startup();s.Size=(uint)Marshal.SizeOf(typeof(Startup));s.Flags=0x100;s.Input=GetStdHandle(-10);s.Output=GetStdHandle(-11);s.Error=GetStdHandle(-12);ProcessInfo p;
  if(!CreateProcessW(executable,new StringBuilder(Quote(executable)+" "+arguments),IntPtr.Zero,IntPtr.Zero,true,4,IntPtr.Zero,cwd,ref s,out p))throw new IOException("Suspended child creation failed");
  try{Process child=Process.GetProcessById((int)p.ProcessId);IntPtr retained=child.Handle;if(!AssignProcessToJobObject(job,p.Process)||ResumeThread(p.Thread)==0xffffffff){TerminateProcess(p.Process,125);child.Dispose();throw new IOException("Child cancellation custody unavailable");}return child;}finally{CloseHandle(p.Thread);CloseHandle(p.Process);}
 }
 public static void Materialize(string git,string root,string snapshot,string[] paths,string[] ids){
  ProcessStartInfo s=new ProcessStartInfo(git,"--no-replace-objects -C "+Quote(root)+" cat-file --batch");s.UseShellExecute=false;s.RedirectStandardInput=true;s.RedirectStandardOutput=true;s.RedirectStandardError=true;
  System.Collections.Generic.List<string> remove=new System.Collections.Generic.List<string>();foreach(string key in s.EnvironmentVariables.Keys)if(key.StartsWith("GIT_",StringComparison.OrdinalIgnoreCase))remove.Add(key);foreach(string key in remove)s.EnvironmentVariables.Remove(key);
  using(Process p=Process.Start(s)){
   try{Stream output=p.StandardOutput.BaseStream;
    for(int i=0;i<paths.Length;i++){
     p.StandardInput.WriteLine(ids[i]);p.StandardInput.Flush();StringBuilder header=new StringBuilder();int c;
     while((c=output.ReadByte())!=10){if(c<0||header.Length>100)throw new IOException("Git blob header unavailable");header.Append((char)c);}
     string[] parts=header.ToString().Split(' ');int count;
     if(parts.Length!=3||parts[0]!=ids[i]||parts[1]!="blob"||!Int32.TryParse(parts[2],out count)||count<0||count>67108864)throw new IOException("Unexpected Git blob response");
     byte[] bytes=new byte[count];int offset=0,n;while(offset<count){n=output.Read(bytes,offset,count-offset);if(n==0)throw new IOException("Incomplete Git blob");offset+=n;}
     if(output.ReadByte()!=10)throw new IOException("Git blob delimiter unavailable");
     string path=Path.Combine(snapshot,paths[i].Replace('/',Path.DirectorySeparatorChar));Directory.CreateDirectory(Path.GetDirectoryName(path));File.WriteAllBytes(path,bytes);
    }
    p.StandardInput.Close();if(!p.WaitForExit(10000)||p.ExitCode!=0)throw new IOException("Git materialization failed");
   }finally{if(!p.HasExited){p.Kill();p.WaitForExit();}}
  }
 }
 public static void PrivateDirectory(string path) {
  string sid=WindowsIdentity.GetCurrent().User.Value; IntPtr d;uint size;
  if(!ConvertStringSecurityDescriptorToSecurityDescriptorW("O:"+sid+"D:P(A;OICI;FA;;;"+sid+")(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)",1,out d,out size))throw new IOException("Private descriptor unavailable");
  try {SecurityAttributes a=new SecurityAttributes();a.Length=(uint)Marshal.SizeOf(typeof(SecurityAttributes));a.Descriptor=d;
   if(!CreateDirectoryW(path,ref a))throw new IOException("Fresh private snapshot directory required");
  }finally{LocalFree(d);}
 }
 public static SafeFileHandle Hold(string path,bool directory,bool denyWrites) {return Hold(path,directory,denyWrites,false);}
 public static SafeFileHandle Hold(string path,bool directory,bool denyWrites,bool existingExecutable) {
  SafeFileHandle h=CreateFileW(path,0x80000000,denyWrites?1u:3u,IntPtr.Zero,3,directory?0x02200000u:0x00200000u,IntPtr.Zero);
  if(h.IsInvalid){h.Dispose();throw new IOException("Source custody handle unavailable");}
  Info i;if(!GetFileInformationByHandle(h,out i)||(i.Attributes&0x400)!=0||((i.Attributes&0x10)!=0)!=directory||(!directory&&i.Links!=1&&!existingExecutable)){h.Dispose();throw new IOException("Reparse, hardlink, or wrong source type refused");}
  return h;
 }
 public static bool Same(SafeFileHandle a,SafeFileHandle b){Info x,y;return GetFileInformationByHandle(a,out x)&&GetFileInformationByHandle(b,out y)&&x.Volume==y.Volume&&x.IndexHigh==y.IndexHigh&&x.IndexLow==y.IndexLow;}
 public static FileStream Pipe(long raw,FileAccess access){IntPtr p=new IntPtr(raw);if(GetFileType(p)!=3||!SetHandleInformation(p,1,0))throw new IOException("Parent pipe handle unavailable");return new FileStream(new SafeFileHandle(p,false),access,4096,false);}
 public static string Quote(string s){if(s.Length>0&&s.IndexOfAny(new char[]{' ','\t','\n','\v','"'})<0)return s;StringBuilder b=new StringBuilder("\"");int n=0;foreach(char c in s){if(c=='\\'){n++;continue;}if(c=='"'){b.Append('\\',2*n+1);b.Append(c);n=0;continue;}b.Append('\\',n);n=0;b.Append(c);}b.Append('\\',2*n);b.Append('"');return b.ToString();}
}
'@
$locks = [Collections.Generic.List[IDisposable]]::new()
$snapshot = $null
$child = $null
$receipt = [GenerationCustody]::Pipe($ReceiptHandle,[IO.FileAccess]::Write)
$ack = [GenerationCustody]::Pipe($ReceiptAckHandle,[IO.FileAccess]::Read)
$exitCode = 125
function Hash-Bytes([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-','').ToLowerInvariant() } finally { $sha.Dispose() }
}
function Git-BlobHash([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA1]::Create()
    try {
        $header = [Text.Encoding]::ASCII.GetBytes(('blob '+$Bytes.Length+[char]0))
        [void]$sha.TransformBlock($header,0,$header.Length,$header,0)
        [void]$sha.TransformFinalBlock($Bytes,0,$Bytes.Length)
        return ([BitConverter]::ToString($sha.Hash)).Replace('-','').ToLowerInvariant()
    } finally { $sha.Dispose() }
}
function Git-Text([string[]]$GitArguments) {
    $saved = @{}
    foreach ($key in @([Environment]::GetEnvironmentVariables().Keys)) {
        if ($key -like 'GIT_*') { $saved[$key]=[Environment]::GetEnvironmentVariable($key,'Process');[Environment]::SetEnvironmentVariable($key,$null,'Process') }
    }
    try {
        $result = & $script:git --no-replace-objects -C $script:root @GitArguments
        if ($LASTEXITCODE -ne 0) { throw 'Installed Git generation unavailable' }
        return ($result -join "`n")
    } finally { foreach ($key in $saved.Keys) { [Environment]::SetEnvironmentVariable($key,$saved[$key],'Process') } }
}
function Bash-Path([string]$Path) {
    $p = [IO.Path]::GetFullPath($Path)
    if ($p.StartsWith('\\')) { throw 'Network source refused' }
    return '/'+$p.Substring(0,1)+'/'+$p.Substring(3).Replace('\','/')
}
try {
    foreach ($key in @([Environment]::GetEnvironmentVariables().Keys)) {
        if (($key -in @('BASH_ENV','ENV') -or $key -like 'BASH_FUNC_*') -and [Environment]::GetEnvironmentVariable($key,'Process')) { throw 'Ambient shell source prevents generation qualification' }
    }
    $root = [IO.Path]::GetFullPath($SourceRoot)
    $git = (Get-Command git.exe -ErrorAction Stop).Source
    $launcher = Join-Path $HOME '.local\bin\ai-task-gates.cmd'
    $launcherBytes = [IO.File]::ReadAllBytes($launcher)
    $launcherText = [Text.Encoding]::UTF8.GetString($launcherBytes)
    if ($launcherText -notmatch '(?m)^rem source-sha=([a-f0-9]{40})\r?$') { throw 'Managed installer source receipt required' }
    $sourceSha = $Matches[1]
    if ($launcherText -notmatch '(?m)^rem source-hash=([a-f0-9]{64})\r?$') { throw 'Managed gate digest required' }
    $gateHash = $Matches[1]
    if ($launcherText -notmatch '(?m)^"([^"\r\n]+)" "(/([A-Za-z])/[^"\r\n]+/bin/ai-task-gates)" %\*\r?$') { throw 'Managed launcher target required' }
    $installedBash = $Matches[1]
    $gatePath = $Matches[2].Substring(1,1)+':\'+$Matches[2].Substring(3).Replace('/','\')
    $expectedGit = Join-Path (Split-Path (Split-Path $installedBash -Parent) -Parent) 'cmd\git.exe'
    foreach ($executable in @($installedBash,$expectedGit)) {
        $parents = @();$parent = [IO.Directory]::GetParent($executable)
        while ($null -ne $parent) { $parents += $parent;$parent=$parent.Parent }
        foreach ($parent in ($parents | Sort-Object {$_.FullName.Length})) { $locks.Add([GenerationCustody]::Hold($parent.FullName,$true,$false)) }
    }
    # Existing Git installations legitimately hardlink git.exe. Deny-write
    # sharing protects the same underlying file through every hardlink alias.
    $gitHandle = [GenerationCustody]::Hold($git,$false,$true,$true)
    $expectedGitHandle = [GenerationCustody]::Hold($expectedGit,$false,$true,$true)
    if (-not [GenerationCustody]::Same($gitHandle,$expectedGitHandle)) { throw 'Unexpected Git helper refused' }
    $locks.Add($gitHandle);$locks.Add($expectedGitHandle)
    $gate = [GenerationCustody]::Hold((Join-Path $root 'bin\ai-task-gates'),$false,$false)
    $target = [GenerationCustody]::Hold($gatePath,$false,$false)
    try { if (-not [GenerationCustody]::Same($gate,$target)) { throw 'Installed source root mismatch' } } finally { $gate.Dispose();$target.Dispose() }
    if ((Git-Text @('rev-parse','HEAD')) -ne $sourceSha -or (Git-Text @('status','--porcelain','--untracked-files=no'))) { throw 'Installed source generation mismatch' }
    if ((Hash-Bytes ([IO.File]::ReadAllBytes((Join-Path $root 'bin\ai-task-gates')))) -ne $gateHash) { throw 'Installed gate receipt mismatch' }
    if (-not $BashExe) { $BashExe = $installedBash }
    $interpreter = [GenerationCustody]::Hold($BashExe,$false,$true)
    $expectedInterpreter = [GenerationCustody]::Hold($installedBash,$false,$true)
    if (-not [GenerationCustody]::Same($interpreter,$expectedInterpreter)) { throw 'Managed interpreter mismatch' }
    $locks.Add($interpreter);$locks.Add($expectedInterpreter)
    $snapshot = Join-Path ([IO.Path]::GetTempPath()) ('ai-gh-generation-'+[Guid]::NewGuid().ToString('N'))
    [GenerationCustody]::PrivateDirectory($snapshot)
    $blobs = @{}
    foreach ($entry in ((Git-Text @('ls-tree','-r',$sourceSha,'--','bin','tools','config')) -split "`n")) {
        if ($entry -notmatch '^100(644|755) blob ([a-f0-9]{40})\t(.+)$') { throw 'Unexpected Git generation object' }
        $blobs[$Matches[3]]=$Matches[2]
    }
    $paths = @($blobs.Keys)
    [Array]::Sort($paths,[StringComparer]::Ordinal)
    foreach ($relative in $paths) {
        if ($relative -notmatch '^(bin|tools|config)/[A-Za-z0-9_./ -]+$' -or $relative -match '(^|/)\.\.(/|$)') { throw 'Unexpected generation path' }
    }
    $ids = @($paths | ForEach-Object { $blobs[$_] })
    # Raw blobs avoid Git archive's Windows EOL/export transformations.
    [GenerationCustody]::Materialize($git,$root,$snapshot,[string[]]$paths,[string[]]$ids)
    # Freeze only the private generation. Canonical files stay writable.
    $ancestors = @()
    $ancestor = [IO.Directory]::GetParent($snapshot)
    while ($null -ne $ancestor) { $ancestors += $ancestor; $ancestor = $ancestor.Parent }
    $directories = @($ancestors) + @((Get-Item -LiteralPath $snapshot)) + @(Get-ChildItem -LiteralPath $snapshot -Directory -Recurse -Force)
    foreach ($directory in ($directories | Sort-Object { $_.FullName.Length })) { $locks.Add([GenerationCustody]::Hold($directory.FullName,$true,$false)) }
    $manifest = [Text.StringBuilder]::new()
    foreach ($relative in $paths) {
        if ($relative -notmatch '^(bin|tools|config)/[A-Za-z0-9_./ -]+$' -or $relative -match '(^|/)\.\.(/|$)') { throw 'Unexpected generation path' }
        $path = Join-Path $snapshot $relative
        $locks.Add([GenerationCustody]::Hold($path,$false,$true))
        $sourceBytes = [IO.File]::ReadAllBytes($path)
        if ((Git-BlobHash $sourceBytes) -ne $blobs[$relative]) { throw ('Snapshot differs from installed Git generation: '+$relative) }
        [void]$manifest.Append($relative).Append([char]0).Append((Hash-Bytes $sourceBytes)).Append("`n")
    }
    $argumentText = [IO.File]::ReadAllText($ArgumentsFile)
    if (-not $argumentText.TrimStart().StartsWith('[')) { throw 'String argument array required' }
    $arguments = $argumentText | ConvertFrom-Json
    if ($null -eq $arguments) { $arguments = @() }
    foreach ($argument in $arguments) { if ($argument -isnot [string] -or $argument.Contains([char]0)) { throw 'String argument array required' } }
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $BashExe
    $start.UseShellExecute = $false
    $start.WorkingDirectory = (Get-Location).ProviderPath
    $commandArguments = @((Bash-Path (Join-Path $snapshot $EntryPoint))) + @($arguments)
    $start.Arguments = (($commandArguments | ForEach-Object { [GenerationCustody]::Quote($_) }) -join ' ')
    $job = [GenerationCustody]::Job()
    $locks.Add($job)
    $child = [GenerationCustody]::Start($job,$start.FileName,$start.Arguments,$start.WorkingDirectory)
    $child.WaitForExit()
    $exitCode = $child.ExitCode
    $record = [ordered]@{schema=1;source_sha=$sourceSha;source_fingerprint=(Hash-Bytes ([Text.Encoding]::UTF8.GetBytes($manifest.ToString())));install_generation_binding=(Hash-Bytes $launcherBytes);source_boundary='windows_locked_generation';child_exit=$exitCode;source_verified='verified';unknown_reason='none';clock_quality='unknown';clock_error_bound_ms=$null}
    $bytes = [Text.Encoding]::UTF8.GetBytes((($record | ConvertTo-Json -Compress)+"`n"))
    $receipt.Write($bytes,0,$bytes.Length);$receipt.Flush()
    # Receipt is consumed before custody ends, never certified by a later file.
    $ackByte = New-Object byte[] 1
    $ackRead = $ack.ReadAsync($ackByte,0,1)
    if (-not $ackRead.Wait(30000) -or $ackRead.Result -ne 1 -or $ackByte[0] -ne 1) { throw 'Parent did not acknowledge source custody receipt' }
} finally {
    if ($null -ne $child) { if (-not $child.HasExited) { $child.Kill();$child.WaitForExit() };$child.Dispose() }
    for ($i=$locks.Count-1;$i -ge 0;$i--) { $locks[$i].Dispose() }
    $receipt.Dispose();$ack.Dispose()
    if ($snapshot -and (Test-Path -LiteralPath $snapshot)) { Remove-Item -LiteralPath $snapshot -Recurse -Force }
}
exit $exitCode
