@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0RUN_VELUM.ps1" -Build -RTX
if errorlevel 1 (
  echo.
  echo VELUM could not start. See the message above and runtime logs.
  pause
)
