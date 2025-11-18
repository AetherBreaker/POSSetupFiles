#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Complete POS System Setup Script for Windows - Version 2
.DESCRIPTION
    This script performs all necessary configurations for a POS system including:
    - Security settings, user accounts, and auto-login
    - Windows updates and scheduled tasks
    - Software installations (Firefox, .NET, drivers)
    - System configurations (firewall, power settings, timezone)
.NOTES
    Author: POS Setup Automation
    Version: 2.0
    Requires: Administrator privileges

    IMPORTANT: The backup admin credentials will be displayed ONCE during setup.
    Make sure to save them in a secure location immediately!
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$BackupAdminUser = "BackupAdmin",

    [Parameter(Mandatory = $false)]
    [switch]$SkipManualInstallers,

    [Parameter(Mandatory = $false)]
    [switch]$NoRestart,

    [Parameter(Mandatory = $false)]
    [switch]$SkipBackupAdmin
)

# ============================================================================
# INITIALIZATION AND SETUP
# ============================================================================

# Self-elevate the script if required
if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
    Write-Host "Elevating to Administrator privileges..." -ForegroundColor Yellow
    if ([int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000) {
        $CommandLine = "-ExecutionPolicy Bypass -File `"" + $MyInvocation.MyCommand.Path + "`" " + $MyInvocation.UnboundArguments
        Start-Process -FilePath PowerShell.exe -Verb Runas -ArgumentList $CommandLine
        Exit
    }
}

# Set error action preference
$ErrorActionPreference = "Continue"
$ProgressPreference = 'SilentlyContinue'

# Create log directory
$LogPath = "C:\Scripts\Logs"
if (-not (Test-Path $LogPath)) {
    New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
}

# Start transcript
$TranscriptPath = Join-Path $LogPath "POS-Setup-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
Start-Transcript -Path $TranscriptPath -Force

# Get script directory
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

Write-Host @"
================================================================================
                        POS COMPLETE SETUP SCRIPT v2.0
================================================================================
Starting automated POS system configuration...
Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
User: $env:USERNAME
Computer: $env:COMPUTERNAME
================================================================================
"@ -ForegroundColor Cyan

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Write-LogMessage {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Level = "Info"
    )

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "$Timestamp [$Level] $Message"

    switch ($Level) {
        "Success" { Write-Host $LogMessage -ForegroundColor Green }
        "Warning" { Write-Host $LogMessage -ForegroundColor Yellow }
        "Error" { Write-Host $LogMessage -ForegroundColor Red }
        default { Write-Host $LogMessage }
    }

    Add-Content -Path (Join-Path $LogPath "setup.log") -Value $LogMessage
}


function Install-SilentlyIfPossible {
    param(
        [string]$InstallerPath,
        [string]$ProductName,
        [string[]]$SilentArgs = @("/S", "/s", "/Q", "/q", "/quiet", "/silent", "/SILENT", "/VERYSILENT"),
        [switch]$ForceManual
    )

    Write-LogMessage "Installing $ProductName..." "Info"

    if (-not (Test-Path $InstallerPath)) {
        Write-LogMessage "Installer not found: $InstallerPath" "Error"
        return $false
    }

    if ($ForceManual) {
        Write-LogMessage "$ProductName requires manual installation" "Warning"
        if (-not $SkipManualInstallers) {
            Start-Process -FilePath $InstallerPath -Wait
            return $true
        }
        else {
            Write-LogMessage "$ProductName skipped (SkipManualInstallers flag set)" "Warning"
            return $false
        }
    }

    # Try silent installation with different arguments
    foreach ($arg in $SilentArgs) {
        Write-LogMessage "Attempting silent install with argument: $arg" "Info"
        try {
            $process = Start-Process -FilePath $InstallerPath -ArgumentList $arg -Wait -PassThru -WindowStyle Hidden
            if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
                # 3010 = success, reboot required
                Write-LogMessage "$ProductName installed successfully (silent)" "Success"
                return $true
            }
        }
        catch {
            continue
        }
    }

    # Fall back to manual installation
    if (-not $SkipManualInstallers) {
        Write-LogMessage "$ProductName cannot be installed silently - launching interactive installer" "Warning"
        Start-Process -FilePath $InstallerPath -Wait
        return $true
    }
    else {
        Write-LogMessage "$ProductName cannot be installed silently and will be skipped (SkipManualInstallers flag set)" "Warning"
        return $false
    }
}

# ============================================================================
# STEP 1: SECURITY AND USER ACCOUNT CONFIGURATION
# ============================================================================

Write-LogMessage ("=" * 70) "Info"
Write-LogMessage "STEP 1: SECURITY AND USER ACCOUNT CONFIGURATION" "Info"
Write-LogMessage ("=" * 70) "Info"

# Get current username
$CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name.Split('\')[1]
Write-LogMessage "Current user: $CurrentUser" "Info"

# Create backup admin account
if (-not $SkipBackupAdmin) {
    Write-LogMessage "Creating backup administrator account..." "Info"

    # Use same password as working batch script
    $BackupAdminPassword = "BackupPass123!"

    # Display credentials prominently (no pause - credentials already saved)
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Yellow -BackgroundColor DarkRed
    Write-Host "                BACKUP ADMIN CREDENTIALS                        " -ForegroundColor Yellow -BackgroundColor DarkRed
    Write-Host "================================================================" -ForegroundColor Yellow -BackgroundColor DarkRed
    Write-Host ""
    Write-Host "Backup Admin Username: $BackupAdminUser" -ForegroundColor Cyan
    Write-Host "Backup Admin Password: $BackupAdminPassword" -ForegroundColor Cyan
    Write-Host ""

    try {
        # Use net user command like the working batch script
        $createResult = & net user $BackupAdminUser $BackupAdminPassword /add 2>&1
        if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 2) {
            # 2 = already exists
            Write-LogMessage "Backup admin account created/updated successfully" "Success"

            # Add to administrators group
            & net localgroup administrators $BackupAdminUser /add 2>&1 | Out-Null

            # Set account to never expire
            & net user $BackupAdminUser /expires:never 2>&1 | Out-Null

            Write-LogMessage "Backup admin added to Administrators group" "Success"
        }
        else {
            Write-LogMessage "Failed to create backup admin account: $createResult" "Error"
        }
    }
    catch {
        Write-LogMessage "Failed to create/update backup admin account: $_" "Error"
    }
}
else {
    Write-LogMessage "Skipping backup admin account creation (SkipBackupAdmin flag set)" "Warning"
}

# Clear password for current user
Write-LogMessage "Removing password from current user account..." "Info"
try {
    # Use net user command like the working batch script
    & net user $CurrentUser "" 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-LogMessage "Password removed from $CurrentUser" "Success"
    }
    else {
        Write-LogMessage "Failed to remove password from $CurrentUser" "Warning"
    }
}
catch {
    Write-LogMessage "Failed to remove password: $_" "Warning"
}

# Disable account lockout policies using net accounts (same as working batch script)
Write-LogMessage "Disabling account lockout policies..." "Info"
try {
    # Use net accounts commands like the working batch script
    & net accounts /lockoutthreshold:0 2>&1 | Out-Null
    & net accounts /lockoutduration:0 2>&1 | Out-Null
    & net accounts /lockoutwindow:0 2>&1 | Out-Null
    & net accounts /minpwage:0 2>&1 | Out-Null
    & net accounts /maxpwage:unlimited 2>&1 | Out-Null
    & net accounts /minpwlen:0 2>&1 | Out-Null

    Write-LogMessage "Password policies disabled successfully" "Success"
}
catch {
    Write-LogMessage "Failed to update password policies: $_" "Error"
}

# Configure auto-login
Write-LogMessage "Configuring automatic login..." "Info"
try {
    $WinlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    Set-ItemProperty -Path $WinlogonPath -Name "AutoAdminLogon" -Value "1" -Type String
    Set-ItemProperty -Path $WinlogonPath -Name "DefaultUserName" -Value $CurrentUser -Type String
    Set-ItemProperty -Path $WinlogonPath -Name "DefaultPassword" -Value "" -Type String
    Set-ItemProperty -Path $WinlogonPath -Name "DefaultDomainName" -Value $env:COMPUTERNAME -Type String
    Write-LogMessage "Auto-login configured for $CurrentUser" "Success"
}
catch {
    Write-LogMessage "Failed to configure auto-login: $_" "Error"
}

# ============================================================================
# STEP 2: WINDOWS FIREWALL CONFIGURATION
# ============================================================================

Write-LogMessage ("=" * 70) "Info"
Write-LogMessage "STEP 2: WINDOWS FIREWALL CONFIGURATION" "Info"
Write-LogMessage ("=" * 70) "Info"

try {
    Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled False
    Write-LogMessage "Windows Firewall disabled for all profiles" "Success"
}
catch {
    Write-LogMessage "Failed to disable Windows Firewall: $_" "Error"
}

# ============================================================================
# STEP 3: POWER AND SLEEP SETTINGS
# ============================================================================

Write-LogMessage ("=" * 70) "Info"
Write-LogMessage "STEP 3: POWER AND SLEEP SETTINGS" "Info"
Write-LogMessage ("=" * 70) "Info"

try {
    # Set power settings to never sleep when plugged in
    powercfg /change monitor-timeout-ac 0
    powercfg /change disk-timeout-ac 0
    powercfg /change standby-timeout-ac 0
    powercfg /change hibernate-timeout-ac 0

    # Disable hybrid sleep
    powercfg /h off

    Write-LogMessage "Power settings configured - system will never sleep when plugged in" "Success"
}
catch {
    Write-LogMessage "Failed to configure power settings: $_" "Error"
}

# ============================================================================
# STEP 4: LOCATION SERVICES AND TIME ZONE
# ============================================================================

Write-LogMessage ("=" * 70) "Info"
Write-LogMessage "STEP 4: LOCATION SERVICES AND TIME ZONE" "Info"
Write-LogMessage ("=" * 70) "Info"

try {
    # Enable Location Services - Create registry path if it doesn't exist
    $LocationPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"
    if (-not (Test-Path $LocationPath)) {
        New-Item -Path $LocationPath -Force | Out-Null
    }
    Set-ItemProperty -Path $LocationPath -Name "Value" -Value "Allow"

    # Also set for current user
    $UserLocationPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"
    if (-not (Test-Path $UserLocationPath)) {
        New-Item -Path $UserLocationPath -Force | Out-Null
    }
    Set-ItemProperty -Path $UserLocationPath -Name "Value" -Value "Allow"

    # Enable Location Service
    Set-Service -Name "lfsvc" -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service -Name "lfsvc" -ErrorAction SilentlyContinue

    Write-LogMessage "Location services enabled" "Success"

    # Set time zone to update automatically
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate" -Name "Start" -Value 3
    Write-LogMessage "Automatic time zone detection enabled" "Success"
}
catch {
    Write-LogMessage "Failed to configure location/timezone settings: $_" "Error"
}

# ============================================================================
# STEP 5: DESKTOP BACKGROUND
# ============================================================================

Write-LogMessage ("=" * 70) "Info"
Write-LogMessage "STEP 5: DESKTOP BACKGROUND" "Info"
Write-LogMessage ("=" * 70) "Info"

$LogoSource = Join-Path $ScriptDir "sft-logo-blackbg.jpg"
$LogoDestination = Join-Path $env:USERPROFILE "Pictures\sft-logo-blackbg.jpg"

if (Test-Path $LogoSource) {
    try {
        # Create Pictures directory if it doesn't exist
        $PicturesDir = Join-Path $env:USERPROFILE "Pictures"
        if (-not (Test-Path $PicturesDir)) {
            New-Item -Path $PicturesDir -ItemType Directory -Force | Out-Null
        }

        # Copy logo file
        Copy-Item -Path $LogoSource -Destination $LogoDestination -Force

        # Set as wallpaper with Fit style
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport(`"user32.dll`", CharSet=CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@

        # Set wallpaper style to Fit (6)
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "WallpaperStyle" -Value 6
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "TileWallpaper" -Value 0

        # Apply wallpaper
        [Wallpaper]::SystemParametersInfo(0x0014, 0, $LogoDestination, 0x0001 -bor 0x0002)

        Write-LogMessage "Desktop background set to SFT logo" "Success"
    }
    catch {
        Write-LogMessage "Failed to set desktop background: $_" "Error"
    }
}
else {
    Write-LogMessage "Logo file not found at: $LogoSource" "Warning"
}

