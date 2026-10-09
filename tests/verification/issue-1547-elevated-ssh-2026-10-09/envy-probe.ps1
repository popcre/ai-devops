$ErrorActionPreference='SilentlyContinue'
$ProgressPreference='SilentlyContinue'
$out=New-Object System.Collections.Generic.List[string]
function K([string]$n,[string]$v){ [void]$script:out.Add("$n=$v") }

# ---- identity of this SSH session's token ----
$id=[Security.Principal.WindowsIdentity]::GetCurrent()
K 'USER' $id.Name
K 'USER_SID' $id.User.Value
K 'AUTH_PACKAGE_IDENTITY' $id.AuthenticationType
$pr=New-Object Security.Principal.WindowsPrincipal($id)
K 'IS_IN_ADMINISTRATORS_ROLE' $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# ---- P/Invoke helpers ----
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class TK {
  [DllImport("advapi32.dll", SetLastError=true)]
  public static extern bool GetTokenInformation(IntPtr h, int cls, IntPtr buf, int len, out int need);
  [DllImport("advapi32.dll", SetLastError=true)]
  public static extern bool OpenProcessToken(IntPtr p, int acc, out IntPtr t);
  [DllImport("kernel32.dll")]
  public static extern IntPtr GetCurrentProcess();
  [StructLayout(LayoutKind.Sequential)]
  public struct LUID { public uint LowPart; public int HighPart; }
  [StructLayout(LayoutKind.Sequential)]
  public struct LSA_UNICODE_STRING { public ushort Length; public ushort MaximumLength; public IntPtr Buffer; }
  [StructLayout(LayoutKind.Sequential)]
  public struct LOGON_SESSION_DATA {
    public uint Size; public LUID LogonId;
    public LSA_UNICODE_STRING UserName; public LSA_UNICODE_STRING LogonDomain; public LSA_UNICODE_STRING AuthenticationPackage;
    public uint LogonType; public uint Session; public IntPtr Sid;
  }
  [DllImport("advapi32.dll")]
  public static extern int LsaGetLogonSessionData(ref LUID logonId, out IntPtr data);
}
'@ -ErrorAction SilentlyContinue

$h=[IntPtr]::Zero
[void][TK]::OpenProcessToken([TK]::GetCurrentProcess(), 0x0008, [ref]$h) # TOKEN_QUERY

# TokenElevationType (18): 1=Default 2=Full 3=Limited
$need=0
$buf=[Runtime.InteropServices.Marshal]::AllocHGlobal(4)
if([TK]::GetTokenInformation($h,18,$buf,4,[ref]$need)){
  $t=[Runtime.InteropServices.Marshal]::ReadInt32($buf)
  $tn=@{1='Default(no-split)';2='Full(elevated)';3='Limited(filtered)'}[$t]
  K 'TOKEN_ELEVATION_TYPE' "$t ($tn)"
} else { K 'TOKEN_ELEVATION_TYPE' "query-failed" }
# TokenElevation (20): TokenIsElevated
if([TK]::GetTokenInformation($h,20,$buf,4,[ref]$need)){
  K 'TOKEN_IS_ELEVATED' ([Runtime.InteropServices.Marshal]::ReadInt32($buf))
} else { K 'TOKEN_IS_ELEVATED' 'query-failed' }
# TokenLinkedToken (19)
$link=0
if([TK]::GetTokenInformation($h,19,$buf,4,[ref]$need)){
  K 'LINKED_TOKEN' 'present'
} else {
  $ec=[Runtime.InteropServices.Marshal]::GetLastWin32Error()
  K 'LINKED_TOKEN' "absent (GetLastError=$ec)"
}
# TokenStatistics (10): AuthenticationId (LUID) at offset 8
$need2=0
$buf2=[Runtime.InteropServices.Marshal]::AllocHGlobal(64)
$statsOk=[TK]::GetTokenInformation($h,10,$buf2,64,[ref]$need2)
$authLuid=''
if($statsOk){
  $low=[Runtime.InteropServices.Marshal]::ReadInt32($buf2,8)
  $high=[Runtime.InteropServices.Marshal]::ReadInt32($buf2,12)
  $authLuid = ('{0:x}:{1:x}' -f $high,$low)
  K 'AUTH_LUID' $authLuid
} else { K 'AUTH_LUID' 'query-failed' }
[Runtime.InteropServices.Marshal]::FreeHGlobal($buf)
[Runtime.InteropServices.Marshal]::FreeHGlobal($buf2)

