# Explicit #658 parent supervisor. Ordinary waiters never trust environment claims.
# Windows PowerShell 5.1 compatible; no installation or machine-policy changes.
# Scope: raw committed bin/tools/config bytes, not checkout EOL/.gitattributes
# equivalence. Fixed issue/PR reads preserve the caller's working directory.
param(
    [Parameter(Mandatory=$true)][string]$SourceRoot,
    [Parameter(Mandatory=$true)][ValidateSet('bin/ai-pr-wait','bin/ai-gh')][string]$EntryPoint,
    [Parameter(Mandatory=$true,ParameterSetName='File')][string]$ArgumentsFile,
    [Parameter(Mandatory=$true,ParameterSetName='Inline')][string]$ArgumentsBase64,
    [Parameter(Mandatory=$true)][long]$ReceiptHandle,
    [Parameter(Mandatory=$true)][long]$ReceiptAckHandle,
    [string]$BashExe,
    [switch]$RestrictedReadProfile,
    [switch]$ObserverEvents,
    [switch]$ReadOnlyNoStdin,
    [string]$CounterManifest,
    [string]$ExpectedCounterManifestSha256
)
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'Native Windows required' }
function Assert-StagingParent([IO.DirectoryInfo]$Directory) {
    $trusted=@([Security.Principal.WindowsIdentity]::GetCurrent().User.Value,'S-1-5-18','S-1-5-32-544','S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464')
    $cursor=$Directory
    while($null -ne $cursor){
        if(-not $cursor.Exists -or ($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Staging ancestor unavailable or reparse point'}
        $acl=Microsoft.PowerShell.Security\Get-Acl -LiteralPath $cursor.FullName
        $raw=[Security.AccessControl.RawSecurityDescriptor]::new($acl.GetSecurityDescriptorBinaryForm(),0)
        if($null -eq $raw.Owner -or $raw.Owner.Value -notin $trusted -or $null -eq $raw.DiscretionaryAcl -or $raw.DiscretionaryAcl.Count -eq 0){throw 'Staging ancestor ownership or DACL unavailable'}
        $mask=0x500d0156L
        # Standard volume roots permit creating a NEW sibling directory. That
        # alone cannot replace an existing protected path; fresh names refuse
        # adoption and every actual staging parent uses the full write mask.
        if($null -eq $cursor.Parent){$mask=$mask -band (-bnot 4L)}
        foreach($ace in $raw.DiscretionaryAcl){
            if(([int]$ace.AceFlags -band [int][Security.AccessControl.AceFlags]::InheritOnly) -ne 0){continue}
            if($ace -isnot [Security.AccessControl.CommonAce] -or $ace.IsCallback){throw 'Unknown staging ancestor ACE'}
            if($ace.AceQualifier -eq [Security.AccessControl.AceQualifier]::AccessDenied){continue}
            if($ace.AceQualifier -ne [Security.AccessControl.AceQualifier]::AccessAllowed){throw 'Unknown staging ancestor rights'}
            if($ace.SecurityIdentifier.Value -notin $trusted -and (([long]$ace.AccessMask -band 0xffffffffL) -band $mask)){throw 'Foreign staging ancestor writer'}
        }
        $cursor=$cursor.Parent
    }
}
function New-BootstrapPrivateDirectory([string]$Path) {
    if(Test-Path -LiteralPath $Path){throw 'Fresh compiler namespace required'}
    $sid=[Security.Principal.WindowsIdentity]::GetCurrent().User
    $acl=[Security.AccessControl.DirectorySecurity]::new();$acl.SetOwner($sid);$acl.SetAccessRuleProtection($true,$false)
    foreach($owner in @($sid,[Security.Principal.SecurityIdentifier]::new('S-1-5-18'),[Security.Principal.SecurityIdentifier]::new('S-1-5-32-544'))){
        $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($owner,'FullControl','ContainerInherit,ObjectInherit','None','Allow'))
    }
    $info=[IO.DirectoryInfo]::new($Path)
    if($PSVersionTable.PSEdition -eq 'Core'){[IO.FileSystemAclExtensions]::Create($info,$acl)}else{$info.Create($acl)}
    return $info
}
# Bootstrap compilation uses ONLY a fresh private child of a verified existing
# standard parent. Never repair a shared parent or honor arbitrary TEMP roots.
$stagingParent=$null
foreach($candidate in @((Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Temp'),[Environment]::GetFolderPath('ProgramFiles'))){
    try{$directory=[IO.DirectoryInfo]::new($candidate);Assert-StagingParent $directory;$stagingParent=$directory;break}catch{}
}
if($null -eq $stagingParent){throw 'Source boundary unavailable: no protected standard staging parent; ordinary installed tools remain available'}
$bootstrap=New-BootstrapPrivateDirectory (Join-Path $stagingParent.FullName ('ai-gh-bootstrap-'+$PID+'-'+[Guid]::NewGuid().ToString('N')))
$compiler=New-BootstrapPrivateDirectory (Join-Path $bootstrap.FullName 'compile')
$savedTemp=$env:TEMP;$savedTmp=$env:TMP
try{
$env:TEMP=$compiler.FullName;$env:TMP=$compiler.FullName
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Text;
using System.Runtime.InteropServices;
using System.Security.Principal;
using System.Security.AccessControl;
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
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern SafeFileHandle CreateNamedPipeW(string name,uint access,uint mode,uint instances,uint output,uint input,uint timeout,ref SecurityAttributes security);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool ConnectNamedPipe(SafeFileHandle pipe,IntPtr overlapped);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool SetNamedPipeHandleState(SafeFileHandle pipe,ref uint mode,IntPtr count,IntPtr timeout);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool ReadFile(SafeFileHandle file,byte[] data,uint count,out uint read,IntPtr overlapped);
 [DllImport("kernel32.dll")] static extern IntPtr LocalFree(IntPtr p);
 [DllImport("advapi32.dll",SetLastError=true)] static extern uint SetSecurityInfo(SafeFileHandle h,uint kind,uint flags,IntPtr owner,IntPtr group,IntPtr dacl,IntPtr sacl);
 [DllImport("advapi32.dll",SetLastError=true)] static extern bool GetSecurityDescriptorDacl(IntPtr descriptor,out bool present,out IntPtr acl,out bool defaulted);
 [DllImport("advapi32.dll",SetLastError=true)] static extern uint GetSecurityInfo(SafeFileHandle h,uint kind,uint flags,out IntPtr owner,out IntPtr group,out IntPtr dacl,out IntPtr sacl,out IntPtr descriptor);
 [DllImport("advapi32.dll")] static extern uint GetSecurityDescriptorLength(IntPtr descriptor);
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode)] static extern SafeFileHandle CreateJobObjectW(IntPtr security,string name);
 [DllImport("kernel32.dll")] static extern bool SetInformationJobObject(SafeFileHandle job,int kind,ref JobLimits limits,uint size);
 [DllImport("kernel32.dll")] static extern bool AssignProcessToJobObject(SafeFileHandle job,IntPtr process);
 [DllImport("kernel32.dll")] static extern uint ResumeThread(IntPtr thread);
 [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
 [DllImport("kernel32.dll")] static extern bool TerminateProcess(IntPtr handle,uint code);
 [DllImport("kernel32.dll")] static extern IntPtr GetStdHandle(int kind);
 [DllImport("kernel32.dll")] static extern IntPtr GetCurrentProcess();
 [DllImport("advapi32.dll",SetLastError=true)] static extern bool OpenProcessToken(IntPtr process,uint access,out SafeFileHandle token);
 [DllImport("advapi32.dll",SetLastError=true)] static extern bool DuplicateTokenEx(SafeFileHandle token,uint access,IntPtr security,int impersonation,int kind,out SafeFileHandle result);
 [DllImport("advapi32.dll",SetLastError=true)] static extern bool AdjustTokenPrivileges(SafeFileHandle token,bool disableAll,IntPtr state,uint size,IntPtr previous,IntPtr returned);
 [DllImport("advapi32.dll",SetLastError=true)] static extern bool GetTokenInformation(SafeFileHandle token,int kind,IntPtr information,uint size,out uint needed);
 [DllImport("advapi32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool LookupPrivilegeNameW(string system,ref Luid luid,StringBuilder name,ref uint length);
 [StructLayout(LayoutKind.Sequential)] struct Luid {public uint Low;public int High;}
 [StructLayout(LayoutKind.Sequential)] struct Privilege {public Luid Id;public uint Attributes;}
 [StructLayout(LayoutKind.Sequential)] struct TokenGroup {public IntPtr Sid;public uint Attributes;}
 [DllImport("advapi32.dll",SetLastError=true)] static extern bool CreateRestrictedToken(SafeFileHandle token,uint flags,uint disableCount,TokenGroup[] disabled,uint deleteCount,Privilege[] deleted,uint restrictCount,IntPtr restricted,out SafeFileHandle result);
 [StructLayout(LayoutKind.Sequential)] struct DefaultDacl {public IntPtr Acl;}
 [DllImport("advapi32.dll",SetLastError=true)] static extern bool SetTokenInformation(SafeFileHandle token,int kind,ref DefaultDacl information,uint size);
 [DllImport("advapi32.dll",EntryPoint="SetTokenInformation",SetLastError=true)] static extern bool SetTokenIntegrityInformation(SafeFileHandle token,int kind,ref TokenGroup information,uint size);
 [DllImport("advapi32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool CreateProcessAsUserW(SafeFileHandle token,string app,StringBuilder command,IntPtr processSecurity,IntPtr threadSecurity,bool inherit,uint flags,IntPtr environment,string cwd,ref Startup startup,out ProcessInfo process);
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool CreateProcessW(string app,StringBuilder command,IntPtr processSecurity,IntPtr threadSecurity,bool inherit,uint flags,IntPtr environment,string cwd,ref Startup startup,out ProcessInfo process);
 [StructLayout(LayoutKind.Sequential)] struct BasicLimits {public long ProcessTime,JobTime;public uint Flags;public UIntPtr MinWorking,MaxWorking;public uint Active;public UIntPtr Affinity;public uint Priority,Scheduling;}
 [StructLayout(LayoutKind.Sequential)] struct IoCounters {public ulong A,B,C,D,E,F;}
 [StructLayout(LayoutKind.Sequential)] struct JobLimits {public BasicLimits Basic;public IoCounters Io;public UIntPtr ProcessMemory,JobMemory,PeakProcessMemory,PeakJobMemory;}
 [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)] struct Startup {public uint Size;public string Reserved,Desktop,Title;public uint X,Y,Width,Height,CharsX,CharsY,Fill,Flags;public ushort Show,ReservedSize;public IntPtr ReservedData,Input,Output,Error;}
 [StructLayout(LayoutKind.Sequential)] struct ProcessInfo {public IntPtr Process,Thread;public uint ProcessId,ThreadId;}
 public static SafeFileHandle Job(){SafeFileHandle j=CreateJobObjectW(IntPtr.Zero,null);JobLimits l=new JobLimits();l.Basic.Flags=0x2000;if(j.IsInvalid||!SetInformationJobObject(j,9,ref l,(uint)Marshal.SizeOf(typeof(JobLimits)))){j.Dispose();throw new IOException("Cancellation job unavailable");}return j;}
 static Privilege[] Privileges(SafeFileHandle token){uint needed;GetTokenInformation(token,3,IntPtr.Zero,0,out needed);if(needed<4||needed>65536)throw new IOException("Token privilege information unavailable");IntPtr buffer=Marshal.AllocHGlobal((int)needed);try{if(!GetTokenInformation(token,3,buffer,needed,out needed))throw new IOException("Token privilege information unavailable");int count=Marshal.ReadInt32(buffer);Privilege[] items=new Privilege[count];for(int i=0;i<count;i++)items[i]=(Privilege)Marshal.PtrToStructure(new IntPtr(buffer.ToInt64()+4+12*i),typeof(Privilege));return items;}finally{Marshal.FreeHGlobal(buffer);}}
 static string PrivilegeName(Luid id){uint length=256;StringBuilder text=new StringBuilder(256);if(!LookupPrivilegeNameW(null,ref id,text,ref length))throw new IOException("Token privilege name unavailable");return text.ToString();}
 static bool HasBypassPrivilege(SafeFileHandle token){foreach(Privilege item in Privileges(token)){string name=PrivilegeName(item.Id);if(name=="SeRestorePrivilege"||name=="SeTakeOwnershipPrivilege"||name=="SeDebugPrivilege"||name=="SeTcbPrivilege")return true;}return false;}
 public static bool PrivilegedContext(){SafeFileHandle token;if(!OpenProcessToken(GetCurrentProcess(),8,out token))throw new IOException("Token qualification unavailable");using(token){return HasBypassPrivilege(token);}}
 public static string PrivilegeState(){SafeFileHandle token;if(!OpenProcessToken(GetCurrentProcess(),8,out token))throw new IOException("Token qualification unavailable");using(token){var names=new System.Collections.Generic.List<string>();foreach(Privilege p in Privileges(token))names.Add(PrivilegeName(p.Id)+":"+p.Attributes);names.Sort(StringComparer.Ordinal);return String.Join(";",names.ToArray());}}
 public static bool DisabledBypassStillDetected(){
  SafeFileHandle original;if(!OpenProcessToken(GetCurrentProcess(),0xf01ff,out original))throw new IOException("Owned token fixture unavailable");using(original){bool expected=HasBypassPrivilege(original);SafeFileHandle duplicate;if(!DuplicateTokenEx(original,0xf01ff,IntPtr.Zero,2,1,out duplicate))throw new IOException("Owned token duplication unavailable");using(duplicate){if(!AdjustTokenPrivileges(duplicate,true,IntPtr.Zero,0,IntPtr.Zero,IntPtr.Zero))throw new IOException("Owned token disable fixture unavailable");foreach(Privilege item in Privileges(duplicate))if((item.Attributes&2)!=0)throw new IOException("Fixture privilege remains enabled");return HasBypassPrivilege(duplicate)==expected;}}
 }
 static SafeFileHandle RestrictedToken(){
  SafeFileHandle token;if(!OpenProcessToken(GetCurrentProcess(),0xf01ff,out token))throw new IOException("Read capsule token unavailable");
  using(token){var deleted=new System.Collections.Generic.List<Privilege>();foreach(Privilege item in Privileges(token))if(PrivilegeName(item.Id)!="SeChangeNotifyPrivilege")deleted.Add(item);
   SecurityIdentifier admin=new SecurityIdentifier(WellKnownSidType.BuiltinAdministratorsSid,null);byte[] bytes=new byte[admin.BinaryLength];admin.GetBinaryForm(bytes,0);IntPtr sid=Marshal.AllocHGlobal(bytes.Length);Marshal.Copy(bytes,0,sid,bytes.Length);
   try{SafeFileHandle result;TokenGroup group=new TokenGroup();group.Sid=sid;if(!CreateRestrictedToken(token,0,1,new TokenGroup[]{group},(uint)deleted.Count,deleted.ToArray(),0,IntPtr.Zero,out result))throw new IOException("Restricted read token creation failed");
    try{ConfigureReadToken(result);return result;}catch{result.Dispose();throw;}
   }finally{Marshal.FreeHGlobal(sid);}
  }
 }
 static void ConfigureReadToken(SafeFileHandle token){
  // MSYS opens its own token to set a per-token default DACL and creates
  // process-tracker pipes. Grant the unchanged user SID control of ONLY this
  // fresh token and its new resources; no parent/global token is modified.
  string user=WindowsIdentity.GetCurrent().User.Value;IntPtr descriptor;uint size;
  if(!ConvertStringSecurityDescriptorToSecurityDescriptorW("D:P(A;;GA;;;"+user+")(A;;GA;;;SY)",1,out descriptor,out size))throw new IOException("Read token descriptor unavailable");
  try{bool present,defaulted;IntPtr acl;if(!GetSecurityDescriptorDacl(descriptor,out present,out acl,out defaulted)||!present||SetSecurityInfo(token,6,4,IntPtr.Zero,IntPtr.Zero,acl,IntPtr.Zero)!=0)throw new IOException("Read token user access unavailable");
   DefaultDacl value=new DefaultDacl();value.Acl=acl;if(!SetTokenInformation(token,6,ref value,(uint)Marshal.SizeOf(typeof(DefaultDacl))))throw new IOException("Read token resource access unavailable");
  }finally{LocalFree(descriptor);}
  uint needed;GetTokenInformation(token,25,IntPtr.Zero,0,out needed);if(needed<16||needed>4096)throw new IOException("Read token integrity unavailable");IntPtr current=Marshal.AllocHGlobal((int)needed);
  try{if(!GetTokenInformation(token,25,current,needed,out needed))throw new IOException("Read token integrity unavailable");string integrity=new SecurityIdentifier(Marshal.ReadIntPtr(current)).Value;int level=Int32.Parse(integrity.Substring(integrity.LastIndexOf('-')+1));
   SecurityIdentifier medium=new SecurityIdentifier("S-1-16-"+Math.Min(level,8192));byte[] bytes=new byte[medium.BinaryLength];medium.GetBinaryForm(bytes,0);IntPtr sid=Marshal.AllocHGlobal(bytes.Length);Marshal.Copy(bytes,0,sid,bytes.Length);
   try{TokenGroup label=new TokenGroup();label.Sid=sid;label.Attributes=0x20;if(!SetTokenIntegrityInformation(token,25,ref label,(uint)(Marshal.SizeOf(typeof(TokenGroup))+bytes.Length)))throw new IOException("Read token integrity limit unavailable");}finally{Marshal.FreeHGlobal(sid);}
  }finally{Marshal.FreeHGlobal(current);}
 }
 public static Process Start(SafeFileHandle job,string executable,string arguments,string cwd){return Start(job,executable,arguments,cwd,false);}
 public static Process Start(SafeFileHandle job,string executable,string arguments,string cwd,bool restricted){return Start(job,executable,arguments,cwd,restricted,false);}
 public static Process Start(SafeFileHandle job,string executable,string arguments,string cwd,bool restricted,bool noStdin){
  Startup s=new Startup();s.Size=(uint)Marshal.SizeOf(typeof(Startup));s.Flags=0x100;s.Input=GetStdHandle(-10);s.Output=GetStdHandle(-11);s.Error=GetStdHandle(-12);ProcessInfo p;
  bool created;using(SafeFileHandle input=noStdin?CreateFileW("NUL",0x80000000,3,IntPtr.Zero,3,0,IntPtr.Zero):null){if(noStdin){if(input.IsInvalid||!SetHandleInformation(input.DangerousGetHandle(),1,1))throw new IOException("Explicit no-stdin profile unavailable");s.Input=input.DangerousGetHandle();}using(SafeFileHandle token=restricted?RestrictedToken():null){created=restricted?CreateProcessAsUserW(token,executable,new StringBuilder(Quote(executable)+" "+arguments),IntPtr.Zero,IntPtr.Zero,true,4,IntPtr.Zero,cwd,ref s,out p):CreateProcessW(executable,new StringBuilder(Quote(executable)+" "+arguments),IntPtr.Zero,IntPtr.Zero,true,4,IntPtr.Zero,cwd,ref s,out p);}}
  if(!created)throw new IOException("Suspended child creation failed");
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
 public static SafeFileHandle DirectoryControl(string path){
  SafeFileHandle h=CreateFileW(path,0x80040000,3,IntPtr.Zero,3,0x02200000,IntPtr.Zero);Info i;
  if(h.IsInvalid||!GetFileInformationByHandle(h,out i)||(i.Attributes&0x400)!=0||(i.Attributes&0x10)==0){h.Dispose();throw new IOException("Private directory control unavailable");}return h;
 }
 public static void AssertProtectedParent(SafeFileHandle handle,bool volumeRoot){
  AssertProtectedMetadata(handle,volumeRoot,false);
 }
 public static void AssertPrivateConfigFile(SafeFileHandle handle){AssertProtectedMetadata(handle,false,true);}
 static void AssertProtectedMetadata(SafeFileHandle handle,bool volumeRoot,bool privateFile){
  IntPtr owner,group,dacl,sacl,descriptor;if(GetSecurityInfo(handle,1,5,out owner,out group,out dacl,out sacl,out descriptor)!=0)throw new IOException("Parent security unavailable");
  try{uint length=GetSecurityDescriptorLength(descriptor);if(length==0||length>65536)throw new IOException("Parent security unavailable");byte[] bytes=new byte[length];Marshal.Copy(descriptor,bytes,0,(int)length);RawSecurityDescriptor security=new RawSecurityDescriptor(bytes,0);
   string current=WindowsIdentity.GetCurrent().User.Value;var trusted=new System.Collections.Generic.HashSet<string>(new string[]{current,"S-1-5-18","S-1-5-32-544","S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464"});
   if(security.Owner==null||!trusted.Contains(security.Owner.Value)||security.DiscretionaryAcl==null||security.DiscretionaryAcl.Count==0)throw new IOException("Untrusted staging parent owner or DACL");
   uint mask=volumeRoot?0x500d0152u:0x500d0156u;if(privateFile)mask|=0x90000001u;
   foreach(GenericAce entry in security.DiscretionaryAcl){if((entry.AceFlags&AceFlags.InheritOnly)!=0)continue;CommonAce ace=entry as CommonAce;if(ace==null||ace.IsCallback)throw new IOException("Unknown staging parent ACE");if(ace.AceQualifier==AceQualifier.AccessDenied)continue;if(ace.AceQualifier!=AceQualifier.AccessAllowed||(!trusted.Contains(ace.SecurityIdentifier.Value)&&(unchecked((uint)ace.AccessMask)&mask)!=0))throw new IOException(privateFile?"Foreign config file reader or writer":"Foreign staging parent writer");}
  }finally{LocalFree(descriptor);}
 }
 public static void DirectoryAccess(SafeFileHandle h,bool writable){
  string sid=WindowsIdentity.GetCurrent().User.Value;
  // OWNER RIGHTS suppresses the owner's implicit WRITE_DAC. The parent alone
  // retains previously granted control handles for restoring its fresh objects.
  string acl=writable?"D:P(A;OICI;FA;;;"+sid+")(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)":
   "D:P(D;OICI;0x000d0156;;;"+sid+")(A;OICI;0x001200a9;;;"+sid+")(A;OICI;FA;;;SY)(A;OICI;RC;;;OW)";
  IntPtr descriptor;uint size;if(!ConvertStringSecurityDescriptorToSecurityDescriptorW("O:"+sid+acl,1,out descriptor,out size))throw new IOException("Snapshot seal descriptor unavailable");
  try{bool present,defaulted;IntPtr dacl;if(!GetSecurityDescriptorDacl(descriptor,out present,out dacl,out defaulted)||!present||SetSecurityInfo(h,1,0x80000004,IntPtr.Zero,IntPtr.Zero,dacl,IntPtr.Zero)!=0)throw new IOException("Snapshot directory sealing unavailable");}finally{LocalFree(descriptor);}
 }
 public static byte[] Read(SafeFileHandle handle){
  return Read(handle,67108864);
 }
 public static byte[] Read(SafeFileHandle handle,int maximum){
  using(FileStream stream=new FileStream(new SafeFileHandle(handle.DangerousGetHandle(),false),FileAccess.Read)){
   if(stream.Length>maximum)throw new IOException("Source capture too large");byte[] bytes=new byte[(int)stream.Length];int offset=0,n;while(offset<bytes.Length){n=stream.Read(bytes,offset,bytes.Length-offset);if(n==0)throw new IOException("Source capture incomplete");offset+=n;}return bytes;
  }
 }
 public static void AssertClosure(string root,string[] paths){
  var files=new System.Collections.Generic.HashSet<string>(paths,StringComparer.OrdinalIgnoreCase);
  var directories=new System.Collections.Generic.HashSet<string>(StringComparer.OrdinalIgnoreCase);
  foreach(string path in paths){int slash=path.LastIndexOf('/');while(slash>0){directories.Add(path.Substring(0,slash));slash=path.LastIndexOf('/',slash-1);}}
  var pending=new System.Collections.Generic.Stack<string>();pending.Push(root);int count=0;
  while(pending.Count>0){string directory=pending.Pop();foreach(string entry in Directory.GetFileSystemEntries(directory)){
   FileAttributes attributes=File.GetAttributes(entry);if((attributes&FileAttributes.ReparsePoint)!=0)throw new IOException("Unexpected reparse helper in private generation");
   string relative=entry.Substring(root.Length+1).Replace('\\','/');
   if((attributes&FileAttributes.Directory)!=0){if(!directories.Contains(relative))throw new IOException("Unexpected helper directory in private generation");pending.Push(entry);}
   else{if(!files.Contains(relative))throw new IOException("Unexpected helper in private generation");count++;}
  }}if(count!=paths.Length)throw new IOException("Incomplete private generation");
 }
 public sealed class EventChannel:IDisposable {
  readonly SafeFileHandle reader,writer;readonly System.Collections.Generic.List<byte[]> messages=new System.Collections.Generic.List<byte[]>();readonly int limit;int total;bool invalid;
  public long WriteHandle {get{return writer.DangerousGetHandle().ToInt64();}}
  public string Status {get{return invalid?"invalid":messages.Count==1?"received":"unavailable";}}
  public EventChannel():this(1){}
  public EventChannel(int messageLimit){
   if(messageLimit!=1&&messageLimit!=128)throw new ArgumentException("Finite channel limit required");limit=messageLimit;
   string user=WindowsIdentity.GetCurrent().User.Value;IntPtr descriptor;uint size;
   if(!ConvertStringSecurityDescriptorToSecurityDescriptorW("O:"+user+"D:P(A;;GA;;;"+user+")(A;;GA;;;SY)S:(ML;;NW;;;ME)",1,out descriptor,out size))throw new IOException("Private event descriptor unavailable");
   try{SecurityAttributes a=new SecurityAttributes();a.Length=(uint)Marshal.SizeOf(typeof(SecurityAttributes));a.Descriptor=descriptor;
    string name=@"\\.\pipe\ai-gh-event-"+Guid.NewGuid().ToString("N");reader=CreateNamedPipeW(name,0x80001,15,1,4096,65536,0,ref a);
    if(reader.IsInvalid)throw new IOException("Private event pipe unavailable");ConnectNamedPipe(reader,IntPtr.Zero);
    writer=CreateFileW(name,0x40000000,0,IntPtr.Zero,3,0,IntPtr.Zero);uint mode=1;
    if(writer.IsInvalid||!SetNamedPipeHandleState(writer,ref mode,IntPtr.Zero,IntPtr.Zero)||!SetHandleInformation(writer.DangerousGetHandle(),1,1))throw new IOException("Nonblocking event writer unavailable");
   }catch{if(writer!=null)writer.Dispose();if(reader!=null)reader.Dispose();throw;}finally{LocalFree(descriptor);}
  }
  public void Drain(){if(invalid)return;for(int i=0;i<129;i++){
   byte[] data=new byte[4096];uint read;bool ok=ReadFile(reader,data,4096,out read,IntPtr.Zero);int error=Marshal.GetLastWin32Error();
   if(!ok&&(error==232||error==109||error==536))return;
   if(!ok||read==0){invalid=true;return;}total+=(int)read;if(total>65536||messages.Count>=limit){invalid=true;return;}
   byte[] message=new byte[read];Array.Copy(data,message,read);messages.Add(message);
  }invalid=true;}
  public string EventText(){Drain();if(invalid||messages.Count!=1)return null;try{return new UTF8Encoding(false,true).GetString(messages[0]);}catch(DecoderFallbackException){invalid=true;return null;}}
  public string CounterText(){Drain();if(invalid||messages.Count==0)return null;try{var b=new StringBuilder();foreach(byte[] m in messages)b.Append(new UTF8Encoding(false,true).GetString(m));return b.ToString();}catch(DecoderFallbackException){invalid=true;return null;}}
  public void Dispose(){writer.Dispose();reader.Dispose();}
 }
 public static SafeFileHandle Hold(string path,bool directory,bool denyWrites) {return Hold(path,directory,denyWrites,false);}
 public static SafeFileHandle Metadata(string path,bool directory){
  SafeFileHandle h=CreateFileW(path,0x20080,3,IntPtr.Zero,3,directory?0x02200000u:0x00200000u,IntPtr.Zero);
  if(h.IsInvalid){int error=Marshal.GetLastWin32Error();h.Dispose();if(error==2||error==3)return null;throw new IOException("Config metadata unavailable");}
  Info i;if(!GetFileInformationByHandle(h,out i)||(i.Attributes&0x400)!=0||((i.Attributes&0x10)!=0)!=directory||(!directory&&i.Links!=1)){h.Dispose();throw new IOException("Config alias or wrong object type refused");}
  return h;
 }
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
}catch{Remove-Item -LiteralPath $bootstrap.FullName -Recurse -Force;throw}finally{$env:TEMP=$savedTemp;$env:TMP=$savedTmp}
$locks = [Collections.Generic.List[IDisposable]]::new()
$directoryControls = [Collections.Generic.List[Microsoft.Win32.SafeHandles.SafeFileHandle]]::new()
$captureLocks = [Collections.Generic.List[IDisposable]]::new()
$snapshot = $null
$child = $null
$eventChannel = $null
$counterChannel = $null
$counterBinding = $null
$receipt = $null
$ack = $null
$exitCode = 125
$primaryFailure = $null
$cancelled = $false
function Invoke-OwnedCleanupStep([Collections.Generic.List[object]]$Errors,[string]$Phase,[object]$Resource,[scriptblock]$Operation) {
    if($null -eq $Resource){return}
    try{& $Operation $Resource | Out-Null}catch{$Errors.Add([pscustomobject]@{phase=$Phase;error=$_})}
}
function Close-OwnedGeneration([Collections.IDictionary]$Owned) {
    $errors=[Collections.Generic.List[object]]::new()
    Invoke-OwnedCleanupStep $errors 'job_stop' $Owned.Job {param($r)$r.Dispose()}
    Invoke-OwnedCleanupStep $errors 'child_stop' $Owned.Child {param($r)if(-not $r.HasExited){$r.Kill();if(-not $r.WaitForExit(10000)){throw 'Owned child did not stop within cleanup deadline'}}}
    Invoke-OwnedCleanupStep $errors 'child_dispose' $Owned.Child {param($r)$r.Dispose()}
    Invoke-OwnedCleanupStep $errors 'event_channel' $Owned.EventChannel {param($r)$r.Dispose()}
    Invoke-OwnedCleanupStep $errors 'counter_channel' $Owned.CounterChannel {param($r)$r.Dispose()}
    foreach($capture in $Owned.CaptureLocks){Invoke-OwnedCleanupStep $errors 'capture_handle' $capture {param($r)$r.Dispose()}}
    foreach($control in $Owned.DirectoryControls){Invoke-OwnedCleanupStep $errors 'directory_unseal' $control {param($r)[GenerationCustody]::DirectoryAccess($r,$true)}}
    foreach($control in $Owned.DirectoryControls){Invoke-OwnedCleanupStep $errors 'directory_control' $control {param($r)$r.Dispose()}}
    for($index=$Owned.Locks.Count-1;$index -ge 0;$index--){Invoke-OwnedCleanupStep $errors 'custody_handle' $Owned.Locks[$index] {param($r)$r.Dispose()}}
    Invoke-OwnedCleanupStep $errors 'receipt' $Owned.Receipt {param($r)$r.Dispose()}
    Invoke-OwnedCleanupStep $errors 'ack' $Owned.Ack {param($r)$r.Dispose()}
    Invoke-OwnedCleanupStep $errors 'snapshot_remove' $Owned.Snapshot {param($p)if(Test-Path -LiteralPath $p){Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop}}
    Invoke-OwnedCleanupStep $errors 'bootstrap_remove' $Owned.Bootstrap {param($p)if(Test-Path -LiteralPath $p){Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop}}
    return ,$errors
}
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
function Read-LockedBytes([string]$Path) {
    $handle=[GenerationCustody]::Hold($Path,$false,$true)
    $script:locks.Add($handle)
    return ,([GenerationCustody]::Read($handle))
}
function Assert-CounterContext {
    foreach($key in @([Environment]::GetEnvironmentVariables().Keys)) {
        if(($key -in @('AI_GH_REAL_GH','GH_PATH','GH_DEBUG','GH_HTTP_UNIX_SOCKET','GH_FORCE_TTY','MSYS_NO_PATHCONV','MSYS2_ARG_CONV_EXCL') -or $key -like 'AI_GH_HTTP_COUNTER_*') -and [Environment]::GetEnvironmentVariable($key,'Process')) { throw 'Ambient counter routing or injection prevents measurement; ordinary command remains available' }
    }
    foreach($key in @('GH_PAGER','PAGER')){if([Environment]::GetEnvironmentVariable($key,'Process') -and [Environment]::GetEnvironmentVariable($key,'Process') -cne 'cat'){throw 'Only literal cat pager is qualified for nonTTY read'}}
    if($env:GH_HOST -and $env:GH_HOST -cne 'github.com'){throw 'Counter supports original github.com context only'}
    if([Console]::IsInputRedirected -eq $false -or [Console]::IsOutputRedirected -eq $false){throw 'Counter requires explicit nonTTY read capsule'}
}
function Config-Directory {
    # cli2.97.0 internal/config/config.go delegates to go-gh/v2@v2.13.0
    # pkg/config/config.go:250. Windows UserHomeDir is USERPROFILE, not HOME.
    if($env:GH_CONFIG_DIR){return $env:GH_CONFIG_DIR}
    if($env:XDG_CONFIG_HOME){return [IO.Path]::Combine($env:XDG_CONFIG_HOME,'gh')}
    if($env:APPDATA){return [IO.Path]::Combine($env:APPDATA,'GitHub CLI')}
    if($env:USERPROFILE){return [IO.Path]::Combine($env:USERPROFILE,'.config','gh')}
    throw 'Original gh configuration location unavailable'
}
function Assert-ConfigMetadata {
    $path=Config-Directory
    # Match native Go absolute semantics. Reject drive-relative/root-relative
    # and UNC namespaces rather than resolving them against a different cwd.
    if($path -notmatch '^[A-Za-z]:[\\/]' -or $path.StartsWith('\\')){throw 'Absolute original gh configuration required'}
    $directory=[IO.DirectoryInfo]::new([IO.Path]::GetFullPath($path))
    $parents=@();$cursor=$directory
    while($null -ne $cursor){$parents+=$cursor;$cursor=$cursor.Parent}
    $tokenPresent=([bool]$env:GH_TOKEN -or [bool]$env:GITHUB_TOKEN)
    foreach($parent in ($parents|Sort-Object {$_.FullName.Length})){
        $held=[GenerationCustody]::Metadata($parent.FullName,$true)
        if($null -eq $held){if($tokenPresent){return};throw 'Missing original gh config requires existing token environment'}
        try{[GenerationCustody]::AssertProtectedParent($held,($null -eq $parent.Parent));$script:locks.Add($held)}catch{$held.Dispose();throw}
    }
    foreach($name in @('config.yml','hosts.yml')){
        $held=[GenerationCustody]::Metadata((Join-Path $directory.FullName $name),$false)
        if($null -eq $held){if($name -ceq 'hosts.yml' -and -not $tokenPresent){throw 'Missing original gh hosts metadata requires existing token environment'};continue}
        try{[GenerationCustody]::AssertPrivateConfigFile($held);$script:locks.Add($held)}catch{$held.Dispose();throw}
    }
}
function Local-OnlyProbe([string]$Executable,[string[]]$Values) {
    $info=[Diagnostics.ProcessStartInfo]::new();$info.FileName=$Executable;$info.UseShellExecute=$false
    $info.Arguments=($Values|ForEach-Object{[GenerationCustody]::Quote($_)}) -join ' '
    $info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true;$info.RedirectStandardInput=$true
    $process=[Diagnostics.Process]::new();$process.StartInfo=$info
    try{
        if(-not $process.Start()){throw 'Local version probe unavailable'}
        $process.StandardInput.Close();$output=$process.StandardOutput.ReadToEndAsync();$errors=$process.StandardError.ReadToEndAsync()
        if(-not $process.WaitForExit(5000)){ $process.Kill();$process.WaitForExit();throw 'Local version probe exceeded finite deadline' }
        if($process.ExitCode -ne 0 -or -not $output.Wait(1000) -or -not $errors.Wait(1000) -or $output.Result.Length -gt 4096){throw 'Local version probe unavailable'}
        return $output.Result.TrimEnd([char[]]"`r`n")
    }finally{$process.Dispose()}
}
function Capture-Counter([string]$ManifestPath,[string]$ExpectedHash) {
    if($ExpectedHash -cnotmatch '^[a-f0-9]{64}$'){throw 'Exact approved counter manifest digest required'}
    $stage=[IO.Directory]::GetParent([IO.Path]::GetFullPath($ManifestPath))
    if([IO.Path]::GetFileName($ManifestPath) -cne 'build.json'){throw 'Fixed counter build manifest required'}
    $ancestors=@();$cursor=$stage
    while($null -ne $cursor){$ancestors+=$cursor;$cursor=$cursor.Parent}
    foreach($ancestor in ($ancestors|Sort-Object {$_.FullName.Length})){
        $held=[GenerationCustody]::Hold($ancestor.FullName,$true,$false)
        try{[GenerationCustody]::AssertProtectedParent($held,($null -eq $ancestor.Parent));$script:locks.Add($held)}catch{$held.Dispose();throw}
    }
    $manifestBytes=Read-LockedBytes $ManifestPath
    if((Hash-Bytes $manifestBytes) -cne $ExpectedHash){throw 'Counter build manifest digest mismatch'}
    $m=[Text.Encoding]::UTF8.GetString($manifestBytes)|ConvertFrom-Json
    if($m.target -cne 'windows-amd64' -or $m.installed -isnot [bool] -or $m.installed -ne $false -or $m.counter_source_binding.schema -ne 1 -or $m.compiled_counter_source_binding.schema -ne 1){throw 'Unsupported counter qualification build'}
    $names=@('httpcounter.go','httpcounter_test.go','channel.go','channel_linux.go','channel_windows.go','channel_unsupported.go','channel_windows_test.go','windows_cli_fixture_test.go','native_fixture.ps1','pins.json')
    $expected=($names|Sort-Object)-join ','
    foreach($binding in @($m.counter_source_binding,$m.compiled_counter_source_binding)){
        if((@($binding.files.PSObject.Properties.Name|Sort-Object)-join ',') -cne $expected){throw 'Counter ten-input closure mismatch'}
    }
    $sourceDir=Join-Path $stage.FullName 'source'
    $script:locks.Add([GenerationCustody]::Hold($sourceDir,$true,$false))
    if((@(Get-ChildItem -LiteralPath $sourceDir -Force|ForEach-Object Name|Sort-Object)-join ',') -cne $expected){throw 'Counter auxiliary source closure mismatch'}
    $pins=$null;$bindingText=[Text.StringBuilder]::new()
    foreach($name in ($names|Sort-Object)){
        $bytes=Read-LockedBytes (Join-Path $sourceDir $name);$hash=Hash-Bytes $bytes
        if($hash -cne $m.counter_source_binding.files.$name -or $hash -cne $m.compiled_counter_source_binding.files.$name){throw 'Counter source/compiled binding mismatch'}
        [void]$bindingText.Append($name).Append([char]0).Append($hash).Append("`n")
        if($name -ceq 'pins.json'){$pins=[Text.Encoding]::UTF8.GetString($bytes)|ConvertFrom-Json}
    }
    $version=[string]$m.pins.upstream_version
    if($version -cnotmatch '^[0-9]+\.[0-9]+\.[0-9]+$'){throw 'Unknown counter runtime version'}
    $profile=$pins.profiles.PSObject.Properties[$version]
    if($null -eq $profile -or $profile.Value.profile_kind -cne 'runtime'){throw 'Counter runtime profile required'}
    foreach($key in @('upstream_commit','source_sha256','api_constructor_hooks','detached_telemetry','profile_kind')){
        if($m.pins.$key -cne $profile.Value.$key){throw 'Counter runtime profile binding mismatch'}
    }
    if($m.pins.toolchain_sha256 -cne $pins.toolchain_sha256){throw 'Counter toolchain binding mismatch'}
    $image=Read-LockedBytes (Join-Path $stage.FullName 'gh-instrumented.exe')
    $imageHash=Hash-Bytes $image
    if($imageHash -cne $m.artifacts.instrumented.sha256 -or $image.Length -lt 128 -or $image[0] -ne 77 -or $image[1] -ne 90){throw 'Counter image digest/PE mismatch'}
    $pe=[BitConverter]::ToInt32($image,60)
    if($pe -lt 64 -or $pe -gt ($image.Length-6) -or [BitConverter]::ToUInt32($image,$pe) -ne 17744 -or [BitConverter]::ToUInt16($image,$pe+4) -ne 34404){throw 'Counter image must be PE amd64'}
    # Resolve the same Bash PATH used by ordinary ai-gh, then hold the actual
    # vendor image during its local version check. No request or credential read.
    $ordinary=Local-OnlyProbe $script:installedBash @('-c','p=$(type -P gh); test -n "$p" && cygpath -w "$p"')
    if(-not [IO.Path]::IsPathRooted($ordinary)){throw 'Ordinary native gh image unavailable'}
    $cursor=[IO.Directory]::GetParent($ordinary)
    $officialParents=@()
    while($null -ne $cursor){$officialParents+=$cursor;$cursor=$cursor.Parent}
    foreach($ancestor in ($officialParents|Sort-Object {$_.FullName.Length})){
        $held=[GenerationCustody]::Hold($ancestor.FullName,$true,$false)
        try{[GenerationCustody]::AssertProtectedParent($held,($null -eq $ancestor.Parent));$script:locks.Add($held)}catch{$held.Dispose();throw}
    }
    $official=Read-LockedBytes $ordinary
    $actualVersion=Local-OnlyProbe $ordinary @('--version')
    if($actualVersion -cnotmatch ('^gh version '+[regex]::Escape($version)+'(?: |\r?\n|$)')){throw 'Counter version differs from actual ordinary gh'}
    return @{bytes=$image;binding=@{schema=1;manifest_sha256=$ExpectedHash;image_sha256=$imageHash;counter_source_fingerprint=(Hash-Bytes ([Text.Encoding]::UTF8.GetBytes($bindingText.ToString())));runtime_version=$version;ordinary_image_sha256=(Hash-Bytes $official);closure_entry='extra/counter.exe';scope='primary_constructor_subset';http_requests=$null;graphql_operations=$null;qualification_only=$true}}
}
function Assert-ReadArguments([string]$Entry,[object[]]$Values) {
    if ($Entry -eq 'bin/ai-pr-wait') {
        if ($Values.Count -eq 1 -and $Values[0] -eq '--help') { return }
        if ($Values.Count -lt 3 -or $Values[0] -notmatch '^[1-9][0-9]*$') { throw 'Restricted read profile requires one public PR wait' }
        $repo = $false
        for ($i=1;$i -lt $Values.Count;$i++) {
            if ($Values[$i] -eq '--fit-tool-call') { continue }
            if ($Values[$i] -eq '--repo') { $i++;if ($i -ge $Values.Count -or $Values[$i] -ne 'popcre/ai-devops') { throw 'Restricted read repository refused' };$repo=$true;continue }
            if ($Values[$i] -notin @('--timeout-minutes','--interval','--api-timeout-seconds')) { throw 'Restricted read option refused' }
            $i++;if ($i -ge $Values.Count -or $Values[$i] -notmatch '^[1-9][0-9]{0,3}$') { throw 'Restricted read deadline refused' }
        }
        if (-not $repo) { throw 'Explicit public repository required for restricted read' }
        return
    }
    if ($Values.Count -ne 7 -or $Values[0] -notin @('issue','pr') -or $Values[1] -ne 'view' -or
        $Values[2] -notmatch '^[1-9][0-9]*$' -or $Values[3] -ne '--repo' -or $Values[4] -ne 'popcre/ai-devops' -or
        $Values[5] -ne '--json' -or $Values[6] -notmatch '^(number|state|title|url|mergedAt|closedAt|updatedAt)(,(number|state|title|url|mergedAt|closedAt|updatedAt))*$') { throw 'Restricted read profile requires fixed public issue or PR view' }
}
function Test-ObserverEvent([string]$Text) {
    if (-not $Text -or [Text.Encoding]::UTF8.GetByteCount($Text) -gt 4096) { return $false }
    $keys=@('schema','utc','measurement','caller','workflow','workflow_id','cohort_id','target_ordinal','source_verified','source_fingerprint_start','source_fingerprint_end','install_generation_binding','event_kind','eligible_utc_ms','observed_utc_ms','delivered_utc_ms','delivery_boundary','clock_quality','clock_error_bound_ms','latency_ms','unknown_reason')
    # All accepted values are simple fixed labels, IDs, numbers or null. This
    # strict key scan also rejects duplicate/escaped keys before JSON coercion.
    $matches=[regex]::Matches($Text,'"([A-Za-z_]+)"\s*:')
    if ($matches.Count -ne $keys.Count) { return $false }
    $seen=@{}
    foreach ($match in $matches) { $key=$match.Groups[1].Value;if($key -cnotin $keys -or $seen.ContainsKey($key)){return $false};$seen[$key]=$true }
    try {
        $parser=Get-Command Microsoft.PowerShell.Utility\ConvertFrom-Json -ErrorAction Stop
        if($parser.Parameters.ContainsKey('DateKind')){$e=$Text|Microsoft.PowerShell.Utility\ConvertFrom-Json -DateKind String}
        else{$e=$Text|Microsoft.PowerShell.Utility\ConvertFrom-Json}
    }catch{return $false}
    if (@($e.PSObject.Properties).Count -ne $keys.Count -or ($e.schema -isnot [int] -and $e.schema -isnot [long]) -or $e.schema -ne 4 -or
        $e.utc -isnot [string] -or
        $e.utc -notmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$' -or $e.measurement -cne 'workflow_evidence' -or
        $e.caller -cne 'ai-pr-wait' -or $e.workflow -cne 'pr_wait' -or $e.workflow_id -notmatch '^[a-f0-9]{32}$' -or
        ($null -ne $e.cohort_id -and $e.cohort_id -notmatch '^[a-f0-9]{32}$') -or
        ($null -ne $e.target_ordinal -and (($e.target_ordinal -isnot [int] -and $e.target_ordinal -isnot [long]) -or $e.target_ordinal -lt 1 -or $e.target_ordinal -gt 1000000000)) -or
        $e.source_verified -cne 'unknown' -or $e.clock_quality -cne 'unknown' -or
        $e.event_kind -cnotin @('pr_merged','pr_closed','check_completed','unknown') -or
        $e.delivery_boundary -cnotin @('terminal_report','unknown') -or
        $e.unknown_reason -cnotin @('metadata_absent','metadata_untrusted','source_unknown','source_changed','event_unknown','event_invalid','clock_unknown','clock_jump','clock_negative','delivery_unknown')) { return $false }
    $parsedUtc=[datetime]::MinValue
    if(-not [datetime]::TryParseExact($e.utc,"yyyy-MM-dd'T'HH:mm:ss'Z'",[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::None,[ref]$parsedUtc)){return $false}
    foreach ($key in @('source_fingerprint_start','source_fingerprint_end','install_generation_binding','clock_error_bound_ms','latency_ms')) { if($null -ne $e.$key){return $false} }
    foreach ($key in @('eligible_utc_ms','observed_utc_ms','delivered_utc_ms')) { $value=$e.$key;if($null -ne $value -and (($value -isnot [int] -and $value -isnot [long]) -or $value -lt 0 -or $value -gt 9999999999999)){return $false} }
    if (($e.event_kind -eq 'unknown') -ne ($null -eq $e.eligible_utc_ms)) { return $false }
    if ($null -ne $e.eligible_utc_ms -and ($null -eq $e.observed_utc_ms -or $e.eligible_utc_ms -gt $e.observed_utc_ms)) { return $false }
    if ($e.delivery_boundary -eq 'terminal_report' -and ($null -eq $e.observed_utc_ms -or $null -eq $e.delivered_utc_ms -or $e.delivered_utc_ms -lt $e.observed_utc_ms)) { return $false }
    return $true
}
try {
    $receipt = [GenerationCustody]::Pipe($ReceiptHandle,[IO.FileAccess]::Write)
    $ack = [GenerationCustody]::Pipe($ReceiptAckHandle,[IO.FileAccess]::Read)
    if($PSCmdlet.ParameterSetName -ceq 'Inline'){
        if($ArgumentsBase64.Length -gt 10924){throw 'Bounded argument JSON required'}
        $argumentBytes=[Convert]::FromBase64String($ArgumentsBase64)
    }else{
        $argumentPath=[IO.Path]::GetFullPath($ArgumentsFile)
        $parents=@();$cursor=[IO.Directory]::GetParent($argumentPath)
        while($null -ne $cursor){$parents+=$cursor;$cursor=$cursor.Parent}
        foreach($parent in ($parents|Sort-Object {$_.FullName.Length})){
            $held=[GenerationCustody]::Hold($parent.FullName,$true,$false)
            try{[GenerationCustody]::AssertProtectedParent($held,($null -eq $parent.Parent));$locks.Add($held)}catch{$held.Dispose();throw}
        }
        $argumentHold=[GenerationCustody]::Hold($argumentPath,$false,$true);$locks.Add($argumentHold)
        $argumentBytes=[GenerationCustody]::Read($argumentHold,8192)
    }
    if($argumentBytes.Length -gt 8192){throw 'Bounded argument JSON required'}
    $argumentText = [Text.UTF8Encoding]::new($false,$true).GetString($argumentBytes)
    if (-not $argumentText.TrimStart().StartsWith('[')) { throw 'String argument array required' }
    $arguments = $argumentText | ConvertFrom-Json
    if ($null -eq $arguments) { $arguments = @() }
    foreach ($argument in $arguments) { if ($argument -isnot [string] -or $argument.Contains([char]0)) { throw 'String argument array required' } }
    if ($RestrictedReadProfile) { Assert-ReadArguments $EntryPoint @($arguments) }
    $countRequests=([bool]$CounterManifest -or [bool]$ExpectedCounterManifestSha256)
    $observeTransport=$ObserverEvents -or $countRequests
    if($countRequests){
        if(-not $CounterManifest -or -not $ExpectedCounterManifestSha256 -or -not $RestrictedReadProfile -or -not $ReadOnlyNoStdin -or $EntryPoint -cne 'bin/ai-gh' -or $ObserverEvents){throw 'Counter requires explicit restricted finite ai-gh read with no stdin'}
        Assert-CounterContext
        Assert-ConfigMetadata
    }
    if ($ObserverEvents -and (-not $RestrictedReadProfile -or -not $ReadOnlyNoStdin -or $EntryPoint -ne 'bin/ai-pr-wait')) { throw 'Observer requires explicit restricted PR read and no-stdin profile' }
    foreach ($key in @([Environment]::GetEnvironmentVariables().Keys)) {
        if (($key -in @('BASH_ENV','ENV','PYTHONPATH','PYTHONHOME','PYTHONSTARTUP') -or $key -like 'BASH_FUNC_*') -and [Environment]::GetEnvironmentVariable($key,'Process')) { throw 'Ambient source prevents generation qualification' }
    }
    # Pin and recheck existing ancestors BEFORE the source snapshot is created.
    $parents=@();$parent=$stagingParent
    while($null -ne $parent){$parents+=$parent;$parent=$parent.Parent}
    foreach($parent in ($parents|Sort-Object {$_.FullName.Length})){
        $heldParent=[GenerationCustody]::Hold($parent.FullName,$true,$false)
        try{[GenerationCustody]::AssertProtectedParent($heldParent,($null -eq $parent.Parent));$locks.Add($heldParent)}catch{$heldParent.Dispose();throw}
    }
    $root = [IO.Path]::GetFullPath($SourceRoot)
    $git = (Get-Command git.exe -ErrorAction Stop).Source
    $launcher = Join-Path $HOME '.local\bin\ai-task-gates.cmd'
    $launcherHold = [GenerationCustody]::Hold($launcher,$false,$true)
    $captureLocks.Add($launcherHold)
    $launcherBytes = [GenerationCustody]::Read($launcherHold)
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
    $gate = [GenerationCustody]::Hold((Join-Path $root 'bin\ai-task-gates'),$false,$true)
    $captureLocks.Add($gate)
    $target = [GenerationCustody]::Hold($gatePath,$false,$true)
    $captureLocks.Add($target)
    if (-not [GenerationCustody]::Same($gate,$target)) { throw 'Installed source root mismatch' }
    if ((Git-Text @('rev-parse','HEAD')) -ne $sourceSha -or (Git-Text @('status','--porcelain','--untracked-files=no'))) { throw 'Installed source generation mismatch' }
    $gateBytes = [GenerationCustody]::Read($gate)
    if ((Hash-Bytes $gateBytes) -ne $gateHash -or (Git-BlobHash $gateBytes) -ne (Git-Text @('rev-parse',($sourceSha+':bin/ai-task-gates')))) { throw 'Installed gate receipt mismatch' }
    foreach ($capture in $captureLocks) { $capture.Dispose() };$captureLocks.Clear()
    if (-not $BashExe) { $BashExe = $installedBash }
    $interpreter = [GenerationCustody]::Hold($BashExe,$false,$true)
    $expectedInterpreter = [GenerationCustody]::Hold($installedBash,$false,$true)
    if (-not [GenerationCustody]::Same($interpreter,$expectedInterpreter)) { throw 'Managed interpreter mismatch' }
    $locks.Add($interpreter);$locks.Add($expectedInterpreter)
    $snapshot = Join-Path $stagingParent.FullName ('ai-gh-generation-'+$PID+'-'+[Guid]::NewGuid().ToString('N'))
    [GenerationCustody]::PrivateDirectory($snapshot)
    # This fresh protected object's identity is held throughout materialization,
    # receipt capture and sealing; no replaceable pathname is adopted later.
    $locks.Add([GenerationCustody]::Hold($snapshot,$true,$false))
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
    $closurePaths=@($paths)
    if($countRequests){
        $capturedCounter=Capture-Counter $CounterManifest $ExpectedCounterManifestSha256
        $counterBinding=$capturedCounter.binding
        $extra=Join-Path $snapshot 'extra'
        [void][IO.Directory]::CreateDirectory($extra)
        [IO.File]::WriteAllBytes((Join-Path $extra 'counter.exe'),$capturedCounter.bytes)
        $counterHold=[GenerationCustody]::Hold((Join-Path $extra 'counter.exe'),$false,$true)
        $locks.Add($counterHold)
        if((Hash-Bytes ([GenerationCustody]::Read($counterHold))) -cne $counterBinding.image_sha256){throw 'Private counter image copy mismatch'}
        $closurePaths+='extra/counter.exe'
    }
    # Freeze only the private generation. Canonical files stay writable.
    $ancestors = @()
    $ancestor = [IO.Directory]::GetParent($snapshot)
    while ($null -ne $ancestor) { $ancestors += $ancestor; $ancestor = $ancestor.Parent }
    $directories = @($ancestors) + @((Get-Item -LiteralPath $snapshot)) + @(Get-ChildItem -LiteralPath $snapshot -Directory -Recurse -Force)
    foreach ($directory in ($directories | Sort-Object { $_.FullName.Length })) { $locks.Add([GenerationCustody]::Hold($directory.FullName,$true,$false)) }
    $snapshotDirectories = @((Get-Item -LiteralPath $snapshot)) + @(Get-ChildItem -LiteralPath $snapshot -Directory -Recurse -Force)
    foreach ($directory in $snapshotDirectories) { $directoryControls.Add([GenerationCustody]::DirectoryControl($directory.FullName)) }
    foreach ($control in $directoryControls) { [GenerationCustody]::DirectoryAccess($control,$false) }
    [GenerationCustody]::AssertClosure($snapshot,[string[]]$closurePaths)
    $manifest = [Text.StringBuilder]::new()
    foreach ($relative in $paths) {
        if ($relative -notmatch '^(bin|tools|config)/[A-Za-z0-9_./ -]+$' -or $relative -match '(^|/)\.\.(/|$)') { throw 'Unexpected generation path' }
        $path = Join-Path $snapshot $relative
        $locks.Add([GenerationCustody]::Hold($path,$false,$true))
        $sourceBytes = [IO.File]::ReadAllBytes($path)
        if ((Git-BlobHash $sourceBytes) -ne $blobs[$relative]) { throw ('Snapshot differs from installed Git generation: '+$relative) }
        [void]$manifest.Append($relative).Append([char]0).Append((Hash-Bytes $sourceBytes)).Append("`n")
    }
    $privilegedOriginal = [GenerationCustody]::PrivilegedContext()
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $BashExe
    $start.UseShellExecute = $false
    $start.WorkingDirectory = (Get-Location).ProviderPath
    $commandArguments = @((Bash-Path (Join-Path $snapshot $EntryPoint))) + @($arguments)
    $start.Arguments = (($commandArguments | ForEach-Object { [GenerationCustody]::Quote($_) }) -join ' ')
    $job = [GenerationCustody]::Job()
    $locks.Add($job)
    $fingerprint = Hash-Bytes ([Text.Encoding]::UTF8.GetBytes($manifest.ToString()))
    $observerRun = if ($observeTransport) {[Guid]::NewGuid().ToString('N')}else{$null}
    $controlByte = New-Object byte[] 1
    $controlRead = if ($observeTransport) {$ack.ReadAsync($controlByte,0,1)}else{$null}
    if($observeTransport -and $controlRead.IsCompleted){throw [OperationCanceledException]::new('Observer control closed before child launch')}
    $savedEventHandle=[Environment]::GetEnvironmentVariable('AI_GH_QUALIFICATION_EVENT_HANDLE','Process')
    $counterEnvironment=@{}
    try {
        if($countRequests){
            $counterChannel=[GenerationCustody+EventChannel]::new(128)
            $childCounter=@{AI_GH_REAL_GH=(Bash-Path (Join-Path $snapshot 'extra/counter.exe'));GH_PATH=(Join-Path $snapshot 'extra/counter.exe');AI_GH_HTTP_COUNTER_HANDLE=[string]$counterChannel.WriteHandle;AI_GH_HTTP_COUNTER_HOST='api.github.com'}
            foreach($key in $childCounter.Keys){$counterEnvironment[$key]=[Environment]::GetEnvironmentVariable($key,'Process');[Environment]::SetEnvironmentVariable($key,$childCounter[$key],'Process')}
        }
        if ($ObserverEvents) {
            try {$eventChannel=[GenerationCustody+EventChannel]::new()}catch{$eventChannel=$null}
            $wireHandle=if($null -ne $eventChannel){[string]$eventChannel.WriteHandle}else{$null}
            [Environment]::SetEnvironmentVariable('AI_GH_QUALIFICATION_EVENT_HANDLE',$wireHandle,'Process')
        }
        $child = [GenerationCustody]::Start($job,$start.FileName,$start.Arguments,$start.WorkingDirectory,[bool]$RestrictedReadProfile,[bool]$ReadOnlyNoStdin)
    } finally {
        [Environment]::SetEnvironmentVariable('AI_GH_QUALIFICATION_EVENT_HANDLE',$savedEventHandle,'Process')
        foreach($key in $counterEnvironment.Keys){[Environment]::SetEnvironmentVariable($key,$counterEnvironment[$key],'Process')}
    }
    if ($observeTransport) {
        $started=@{schema=1;frame='started';observer_run_id=$observerRun;observer_arguments_sha256=(Hash-Bytes $argumentBytes);source_sha=$sourceSha;source_fingerprint=$fingerprint;source_scope='git_raw_bin_tools_config_v1';execution_profile='restricted_read';stdin_profile='read_only_no_stdin';start_boundary='process_resumed'}
        $startedBytes=[Text.Encoding]::UTF8.GetBytes((($started|ConvertTo-Json -Compress)+"`n"));$receipt.Write($startedBytes,0,$startedBytes.Length);$receipt.Flush()
        while (-not $child.WaitForExit(20)) {
            if($controlRead.IsCompleted){throw [OperationCanceledException]::new('Observer control closed before terminal delivery')}
            if($null -ne $eventChannel){$eventChannel.Drain()}
            if($null -ne $counterChannel){$counterChannel.Drain()}
        }
        if($null -ne $eventChannel){$eventChannel.Drain()}
        if($null -ne $counterChannel){$counterChannel.Drain()}
    } else { $child.WaitForExit() }
    $exitCode = $child.ExitCode
    $verified = $RestrictedReadProfile -or -not $privilegedOriginal
    $reason = if ($verified) {'none'} else {'boundary_unavailable'}
    $detail = if ($verified) {'none'} else {'privileged_original_context'}
    $profile = if ($RestrictedReadProfile) {'restricted_read'} else {'original'}
    $record = [ordered]@{schema=1;source_sha=$sourceSha;source_fingerprint=$fingerprint;loaded_source_fingerprint=$fingerprint;source_scope='git_raw_bin_tools_config_v1';install_generation_binding=(Hash-Bytes $launcherBytes);source_boundary='windows_locked_generation';child_exit=$exitCode;source_verified=$(if($verified){'verified'}else{'unknown'});unknown_reason=$reason;boundary_detail=$detail;execution_profile=$profile;clock_quality='unknown';clock_error_bound_ms=$null}
    if ($observeTransport) {
        $eventText=if($null -ne $eventChannel){$eventChannel.EventText()}else{$null}
        $record['observer_run_id']=$observerRun
        $record['observer_arguments_sha256']=Hash-Bytes $argumentBytes
        $record['stdin_profile']='read_only_no_stdin'
        $record['start_boundary']='process_resumed'
        $record['observer_event_json']=if(Test-ObserverEvent $eventText){$eventText}else{$null}
        $record['observer_event_status']=if($record['observer_event_json']){'received'}elseif($null -eq $eventChannel -or $eventChannel.Status -eq 'unavailable'){'unavailable'}else{'invalid'}
        if($countRequests){$record['counter_binding']=$counterBinding;$record['counter_raw']=$counterChannel.CounterText()}
    }
    $bytes = [Text.Encoding]::UTF8.GetBytes((($record | ConvertTo-Json -Compress)+"`n"))
    $receipt.Write($bytes,0,$bytes.Length);$receipt.Flush()
    # Receipt is consumed before custody ends, never certified by a later file.
    if (-not $observeTransport) {$controlRead=$ack.ReadAsync($controlByte,0,1)}
    if ($controlRead.Wait(30000) -and $controlRead.Result -eq 0) { throw [OperationCanceledException]::new('Observer control closed') }
    if (-not $controlRead.IsCompleted -or $controlRead.Result -ne 1 -or $controlByte[0] -ne 1) { throw 'Parent did not acknowledge source custody receipt' }
} catch [OperationCanceledException] {
    $exitCode=130
    $cancelled=$true
    $primaryFailure=$_
} catch {
    $primaryFailure=$_
} finally {
    $cleanupErrors=Close-OwnedGeneration @{Job=$job;Child=$child;EventChannel=$eventChannel;CounterChannel=$counterChannel;CaptureLocks=$captureLocks;DirectoryControls=$directoryControls;Locks=$locks;Receipt=$receipt;Ack=$ack;Snapshot=$snapshot;Bootstrap=$(if($bootstrap){$bootstrap.FullName}else{$null})}
    foreach($failure in $cleanupErrors){
        Write-Error ('Owned generation cleanup failed at '+$failure.phase) -ErrorAction Continue
        Write-Error -ErrorRecord $failure.error -ErrorAction Continue
    }
    if($cleanupErrors.Count -gt 0 -and $exitCode -eq 0){$exitCode=125}
}
if($primaryFailure -and -not $cancelled){throw $primaryFailure}
exit $exitCode
