@echo off
setlocal DisableDelayedExpansion
cd /d "%~dp0" || exit /b 1
if not exist "WESTSIDE TEST.exe" (
    echo Khong tim thay WESTSIDE TEST.exe. Dat file nay canh launcher TEST 1000080.
    pause
    exit /b 1
)
if not exist "WESTSIDE CITY.app\" (
    echo Thieu thu muc WESTSIDE CITY.app. Can giai nen day du ban build.
    pause
    exit /b 1
)
rem Refuse older launchers that do not understand the safety request.
powershell.exe -NoLogo -NoProfile -NonInteractive -Command "try { if ((Get-FileHash -LiteralPath 'WESTSIDE TEST.exe' -Algorithm SHA256 -ErrorAction Stop).Hash -ne '352838a86dcc8fef668bffd213d9ed8eb225383191870922ba994c0c7f5fa816') { exit 1 } } catch { exit 1 }; exit 0"
if errorlevel 1 (
    echo Launcher khong dung ban TEST 1000080 da kiem chung. Khong khoi dong.
    pause
    exit /b 1
)
rem This marker requests a safety stop; it does not grant permission to skip EAC.
if not exist "WESTSIDE CITY.app\westside-eac-safety.hold" (
    >"WESTSIDE CITY.app\westside-eac-safety.hold" echo User requested cafe safety review. Admin network approval required.
    if errorlevel 1 (
        echo Khong ghi duoc danh dau an toan. Khong mo launcher.
        pause
        exit /b 1
    )
)
start "" /D "%~dp0" "%~dp0WESTSIDE TEST.exe" -westside_cafe_bootstrapped -b3258 -pure_2
exit /b %errorlevel%