# ---- logon session type via LSA ----
if($statsOk){
  $luid=[TK+LUID]::new()
  $luid.LowPart=[uint32]$low
  $luid.HighPart=$high
  $ptr=[IntPtr]::Zero
  $rc=0
  try { $rc=[TK]::LsaGetLogonSessionData([ref]$luid,[ref]$ptr) } catch { $rc=-1 }
  if($rc -eq 0 -and $ptr -ne [IntPtr]::Zero){
    $d=[Runtime.InteropServices.Marshal]::PtrToStructure($ptr,[type][TK+LOGON_SESSION_DATA])
    $ltName=@{2='Interactive';3='Network';4='Batch';5='Service';7='Unlock';8='NetworkCleartext';9='NewCredentials';10='RemoteInteractive';11='CachedInteractive'}[[int]$d.LogonType]
    K 'LOGON_TYPE' "$($d.LogonType) ($ltName)"
    K 'LOGON_SESSION_AUTH_PKG' ([Runtime.InteropServices.Marshal]::PtrToStringUni($d.AuthenticationPackage.Buffer, $d.AuthenticationPackage.Length/2))
    K 'LOGON_SESSION_USER' ([Runtime.InteropServices.Marshal]::PtrToStringUni($d.UserName.Buffer, $d.UserName.Length/2))
  } elseif($rc -eq 0){ K 'LOGON_TYPE' 'lsa-null-data' } else { K 'LOGON_TYPE' "lsa-rc=$rc" }
}

# ---- whoami: groups + integrity + privileges ----
$g = & whoami /groups 2>$null
foreach($line in $g){
  if($line -match 'S-1-5-32-544' -or $line -match 'Mandatory Label'){
    K 'WHOAMI_GROUP' (($line -replace '\s+',' ').Trim())
  }
}
$p = & whoami /priv 2>$null
$enabled = @($p | Where-Object { $_ -match '\sEnabled\s*$' })
K 'PRIV_ENABLED_COUNT' $enabled.Count
foreach($line in $p){ if($line -match 'SeDebugPrivilege|SeBackupPrivilege|SeTakeOwnershipPrivilege|SeShutdownPrivilege'){ K 'PRIV_SAMPLE' (($line -replace '\s+',' ').Trim()) } }

# ---- UAC / remote-filter policy state ----
$sp='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
foreach($v in 'EnableLUA','ConsentPromptBehaviorAdmin','PromptOnSecureDesktop','FilterAdministratorToken','LocalAccountTokenFilterPolicy','ValidateAdminCodeSignatures','EnableSecureUIAPaths'){
  $item=Get-ItemProperty -Path $sp -Name $v -ErrorAction SilentlyContinue
  if($null -ne $item){ K "POL_$v" (Get-ItemPropertyValue -Path $sp -Name $v -ErrorAction SilentlyContinue) }
  else { K "POL_$v" 'ABSENT' }
}
# policy-path variant sometimes used by GPO
$sp2='HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'
$lat=Get-ItemProperty -Path $sp2 -Name 'LocalAccountTokenFilterPolicy' -ErrorAction SilentlyContinue
if($null -ne $lat){ K 'POL2_LocalAccountTokenFilterPolicy' $lat.LocalAccountTokenFilterPolicy } else { K 'POL2_LocalAccountTokenFilterPolicy' 'ABSENT' }

# ---- OS facts ----
$ntv='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
K 'OS_PRODUCT' (Get-ItemPropertyValue $ntv 'ProductName' -ErrorAction SilentlyContinue)
K 'OS_DISPLAY' (Get-ItemPropertyValue $ntv 'DisplayVersion' -ErrorAction SilentlyContinue)
K 'OS_BUILDTAG' ((Get-ItemPropertyValue $ntv 'CurrentBuild' -ErrorAction SilentlyContinue) + '.' + (Get-ItemPropertyValue $ntv 'UBR' -ErrorAction SilentlyContinue))
K 'OS_INSTALLDATE' ([DateTimeOffset]::FromUnixTimeSeconds((Get-ItemPropertyValue $ntv 'InstallDate' -ErrorAction SilentlyContinue)).UtcDateTime.ToString('yyyy-MM-dd HH:mmZ'))
$os=Get-CimInstance Win32_OperatingSystem
K 'OS_CAPTION' $os.Caption
K 'LAST_BOOT' $os.LastBootUpTime.ToUniversalTime().ToString('yyyy-MM-dd HH:mmZ')

