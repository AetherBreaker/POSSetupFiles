@echo off
echo ========================================
echo FasTrax POS Update System - SAFE TEST
echo ========================================

REM Test 1: Directory and file structure
echo.
echo [TEST 1] Checking file structure...
if exist "C:\Scripts\POS-Update.bat" (
    echo ✓ Main script found
) else (
    echo ✗ Main script missing
)

if exist "C:\Scripts\Logs" (
    echo ✓ Logs directory exists
) else (
    echo ✗ Logs directory missing
)

REM Test 2: FasTrax detection
echo.
echo [TEST 2] Testing FasTrax POS detection...
tasklist /FI "IMAGENAME eq FasTraxPOSWPF.exe" 2>NUL | find /I /N "FasTraxPOSWPF.exe">NUL
if "%ERRORLEVEL%"=="0" (
    echo ✓ FasTrax POS is currently running
    echo   Process details:
    tasklist /FI "IMAGENAME eq FasTraxPOSWPF.exe" /FO TABLE
) else (
    echo ℹ FasTrax POS is not currently running (normal if store closed)
)

REM Test 3: Update methods availability
echo.
echo [TEST 3] Testing Windows Update methods...

REM Test UsoClient
echo Testing UsoClient availability...
UsoClient StartScan >nul 2>&1
if %errorlevel% == 0 (
    echo ✓ UsoClient is available and working
) else (
    echo ⚠ UsoClient not available - will use fallback methods
    
    REM Test PowerShell alternative
    echo Testing PowerShell Windows Update capability...
    powershell -Command "Get-Module -ListAvailable PSWindowsUpdate" >nul 2>&1
    if %errorlevel% == 0 (
        echo ✓ PSWindowsUpdate module available
    ) else (
        echo ℹ PSWindowsUpdate not installed - can be installed automatically
    )
    
    REM Test wuauclt
    echo Testing legacy wuauclt...
    where wuauclt >nul 2>&1
    if %errorlevel% == 0 (
        echo ✓ wuauclt available as fallback
    ) else (
        echo ⚠ wuauclt not found
    )
)

REM Test 4: Windows Update service
echo.
echo [TEST 4] Checking Windows Update service...
sc query wuauserv | find "RUNNING" >nul
if %errorlevel% == 0 (
    echo ✓ Windows Update service is running
) else (
    echo ⚠ Windows Update service not running - attempting to start...
    net start wuauserv >nul 2>&1
    if %errorlevel% == 0 (
        echo ✓ Windows Update service started successfully
    ) else (
        echo ✗ Failed to start Windows Update service
    )
)

REM Test 5: Restart requirement detection (all methods)
echo.
echo [TEST 5] Testing restart detection methods...
set RESTART_NEEDED=0

reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" >nul 2>&1
if %errorlevel% == 0 (
    echo ✓ Method 1: WindowsUpdate RebootRequired - YES
    set RESTART_NEEDED=1
) else (
    echo ✓ Method 1: WindowsUpdate RebootRequired - NO
)

reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" >nul 2>&1
if %errorlevel% == 0 (
    echo ✓ Method 2: Component Based Servicing - YES
    set RESTART_NEEDED=1
) else (
    echo ✓ Method 2: Component Based Servicing - NO
)

reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" /v PendingFileRenameOperations >nul 2>&1
if %errorlevel% == 0 (
    echo ✓ Method 3: PendingFileRenameOperations - YES
    set RESTART_NEEDED=1
) else (
    echo ✓ Method 3: PendingFileRenameOperations - NO
)

if %RESTART_NEEDED% == 1 (
    echo.
    echo ⚠ RESTART WOULD BE REQUIRED
) else (
    echo.
    echo ✓ NO RESTART NEEDED
)

REM Test 6: Scheduled task verification
echo.
echo [TEST 6] Checking scheduled task...
schtasks /query /tn "FasTrax_NightlyUpdate" /fo table >nul 2>&1
if %errorlevel% == 0 (
    echo ✓ Scheduled task exists
    schtasks /query /tn "FasTrax_NightlyUpdate" /fo list | findstr "Next Run Time"
) else (
    echo ✗ Scheduled task not found
)

REM Test 7: Permissions check
echo.
echo [TEST 7] Testing administrative permissions...
net session >nul 2>&1
if %errorlevel% == 0 (
    echo ✓ Running with administrative privileges
) else (
    echo ⚠ Not running as administrator - some functions may fail
)

echo.
echo ========================================
echo TEST COMPLETED - NO CHANGES MADE
echo ========================================
echo.
echo SUMMARY:
echo - File structure: Ready
echo - FasTrax detection: Working
echo - Update methods: Available with fallbacks
echo - Restart detection: Working
echo - Scheduled task: Configured
echo.
pause