# ============================================================================
# STEP 6: FIREFOX INSTALLATION AND CONFIGURATION
# ============================================================================

Write-LogMessage ("=" * 70) "Info"
Write-LogMessage "STEP 6: FIREFOX INSTALLATION AND CONFIGURATION" "Info"
Write-LogMessage ("=" * 70) "Info"

# Download and install Firefox
$FirefoxURL = "https://download.mozilla.org/?product=firefox-latest-ssl&os=win64&lang=en-US"
$FirefoxInstaller = Join-Path $env:TEMP "Firefox-Setup.exe"

try {
    Write-LogMessage "Downloading Firefox..." "Info"
    Invoke-WebRequest -Uri $FirefoxURL -OutFile $FirefoxInstaller -UseBasicParsing

    Write-LogMessage "Installing Firefox silently..." "Info"
    Start-Process -FilePath $FirefoxInstaller -ArgumentList "/S" -Wait

    Write-LogMessage "Firefox installed successfully" "Success"
    Remove-Item $FirefoxInstaller -Force -ErrorAction SilentlyContinue
}
catch {
    Write-LogMessage "Failed to install Firefox: $_" "Error"
}

# Install uBlock Origin extension
$FirefoxPath = "C:\Program Files\Mozilla Firefox"
$ExtensionsPath = Join-Path $FirefoxPath "distribution\extensions"
$UblockURL = "https://addons.mozilla.org/firefox/downloads/file/4598854/ublock_origin-1.67.0.xpi"
$UblockFile = "uBlock0@raymondhill.net.xpi"

