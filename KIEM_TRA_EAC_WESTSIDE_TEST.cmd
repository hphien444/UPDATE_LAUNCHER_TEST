@echo off
setlocal
if "%~1"=="" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0KIEM_TRA_EAC_WESTSIDE_TEST.ps1"
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0KIEM_TRA_EAC_WESTSIDE_TEST.ps1" -LauncherPath "%~f1"
)
echo.
echo Gui file KET_QUA_EAC_TEST_*.json cho ho tro. Khong gui config hay token.
pause
