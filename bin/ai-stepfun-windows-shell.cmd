@echo off
rem Launcher for ai-stepfun-windows-shell (tests/test-bin-cmd-launchers.sh).
setlocal
set "SCRIPT=%~dp0ai-stepfun-windows-shell"
bash "%SCRIPT%" %*
exit /b %ERRORLEVEL%