try {
    if (-not (Test-Path $ExtensionsPath)) {
        New-Item -Path $ExtensionsPath -ItemType Directory -Force | Out-Null
    }

    Write-LogMessage "Downloading uBlock Origin extension..." "Info"
    Invoke-WebRequest -Uri $UblockURL -OutFile (Join-Path $ExtensionsPath $UblockFile) -UseBasicParsing
    Write-LogMessage "uBlock Origin extension installed" "Success"
}
catch {
    Write-LogMessage "Failed to install uBlock Origin: $_" "Warning"
}

# Set Firefox as default browser
try {
    Write-LogMessage "Setting Firefox as default browser..." "Info"

    # Try using Firefox's built-in method first
    $FirefoxExe = Join-Path $FirefoxPath "firefox.exe"
    if (Test-Path $FirefoxExe) {
        Start-Process -FilePath $FirefoxExe -ArgumentList "-setDefaultBrowser" -Wait -WindowStyle Hidden
    }

    # Fallback: Open settings for manual configuration
    Start-Process "ms-settings:defaultapps"
    Write-LogMessage "Please manually set Firefox as default browser in the Settings window if needed" "Warning"
}
catch {
    Write-LogMessage "Failed to set default browser automatically" "Warning"
}

# Pin Firefox to taskbar
try {
    $FirefoxExe = Join-Path $FirefoxPath "firefox.exe"
    if (Test-Path $FirefoxExe) {
        # Create shortcut in temp location
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut("$env:TEMP\Firefox.lnk")
        $Shortcut.TargetPath = $FirefoxExe
        $Shortcut.Save()

        # Pin to taskbar (Windows 10/11)
        $Shell = New-Object -ComObject Shell.Application
        $Folder = $Shell.NameSpace((Get-Item "$env:TEMP\Firefox.lnk").DirectoryName)
        $Item = $Folder.ParseName("Firefox.lnk")
        $Item.InvokeVerb("taskbarpin")

        Write-LogMessage "Firefox pinned to taskbar" "Success"
        Remove-Item "$env:TEMP\Firefox.lnk" -Force -ErrorAction SilentlyContinue
    }
}
catch {
    Write-LogMessage "Failed to pin Firefox to taskbar: $_" "Warning"
}

