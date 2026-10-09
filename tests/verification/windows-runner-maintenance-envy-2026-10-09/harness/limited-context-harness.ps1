$ErrorActionPreference='Stop'
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public class LimP {
  [DllImport("kernel32.dll", SetLastError=true)] public static extern IntPtr OpenProcess(uint a, bool inh, int pid);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool CloseHandle(IntPtr h);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern uint WaitForSingleObject(IntPtr h, uint ms);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool GetExitCodeProcess(IntPtr h, out uint code);
  [DllImport("advapi32.dll", SetLastError=true)] public static extern bool OpenProcessToken(IntPtr h, uint a, out IntPtr t);
  [DllImport("advapi32.dll", SetLastError=true)] public static extern bool DuplicateTokenEx(IntPtr h, uint access, IntPtr attr, int imp, int type, out IntPtr nt);
  [DllImport("advapi32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
  public static extern bool CreateProcessWithTokenW(IntPtr tok, uint f, string app, StringBuilder cmd, uint cf, IntPtr env, string dir, ref SI si, out PI pi);
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
  public struct SI { public int cb; public string lpReserved; public string lpDesktop; public string lpTitle;
    public int dwX; public int dwY; public int dwXSize; public int dwYSize; public int dwXCountChars; public int dwYCountChars;
    public int dwFillAttribute; public int dwFlags; public int wShowWindow; public short cbReserved2; public IntPtr lpReserved2;
    public IntPtr hStdInput; public IntPtr hStdOutput; public IntPtr hStdError; }
  [StructLayout(LayoutKind.Sequential)] public struct PI { public IntPtr hProcess; public IntPtr hThread; public int dwProcessId; public int dwThreadId; }
  public static string LastDetail = "";
  public static int RunLimited(int pid, string app, string cmdline, int waitMs) {
    IntPtr proc = OpenProcess(0x1000, false, pid);
    if (proc == IntPtr.Zero) return 6000 + Marshal.GetLastWin32Error();
    IntPtr tok;
    if (!OpenProcessToken(proc, 0x018B, out tok)) { int e = Marshal.GetLastWin32Error(); CloseHandle(proc); return 7000 + e; }
    CloseHandle(proc);
    IntPtr prim;
    if (!DuplicateTokenEx(tok, 0x018B, IntPtr.Zero, 2, 1, out prim)) {
      int de = Marshal.GetLastWin32Error(); LastDetail = "dup-err=" + de; CloseHandle(tok); return 8000 + (de % 900);
    }
    CloseHandle(tok);
    SI si = new SI(); si.cb = Marshal.SizeOf(typeof(SI)); si.dwFlags = 1; si.wShowWindow = 0;
    PI pi;
    if (CreateProcessWithTokenW(prim, 0, app, new StringBuilder(cmdline), 0, IntPtr.Zero, null, ref si, out pi)) {
      LastDetail = "spawn-ok pid=" + pi.dwProcessId;
      CloseHandle(pi.hThread);
      WaitForSingleObject(pi.hProcess, (uint)waitMs);
      uint code; GetExitCodeProcess(pi.hProcess, out code); CloseHandle(pi.hProcess); CloseHandle(prim);
      return (int)code;
    }
    int w = Marshal.GetLastWin32Error();
    LastDetail = "spawn-err=" + w;
    CloseHandle(prim);
    return 9000 + (w % 900);
  }
}
'@
if ($env:COMPUTERNAME -ne 'EDGE-RUNN-ENVY') { throw 'wrong host' }
$repo='C:\repos\ai-devops'
$pwsh7='C:\Program Files\PowerShell\7\pwsh.exe'
# A. read-only verify from a fresh session (elevated context accepted by reviewer)
$v=& $pwsh7 -NoProfile -File (Join-Path $repo 'bin\install-windows-runner-maintenance.ps1') -Verify -OperatorUser "$env:COMPUTERNAME\ahazan" 2>&1 | Out-String
$vrc=$LASTEXITCODE
Write-Output ("VERIFY_RC=" + $vrc + " OUT=" + (($v -replace '\s+',' ').Trim()))
if ($vrc -ne 0) { throw 'verify failed' }
# B. service baseline compare
$pre=Get-Content -LiteralPath (Join-Path $env:TEMP 'envy-service-preinstall.txt') -Raw
$svc=Get-CimInstance Win32_Service -Filter "Name='actions.runner.popcre-ai-devops.EDGE-RUNN-ENVY'"
$post='name=' + $svc.Name + '|state=' + $svc.State + '|startmode=' + $svc.StartMode + '|startname=' + $svc.StartName
Write-Output ("SERVICE_PRE=" + $pre.Trim())
Write-Output ("SERVICE_POST=" + $post)
Write-Output ("SERVICE_UNCHANGED=" + ($post.Trim() -eq $pre.Trim()))
# C. evidence timestamp before (metadata only, content never read)
$evFile='C:\ProgramData\ai-devops\windows-runner-security.json'
$evB=(Get-Item -LiteralPath $evFile).LastWriteTimeUtc.ToString('o')
Write-Output ("EVIDENCE_MTIME_PRE_INVOKE=" + $evB)
# D. run the non-elevated proof suite in a proven limited operator context
$negPath=Join-Path $env:TEMP 'negproof.ps1'
$negOut=Join-Path $env:TEMP 'envy-negproof.txt'
Remove-Item -LiteralPath $negOut -ErrorAction SilentlyContinue
$exp=Get-Process explorer -ErrorAction SilentlyContinue | Where-Object { $_.SessionId -gt 0 } | Select-Object -First 1
if (-not $exp) { throw 'no interactive explorer token source available' }
$cl='"' + $pwsh7 + '" -NoProfile -ExecutionPolicy Bypass -File "' + $negPath + '"'
$rc=[LimP]::RunLimited($exp.Id, $pwsh7, $cl, 300000)
Write-Output ("LIMITED_CHILD_RC=" + $rc + " DETAIL=" + [LimP]::LastDetail)
# E. transcript
$deadline=(Get-Date).AddSeconds(20)
while ((Get-Date) -lt $deadline) { if (Test-Path -LiteralPath $negOut) { break }; Start-Sleep -Seconds 1 }
if (Test-Path -LiteralPath $negOut) {
  Get-Content -LiteralPath $negOut | ForEach-Object { Write-Output ("PROOF " + $_) }
  $g=Join-Path $env:TEMP 'envy-negproof-groups.txt'
  if (Test-Path -LiteralPath $g) {
    Get-Content -LiteralPath $g | Where-Object { $_ -match 'Mandatory Label|BUILTIN\\Administrators|DENY|deny' } | ForEach-Object { Write-Output ("GROUPS " + $_.Trim()) }
  }
} else { Write-Output 'PROOF_TRANSCRIPT_MISSING' }
# F. evidence timestamp after
$evA=(Get-Item -LiteralPath $evFile).LastWriteTimeUtc.ToString('o')
Write-Output ("EVIDENCE_MTIME_POST_INVOKE=" + $evA)
Write-Output ("EVIDENCE_ADVANCED=" + ($evA -gt $evB))
# G. task still healthy
& schtasks.exe /query /tn '\AiDevOps\WindowsRunnerMaintenance' *> $null
Write-Output ("TASK_STILL_PRESENT_RC=" + $LASTEXITCODE)
$svc2=Get-CimInstance Win32_Service -Filter "Name='actions.runner.popcre-ai-devops.EDGE-RUNN-ENVY'"
$post2='name=' + $svc2.Name + '|state=' + $svc2.State + '|startmode=' + $svc2.StartMode + '|startname=' + $svc2.StartName
Write-Output ("SERVICE_FINAL_UNCHANGED=" + ($post2 -eq $pre.Trim()))
