@echo off
rem Hash-pinned elevated launcher (issue #262). The S4U task runs in the
rem operator's own logon session, so its inherited environment - including
rem every HKCU\Environment value the non-elevated operator can write - is
rem hostile input. A denylist cannot close the class (.NET startup hooks,
rem CoreCLR profilers, runtime roots, and their siblings all load operator
rem code before any script statement runs), so this launcher clears the
rem ENTIRE environment and rebuilds a fixed allowlist of well-known
rem literals before the machine-wide pwsh host starts. It runs with /d
rem (no per-user AutoRun) and lives in the administrator-owned, hash-
rem verified payload root.
for /f "delims==" %%v in ('set') do set "%%v="
set "SystemRoot=C:\Windows"
set "windir=C:\Windows"
set "SystemDrive=C:"
set "ProgramData=C:\ProgramData"
set "ProgramFiles=C:\Program Files"
set "PATH=C:\Windows\System32;C:\Windows;C:\Program Files\PowerShell\7"
set "PATHEXT=.COM;.EXE;.BAT;.CMD"
set "TEMP=C:\Windows\Temp"
set "TMP=C:\Windows\Temp"
"C:\Program Files\PowerShell\7\pwsh.exe" -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File "C:\Program Files\ai-devops\windows-runner-maintenance\windows-runner-maintenance-worker.ps1"
exit /b %errorlevel%
