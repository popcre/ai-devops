# Run a Bash script inside a Windows job object that kills every member when
# this launcher's handle closes (JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE).
#
# Used by bin/ai-codex-review's desktop relay (popcre/ai-devops#1891). Job
# membership is inherited by every descendant, including processes started
# through Git Bash, whose Windows parent links are not reliable. So when this
# launcher ends for any reason (normal exit, schtasks /End, a crash), Windows
# itself terminates Codex and everything it started; nothing is found by PID.
param([Parameter(Mandatory)][string]$Bash, [Parameter(Mandatory)][string]$Script)
$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class AiDevOpsJob {
  [StructLayout(LayoutKind.Sequential)] struct BASIC { public long a, b; public uint LimitFlags; public UIntPtr c, d; public uint e; public UIntPtr f; public uint g, h; }
  [StructLayout(LayoutKind.Sequential)] struct IO { public ulong a, b, c, d, e, f; }
  [StructLayout(LayoutKind.Sequential)] struct EXTENDED { public BASIC Basic; public IO Io; public UIntPtr i, j, k, l; }
  [DllImport("kernel32.dll", SetLastError = true)] static extern IntPtr CreateJobObject(IntPtr a, string name);
  [DllImport("kernel32.dll", SetLastError = true)] static extern bool SetInformationJobObject(IntPtr job, int cls, ref EXTENDED info, int len);
  [DllImport("kernel32.dll", SetLastError = true)] static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);
  [DllImport("kernel32.dll")] static extern IntPtr GetCurrentProcess();
  public static IntPtr Enter() {
    IntPtr job = CreateJobObject(IntPtr.Zero, null);
    if (job == IntPtr.Zero) throw new System.ComponentModel.Win32Exception();
    EXTENDED info = new EXTENDED(); info.Basic.LimitFlags = 0x2000; // KILL_ON_JOB_CLOSE
    if (!SetInformationJobObject(job, 9, ref info, Marshal.SizeOf(typeof(EXTENDED)))) throw new System.ComponentModel.Win32Exception();
    if (!AssignProcessToJobObject(job, GetCurrentProcess())) throw new System.ComponentModel.Win32Exception();
    return job; // never closed explicitly: process exit closes it and kills the job
  }
}
'@

try { $script:job = [AiDevOpsJob]::Enter() } catch { [Console]::Error.WriteLine("windows-job-run: could not create the kill-on-close job: $_"); exit 94 }
$p = Start-Process -FilePath $Bash -ArgumentList @("`"$Script`"") -NoNewWindow -PassThru -Wait
exit $p.ExitCode
