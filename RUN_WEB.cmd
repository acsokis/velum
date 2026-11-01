@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0RUN_WEB.ps1"
if errorlevel 1 pause
