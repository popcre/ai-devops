@echo off
rem Hash-pinned elevated launcher (issue #262). The S4U task runs in the
rem operator's own logon session, so its inherited environment - including
rem every HKCU\Environment value the non-elevated operator can write - is
rem hostile input. A denylist cannot close the class, and neither can a
rem naive clear loop: FOR /F spawns its child through COMSPEC, and cmd
rem re-parses substituted names, so a hostile variable NAME containing
rem quotes or ampersands would execute as commands. This launcher
rem therefore pins COMSPEC to the fixed system cmd FIRST, then clears
rem only names filtered by the system findstr down to an injection-proof
rem character class. Names outside that class survive in the environment
rem but no host or runtime consumes them as configuration keys. Only
rem after the clear does it rebuild a fixed allowlist of well-known
rem literals, then start the machine-wide pwsh worker.
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
