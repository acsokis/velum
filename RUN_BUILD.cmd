@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0RUN_VELUM.ps1" -Build -RTX
if errorlevel 1 pause