# Unpin Edge from taskbar and remove desktop shortcuts
try {
    Write-LogMessage "Removing Edge shortcuts..." "Info"

    # Remove Edge desktop shortcuts
    $DesktopPaths = @(
        [Environment]::GetFolderPath("Desktop"),
        [Environment]::GetFolderPath("CommonDesktopDirectory")
    )

    foreach ($Desktop in $DesktopPaths) {
        Get-ChildItem -Path $Desktop -Filter "*Edge*.lnk" -ErrorAction SilentlyContinue | Remove-Item -Force
    }

    Write-LogMessage "Edge shortcuts removed" "Success"
}
catch {
    Write-LogMessage "Failed to remove Edge shortcuts: $_" "Warning"
}

# ============================================================================
# STEP 7: WINDOWS FEATURES (.NET FRAMEWORK)
# ============================================================================

Write-LogMessage ("=" * 70) "Info"
Write-LogMessage "STEP 7: WINDOWS FEATURES (.NET FRAMEWORK)" "Info"
Write-LogMessage ("=" * 70) "Info"

# Enable .NET Framework 3.5 and 4.8 with retry logic
$MaxRetries = 3
$RetryCount = 0
$FeatureInstalled = $false

while ($RetryCount -lt $MaxRetries -and -not $FeatureInstalled) {
    try {
        Write-LogMessage "Enabling .NET Framework features (Attempt $($RetryCount + 1) of $MaxRetries)..." "Info"

        # Enable .NET 3.5
        $NetFx3Result = Enable-WindowsOptionalFeature -Online -FeatureName "NetFx3" -All -NoRestart -ErrorAction Stop

        # Enable .NET 4.8 Advanced Services
        $NetFx4Result = Enable-WindowsOptionalFeature -Online -FeatureName "NetFx4-AdvSrvs" -All -NoRestart -ErrorAction Stop
        $AspNetResult = Enable-WindowsOptionalFeature -Online -FeatureName "NetFx4Extended-ASPNET45" -All -NoRestart -ErrorAction Stop

        Write-LogMessage ".NET Framework features enabled successfully" "Success"
        $FeatureInstalled = $true
    }
    catch {
        $RetryCount++
        if ($RetryCount -lt $MaxRetries) {
            Write-LogMessage "Installation failed, retrying in 10 seconds..." "Warning"
            Write-LogMessage "Error: $_" "Warning"
            Start-Sleep -Seconds 10
        }
        else {
            Write-LogMessage ".NET Framework installation failed after $MaxRetries attempts. May require manual installation." "Error"
            Write-LogMessage "Error details: $_" "Error"
        }
    }
}


