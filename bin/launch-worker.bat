@echo off
rem Hash-pinned elevated launcher (issue #262). The S4U task runs in the
rem operator's own logon session, so its inherited environment - including
rem every HKCU\Environment value the non-elevated operator can write - is
rem hostile input. A denylist cannot close the class, and neither can a
rem naive clear loop: FOR /F spawns its child through COMSPEC (overridable
rem in HKCU), cmd re-parses substituted names, and a child cmd without /d
rem runs the per-user AutoRun script first. This launcher therefore:
rem   1. refuses to run at all when any cmd AutoRun override exists
rem      (queried with the full-path reg.exe before any FOR /F),
rem   2. pins COMSPEC to the fixed system cmd,
rem   3. clears only names filtered by the system findstr down to an
rem      injection-proof character class - names outside the class survive
rem      in the environment but no host or runtime consumes them as
rem      configuration keys,
rem   4. rebuilds a fixed allowlist of well-known literals,
rem then starts the machine-wide pwsh worker.
C:\Windows\System32\reg.exe query "HKCU\Software\Microsoft\Command Processor" /v AutoRun >nul 2>nul
if not errorlevel 1 (
  echo REFUSING: per-user cmd AutoRun override exists 1>&2
  exit /b 1
)
C:\Windows\System32\reg.exe query "HKLM\Software\Microsoft\Command Processor" /v AutoRun >nul 2>nul
if not errorlevel 1 (
  echo REFUSING: system-wide cmd AutoRun override exists 1>&2
  exit /b 1
)
set "COMSPEC=C:\Windows\System32\cmd.exe"
for /f "delims==" %%v in ('set ^| C:\Windows\System32\findstr.exe /r /c:"^[A-Za-z0-9_-]*="') do set "%%v="
set "SystemRoot=C:\Windows"
set "windir=C:\Windows"
set "SystemDrive=C:"
set "COMSPEC=C:\Windows\System32\cmd.exe"
set "ProgramData=C:\ProgramData"
set "ProgramFiles=C:\Program Files"
set "PATH=C:\Windows\System32;C:\Windows;C:\Program Files\PowerShell\7"
set "PATHEXT=.COM;.EXE;.BAT;.CMD"
set "TEMP=C:\ProgramData\ai-devops\windows-runner-maintenance\temp"
set "TMP=C:\ProgramData\ai-devops\windows-runner-maintenance\temp"
"C:\Program Files\PowerShell\7\pwsh.exe" -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File "C:\Program Files\ai-devops\windows-runner-maintenance\windows-runner-maintenance-worker.ps1"
exit /b %errorlevel%
