@echo off
rem Windows launcher for az-mail. See tests/test-bin-cmd-launchers.sh.
setlocal
set "AI_BASH=%ProgramFiles%\Git\bin\bash.exe"
if not exist "%AI_BASH%" set "AI_BASH=%ProgramFiles(x86)%\Git\bin\bash.exe"
if not exist "%AI_BASH%" set "AI_BASH=%LOCALAPPDATA%\Programs\Git\bin\bash.exe"
if not exist "%AI_BASH%" set "AI_BASH=C:\Program Files\Git\bin\bash.exe"
if not exist "%AI_BASH%" set "AI_BASH=C:\Program Files (x86)\Git\bin\bash.exe"
"%AI_BASH%" -c "exec \"$0\" \"$@\"" "%~dpn0" %*
exit /b %ERRORLEVEL%
