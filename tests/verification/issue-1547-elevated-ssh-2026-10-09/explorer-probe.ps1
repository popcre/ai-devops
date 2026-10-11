$ProgressPreference='SilentlyContinue'
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class TK3 {
  [DllImport("advapi32.dll", SetLastError=true)] public static extern bool OpenProcessToken(IntPtr p, int acc, out IntPtr t);
  [DllImport("advapi32.dll", SetLastError=true)] public static extern bool GetTokenInformation(IntPtr h, int cls, IntPtr buf, int len, out int need);
  [DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(int a, bool i, int pid);
  [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
}
'@
$ip=Get-Process explorer -ErrorAction SilentlyContinue | Select-Object -First 1
if($ip){
  $hproc=[TK3]::OpenProcess(0x1000,$false,$ip.Id)
  $ht=[IntPtr]::Zero
  [void][TK3]::OpenProcessToken($hproc,0x0008,[ref]$ht)
  $need=0
  $buf=[Runtime.InteropServices.Marshal]::AllocHGlobal(4)
  $elev='q-fail'
  if([TK3]::GetTokenInformation($ht,20,$buf,4,[ref]$need)){ $elev=[Runtime.InteropServices.Marshal]::ReadInt32($buf) }
  $etype='q-fail'
  if([TK3]::GetTokenInformation($ht,18,$buf,4,[ref]$need)){ $t=[Runtime.InteropServices.Marshal]::ReadInt32($buf); $etype=@{1='Default';2='Full';3='Limited'}[$t] }
  [Runtime.InteropServices.Marshal]::FreeHGlobal($buf)
  "EXPLORER_TOKEN elevated=$elev type=$etype pid=$($ip.Id)"
  [void][TK3]::CloseHandle($ht)
  [void][TK3]::CloseHandle($hproc)
} else { "EXPLORER_TOKEN none-running" }
$vs=Get-Item 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
"OS now: $($vs.GetValue('CurrentBuild')).$($vs.GetValue('UBR')) display=$($vs.GetValue('DisplayVersion'))"
"date_utc=$([DateTime]::UtcNow.ToString('yyyy-MM-dd HH:mmZ'))"
