@echo off
REM FasTrax POS Update System Setup
REM Run as Administrator - Save as: Setup-FasTrax-Updates.bat

echo Setting up FasTrax POS Auto-Update System...
echo.

REM Verify FasTrax installation
if not exist "C:\Program Files (x86)\FasTraxPOS\FTX POS\FasTraxPOSWPF.exe" (
    echo WARNING: FasTrax POS not found at expected location
    echo Please verify FasTrax POS installation path
    echo Expected: C:\Program Files ^(x86^)\FasTraxPOS\FTX POS\FasTraxPOSWPF.exe
    echo.
    set /p continue="Continue anyway? (Y/N): "
    if /i not "!continue!"=="Y" exit /b 1
)

REM Create directory structure
echo Creating directories...
if not exist "C:\Scripts" mkdir "C:\Scripts"
if not exist "C:\Scripts\Logs" mkdir "C:\Scripts\Logs"
if not exist "C:\Scripts\Backup" mkdir "C:\Scripts\Backup"

REM Check if main script exists
if not exist "C:\Scripts\POS-Update.bat" (
    echo ERROR: POS-Update.bat not found in C:\Scripts\
    echo Please copy the FasTrax-customized script first, then run setup again.
    pause
    exit /b 1
)

REM Create the scheduled task for 2 AM daily
echo Creating scheduled task for FasTrax POS updates...
schtasks /create /tn "FasTrax_NightlyUpdate" /tr "C:\Scripts\POS-Update.bat" /sc daily /st 02:00 /rl highest /f

if %errorlevel% == 0 (
    echo SUCCESS: Scheduled task created - will run daily at 2:00 AM
) else (
    echo ERROR: Failed to create scheduled task
    pause
    exit /b 1
)

REM Configure Windows Update service
echo Configuring Windows Update service...
sc config wuauserv start= auto
net start wuauserv >nul 2>&1

REM Set up Windows Update policies
echo Configuring Windows Update settings for FasTrax environment...
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 0 /f >nul
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUOptions /t REG_DWORD /d 4 /f >nul
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v ScheduledInstallDay /t REG_DWORD /d 0 /f >nul
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v ScheduledInstallTime /t REG_DWORD /d 2 /f >nul

REM Create FasTrax-specific monitoring script
echo Creating FasTrax monitoring script...
echo @echo off > "C:\Scripts\Check-FasTrax.bat"
echo REM Quick check if FasTrax is running properly after updates >> "C:\Scripts\Check-FasTrax.bat"
echo tasklist /FI "IMAGENAME eq FasTraxPOSWPF.exe" 2^>NUL ^| find /I /N "FasTraxPOSWPF.exe"^>NUL >> "C:\Scripts\Check-FasTrax.bat"
echo if "%%ERRORLEVEL%%"=="0" ^( >> "C:\Scripts\Check-FasTrax.bat"
echo     echo %%date%% %%time%% - FasTrax POS is running normally ^>^> C:\Scripts\Logs\fastrax-status.log >> "C:\Scripts\Check-FasTrax.bat"
echo ^) else ^( >> "C:\Scripts\Check-FasTrax.bat"
echo     echo %%date%% %%time%% - WARNING: FasTrax POS not detected ^>^> C:\Scripts\Logs\fastrax-status.log >> "C:\Scripts\Check-FasTrax.bat"
echo ^) >> "C:\Scripts\Check-FasTrax.bat"

REM Test FasTrax detection
echo.
echo Testing FasTrax POS detection...
tasklist /FI "IMAGENAME eq FasTraxPOSWPF.exe" 2>NUL | find /I /N "FasTraxPOSWPF.exe">NUL
if "%ERRORLEVEL%"=="0" (
    echo SUCCESS: FasTrax POS is currently running and detected
) else (
    echo INFO: FasTrax POS is not currently running ^(this is normal if store is closed^)
)

echo.
echo ============================================
echo FasTrax POS Update System Setup Complete!
echo ============================================
echo.
echo CONFIGURATION SUMMARY:
echo - Update Schedule: Daily at 2:00 AM
echo - Target Application: FasTraxPOSWPF.exe
echo - Logs Location: C:\Scripts\Logs\
echo - Script Location: C:\Scripts\POS-Update.bat
echo.
echo TESTING STEPS:
echo 1. Test script manually: C:\Scripts\POS-Update.bat
echo 2. Check logs: type C:\Scripts\Logs\update.log
echo 3. Test FasTrax detection: C:\Scripts\Check-FasTrax.bat
echo 4. Verify task: schtasks /query /tn "FasTrax_NightlyUpdate"
echo.
echo IMPORTANT FASTRAX CONSIDERATIONS:
echo - Ensure no transactions are processing during 2 AM window
echo - Verify FasTrax database backups are current
echo - Test restart process during non-business hours first
echo - Monitor first few automated runs closely
echo.
pause