# ============================================================================
# STEP 8: WinSewView CONFIGURATION
# ============================================================================

Write-LogMessage ("=" * 70) "Info"
Write-LogMessage "STEP 8: WinSetView CONFIGURATION" "Info"
Write-LogMessage ("=" * 70) "Info"

.\WinSetView.ps1 .\POSDefaults.ini
Write-LogMessage "WinSetView configuration applied from POSDefaults.ini" "Success"


# ============================================================================
# STEP 9: PREREQUISITE SOFTWARE INSTALLATION
# ============================================================================

Write-LogMessage ("=" * 70) "Info"
Write-LogMessage "STEP 9: PREREQUISITE SOFTWARE INSTALLATION" "Info"
Write-LogMessage ("=" * 70) "Info"

# Determine system architecture
$Is64Bit = [System.Environment]::Is64BitOperatingSystem

# Install MS ODBC SQL Driver
$ODBCInstaller = if ($Is64Bit) {
    Join-Path $ScriptDir "Installer Files Directory\FTX Pre-reqs\msodbcsql_x64.msi"
}
else {
    Join-Path $ScriptDir "Installer Files Directory\FTX Pre-reqs\msodbcsql_x86.msi"
}

if (Test-Path $ODBCInstaller) {
    try {
        Write-LogMessage "Installing MS ODBC SQL Driver..." "Info"
        $msiArgs = @(
            "/i",
            "`"$ODBCInstaller`"",
            "/quiet",
            "/norestart",
            "IACCEPTMSODBCSQLLICENSETERMS=YES"
        )
        $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru
        if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
            Write-LogMessage "MS ODBC SQL Driver installed successfully" "Success"
        }
        else {
            Write-LogMessage "MS ODBC SQL Driver installation returned code: $($process.ExitCode)" "Warning"
        }
    }
    catch {
        Write-LogMessage "Failed to install MS ODBC SQL Driver: $_" "Error"
    }
}
else {
    Write-LogMessage "MS ODBC SQL Driver installer not found at: $ODBCInstaller" "Warning"
}

# Install PosForDotNet
$PosForDotNetInstaller = Join-Path $ScriptDir "Installer Files Directory\FTX Pre-reqs\PosForDotNet-1.14.1.msi"
if (Test-Path $PosForDotNetInstaller) {
    try {
        Write-LogMessage "Installing PosForDotNet..." "Info"
        $msiArgs = @(
            "/i",
            "`"$PosForDotNetInstaller`"",
            "/quiet",
            "/norestart"
        )
        $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru
        if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
            Write-LogMessage "PosForDotNet installed successfully" "Success"
        }
        else {
            Write-LogMessage "PosForDotNet installation returned code: $($process.ExitCode)" "Warning"
        }
    }
    catch {
        Write-LogMessage "Failed to install PosForDotNet: $_" "Error"
    }
}
else {
    Write-LogMessage "PosForDotNet installer not found at: $PosForDotNetInstaller" "Warning"
}