# ---- account ----
$u=Get-LocalUser -Name 'ahazan' -ErrorAction SilentlyContinue
if($u){ K 'AHAZAN_SID' $u.SID.Value; K 'AHAZAN_ENABLED' $u.Enabled } else { K 'AHAZAN' 'lookup-failed' }
$adm=Get-LocalGroupMember -Group 'Administrators' -ErrorAction SilentlyContinue
K 'ADMIN_GROUP_MEMBERS' (($adm | ForEach-Object { $_.Name + '[' + $_.SID.Value + ']' }) -join '; ')

# ---- sshd facts ----
$svc=Get-Service sshd -ErrorAction SilentlyContinue
if($svc){ K 'SSHD_SVC' "$($svc.Status)/$($svc.StartType)" }
$bin=(Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\sshd' -Name ImagePath -ErrorAction SilentlyContinue).ImagePath
K 'SSHD_IMAGEPATH' $bin
$exe='C:\Windows\System32\OpenSSH\sshd.exe'
if(Test-Path $exe){
  $f=Get-Item $exe
  K 'SSHD_FILE' ($f.VersionInfo.ProductVersion + ' filever=' + $f.VersionInfo.FileVersion + ' created=' + $f.CreationTimeUtc.ToString('yyyy-MM-dd') + ' written=' + $f.LastWriteTimeUtc.ToString('yyyy-MM-dd'))
}
$lst=Get-NetTCPConnection -LocalPort 22 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
if($lst){
  K 'PORT22_PID' $lst.OwningProcess
  $pp=Get-Process -Id $lst.OwningProcess -ErrorAction SilentlyContinue
  if($pp){ K 'PORT22_PROCEXE' $pp.Path }
}
# non-comment sshd_config lines
$cfg='C:\ProgramData\ssh\sshd_config'
if(Test-Path $cfg){
  $lines=Get-Content $cfg -ErrorAction SilentlyContinue | Where-Object { $_ -match '\S' -and $_ -notmatch '^\s*#' }
  K 'SSHD_CONFIG_LINES' ($lines -join ' | ')
}
# OpenSSH capability provenance
$cap=Get-WindowsCapability -Online -Name 'OpenSSH.Server*' -ErrorAction SilentlyContinue
if($cap){ K 'SSHD_CAPABILITY' ($cap.Name + ' state=' + $cap.State + ' version=' + $cap.Version) } else { K 'SSHD_CAPABILITY' 'unavailable' }
# sudo feature
$feat=Get-WindowsOptionalFeature -Online -FeatureName 'sudo' -ErrorAction SilentlyContinue
if($feat){ K 'SUDO_FEATURE' $feat.State } else { K 'SUDO_FEATURE' 'unavailable' }

# ---- update history (what changed Sep 3 -> Oct 10) ----
$hf = Get-HotFix -ErrorAction SilentlyContinue | Sort-Object InstalledOn | Select-Object -Last 6
K 'HOTFIX_LAST' (($hf | ForEach-Object { $_.HotFixID + '@' + ([datetime]$_.InstalledOn).ToString('yyyy-MM-dd') }) -join ', ')
$wu=Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-WindowsUpdateClient/Operational'; Id=19,43; StartTime=[datetime]'2026-08-25T00:00:00'} -MaxEvents 12 -ErrorAction SilentlyContinue
K 'WU_INSTALL_EVENTS' (($wu | ForEach-Object { $_.TimeCreated.ToString('yyyy-MM-dd') + ':id' + $_.Id + ':' + ((($_.Message -split "`n")[0]).Trim()) }) -join ' || ')

# ---- interactive logons present? ----
$procs=Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq 'explorer' }
foreach($p2 in $procs){ $ow=Invoke-CimMethod -InputObject (Get-CimInstance Win32_Process -Filter "ProcessId=$($p2.Id)") -MethodName GetOwner; K 'EXPLORER_OWNER' "$($p2.Id) $($ow.Domain)\$($ow.User)" }
$q = & query user 2>$null
K 'SESSIONS' (($q | Select-Object -Skip 1) -join ' || ')

# ---- pending reboot markers (read-only) ----
K 'PENDING_REBOOT_COMPONENTS' "$([bool](Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentComponentBasedServicing\RebootPending'))"
K 'PENDING_REBOOT_WU' "$([bool](Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'))"
# OpenSSH default shell + sshd config file hash
$osh=Get-ItemProperty 'HKLM:\SOFTWARE\OpenSSH' -ErrorAction SilentlyContinue
K 'OPENSSH_DEFSHELL' "$(if($osh.DefaultShell){$osh.DefaultShell}else{'(unset)'})"
if(Test-Path $cfg){ K 'SSHD_CONFIG_SHA256' (Get-FileHash $cfg -Algorithm SHA256).Hash }

$out
