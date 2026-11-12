@echo off
rem Windows entry point: runs setup.ps1 without changing the machine's execution policy.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1" %*
exit /b %ERRORLEVEL%