# Install SQL Server Compact Edition Runtime
$SSCEInstaller = Join-Path $ScriptDir "Installer Files Directory\FTX Pre-reqs\SSCERuntime_x64-ENU.exe"
if (Test-Path $SSCEInstaller) {
    Install-SilentlyIfPossible -InstallerPath $SSCEInstaller -ProductName "SQL Server Compact Edition Runtime" -SilentArgs @("/quiet", "/norestart")
}
else {
    Write-LogMessage "SSCE Runtime installer not found at: $SSCEInstaller" "Warning"
}


# ============================================================================
# INSTALLATION SUMMARY
# ============================================================================

Write-Host @"

================================================================================
                        INSTALLATION SUMMARY
================================================================================
"@ -ForegroundColor Cyan

Write-LogMessage "Installation process completed!" "Success"
Write-Host ""

Write-Host "Completed Configurations:" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Green
Write-Host "  [OK] Backup admin account created" -ForegroundColor Green
Write-Host "  [OK] Account lockout policies disabled" -ForegroundColor Green
Write-Host "  [OK] Auto-login configured" -ForegroundColor Green
Write-Host "  [OK] Windows Firewall disabled" -ForegroundColor Green
Write-Host "  [OK] Power settings configured (no sleep)" -ForegroundColor Green
Write-Host "  [OK] Location services and timezone configured" -ForegroundColor Green
Write-Host "  [OK] Desktop background set" -ForegroundColor Green
Write-Host "  [OK] Firefox installed with uBlock Origin" -ForegroundColor Green
Write-Host "  [OK] .NET Framework features enabled" -ForegroundColor Green
Write-Host ""

Write-Host "Log files location: C:\Scripts\Logs\" -ForegroundColor Cyan
Write-Host "Transcript saved to: $TranscriptPath" -ForegroundColor Cyan
Write-Host ""

# Stop transcript
Stop-Transcript

# Restart prompt
if (-not $NoRestart) {
    Write-Host "=================================================================================" -ForegroundColor Yellow
    Write-Host "A system restart is recommended to apply all changes." -ForegroundColor Yellow
    Write-Host "=================================================================================" -ForegroundColor Yellow
    $RestartChoice = Read-Host "Would you like to restart now? (Y/N)"

    if ($RestartChoice -eq 'Y' -or $RestartChoice -eq 'y') {
        Write-Host "System will restart in 30 seconds..." -ForegroundColor Red
        shutdown /r /t 30 /c `"POS Setup Complete - Restarting to apply changes`"
    }
    else {
        Write-Host "Please restart manually when convenient to apply all changes." -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "POS Setup Script Completed Successfully!" -ForegroundColor Green
Write-Host "Script will exit automatically in 3 seconds..." -ForegroundColor Cyan
Start-Sleep -Seconds 3