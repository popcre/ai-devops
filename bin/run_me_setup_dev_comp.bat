@echo off
REM TRANSITIONAL/DEPRECATED: use bootstrap-windows-dev.ps1 for new setups.
rem Double-click entry point for a fully configured Windows development computer.
rem This launches the internal PowerShell helper beside it. Do not run the helper directly.
echo Starting Windows development computer setup...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup_dev_computer_internal.ps1"
