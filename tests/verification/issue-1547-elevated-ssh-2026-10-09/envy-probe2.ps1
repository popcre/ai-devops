$ErrorActionPreference='SilentlyContinue'
$ProgressPreference='SilentlyContinue'
$out=New-Object System.Collections.Generic.List[string]
function K([string]$n,[string]$v){ [void]$script:out.Add("$n=$v") }
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class TK2 {
  [DllImport("advapi32.dll", SetLastError=true)]
  public static extern bool GetTokenInformation(IntPtr h, int cls, IntPtr buf, int len, out int need);
  [DllImport("advapi32.dll", SetLastError=true)]
  public static extern bool OpenProcessToken(IntPtr p, int acc, out IntPtr t);
  [DllImport("kernel32.dll")]
  public static extern IntPtr GetCurrentProcess();
}
'@
$h=[IntPtr]::Zero
[void][TK2]::OpenProcessToken([TK2]::GetCurrentProcess(), 0x0008, [ref]$h)
$need=0
$buf=[Runtime.InteropServices.Marshal]::AllocHGlobal(64)
if([TK2]::GetTokenInformation($h,10,$buf,64,[ref]$need)){
  $low=[Runtime.InteropServices.Marshal]::ReadInt32($buf,8)
  $high=[Runtime.InteropServices.Marshal]::ReadInt32($buf,12)
  K 'MY_AUTHLUID' ('{0:x}:{1:x}' -f $high,$low)
  K 'MY_AUTHLUID_LOW_DEC' "$low"
}
[Runtime.InteropServices.Marshal]::FreeHGlobal($buf)
$now=(Get-Date).ToUniversalTime()
$all=Get-CimInstance Win32_LogonSession -ErrorAction SilentlyContinue
K 'SESSION_COUNT' "$($all.Count)"
foreach($s in $all){
  $st=[datetime]$s.StartTime
  $age=[int]($now - $st.ToUniversalTime()).TotalSeconds
  if($age -lt 1800 -or [int]$s.LogonType -in 3,4,9){
    K 'SESS' ("id={0} type={1} pkg={2} age={3}s" -f $s.LogonId, $s.LogonType, $s.AuthenticationPackage, $age)
  }
}
# sshd file timestamps full
$f=Get-Item 'C:\Windows\System32\OpenSSH\sshd.exe'
K 'SSHD_CREATED' $f.CreationTimeUtc.ToString('yyyy-MM-dd HH:mm:ssZ')
K 'SSHD_WRITTEN' $f.LastWriteTimeUtc.ToString('yyyy-MM-dd HH:mm:ssZ')
# sshd service start time
$s2=Get-CimInstance Win32_Service -Filter "Name='sshd'"
K 'SSHD_SVC_STARTED' "$($s2.StartMode) state=$($s2.State) pid=$($s2.ProcessId)"
$out
