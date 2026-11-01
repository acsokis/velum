@echo off
setlocal
cd /d "%~dp0"
set "VELUM_DATA_DIR=%~dp0runtime"
set "VELUM_LINK_DISABLED=1"
if not exist "%VELUM_DATA_DIR%" mkdir "%VELUM_DATA_DIR%"
"%~dp0VELUM.exe" --rendering-driver d3d12 --log-file "%VELUM_DATA_DIR%\desktop.log" %*
if errorlevel 1 pause
