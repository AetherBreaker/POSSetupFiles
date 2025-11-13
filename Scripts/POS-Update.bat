@echo off
REM POS Hybrid Update Script
REM Save as: C:\Scripts\POS-Update.bat

setlocal enabledelayedexpansion

REM Set variables
set LOG_FILE=C:\Scripts\Logs\update.log
set SCRIPT_DIR=C:\Scripts
set LOGS_DIR=C:\Scripts\Logs

REM Create directories if they don't exist
if not exist "%SCRIPT_DIR%" mkdir "%SCRIPT_DIR%"
if not exist "%LOGS_DIR%" mkdir "%LOGS_DIR%"

REM Function to log with timestamp
call :LOG "=== POS Update Process Started ==="

REM Check if it's business hours (optional safety check)
for /f "tokens=1-3 delims=:" %%a in ('echo %time%') do (
    set hour=%%a
    set /a "hour=!hour: =!"
)

if !hour! geq 6 if !hour! leq 22 (
    call :LOG "WARNING: Running during potential business hours (6 AM - 10 PM)"
    call :LOG "Aborting to prevent business disruption"
    goto :END
)

call :LOG "Starting Windows Update process..."

REM Stop any running FasTrax POS applications
call :LOG "Checking for running FasTrax POS applications..."
tasklist /FI "IMAGENAME eq FasTraxPOSWPF.exe" 2>NUL | find /I /N "FasTraxPOSWPF.exe">NUL
if "%ERRORLEVEL%"=="0" (
    call :LOG "FasTrax POS application detected - attempting graceful shutdown..."
    REM Try graceful shutdown first
    timeout /t 30
    REM Force close if still running
    tasklist /FI "IMAGENAME eq FasTraxPOSWPF.exe" 2>NUL | find /I /N "FasTraxPOSWPF.exe">NUL
    if "%ERRORLEVEL%"=="0" (
        call :LOG "Force closing FasTrax POS application..."
        taskkill /F /IM FasTraxPOSWPF.exe 2>NUL
        timeout /t 15
    )
)

REM Force Windows Update scan and download with fallback methods
call :LOG "Attempting Windows Update via UsoClient..."
UsoClient StartScan >nul 2>&1
if %errorlevel% neq 0 (
    call :LOG "UsoClient not available, using alternative method..."
    call :LOG "Triggering Windows Update via PowerShell..."
    powershell -Command "& {try {Install-Module PSWindowsUpdate -Force -ErrorAction Stop; Get-WUInstall -AcceptAll -AutoReboot:$false} catch {Write-Host 'PowerShell method failed, using wuauclt'; Start-Process 'wuauclt' -ArgumentList '/detectnow' -Wait; Start-Sleep 30; Start-Process 'wuauclt' -ArgumentList '/updatenow' -Wait}}" >nul 2>&1
    timeout /t 180
) else (
    call :LOG "UsoClient available, proceeding with standard method..."
    timeout /t 30
    
    call :LOG "Starting download..."
    UsoClient StartDownload
    timeout /t 120
    
    call :LOG "Installing updates..."
    UsoClient StartInstall
    timeout /t 600
)

REM Wait for updates to process
call :LOG "Waiting for update installation to complete..."
timeout /t 300

REM Check multiple registry locations for restart requirement
set RESTART_NEEDED=0

reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" >nul 2>&1
if %errorlevel% == 0 set RESTART_NEEDED=1

reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" >nul 2>&1
if %errorlevel% == 0 set RESTART_NEEDED=1

reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" /v PendingFileRenameOperations >nul 2>&1
if %errorlevel% == 0 set RESTART_NEEDED=1

if %RESTART_NEEDED% == 1 (
    call :LOG "Restart required - setting up dual restart sequence"
    
    REM Create second restart script
    echo @echo off > "%SCRIPT_DIR%\SecondRestart.bat"
    echo echo %%date%% %%time%% - Second restart initiated ^>^> "%LOG_FILE%" >> "%SCRIPT_DIR%\SecondRestart.bat"
    echo timeout /t 900 >> "%SCRIPT_DIR%\SecondRestart.bat"
    echo shutdown /r /t 60 /c "Second restart - POS Update Process" >> "%SCRIPT_DIR%\SecondRestart.bat"
    echo schtasks /delete /tn "POS_SecondRestart" /f ^>nul 2^>^&1 >> "%SCRIPT_DIR%\SecondRestart.bat"
    echo del "%%~f0" >> "%SCRIPT_DIR%\SecondRestart.bat"
    
    REM Schedule second restart to run at startup
    schtasks /create /tn "POS_SecondRestart" /tr "\"%SCRIPT_DIR%\SecondRestart.bat\"" /sc onstart /delay 0005:00 /rl highest /f >nul 2>&1
    
    if %errorlevel% == 0 (
        call :LOG "Second restart scheduled successfully"
    ) else (
        call :LOG "ERROR: Failed to schedule second restart"
    )
    
    REM Perform first restart
    call :LOG "Initiating first restart in 5 minutes..."
    shutdown /r /t 300 /c "First restart - Windows Updates installed"
    
) else (
    call :LOG "No restart required - updates completed successfully"
)

goto :END

:LOG
echo %date% %time% - %~1 >> "%LOG_FILE%"
echo %date% %time% - %~1
goto :eof

:END
call :LOG "=== POS Update Process Completed ==="
endlocal