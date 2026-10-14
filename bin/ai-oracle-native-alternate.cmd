@echo off
rem Windows launcher so a path call such as bin$b runs the script instead of
rem opening the "Select an app" dialog. Checked by tests/test-bin-cmd-launchers.sh.
setlocal
set "AI_BASH=%ProgramFiles%\Git\bin\bash.exe"
if not exist "%AI_BASH%" set "AI_BASH=%LOCALAPPDATA%\Programs\Git\bin\bash.exe"
"%AI_BASH%" -c "exec \"$0\" \"$@\"" "%~dpn0" %*
exit /b %ERRORLEVEL%
