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




# Get script directory
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }



# ============================================================================
# STEP 1: SECURITY AND USER ACCOUNT CONFIGURATION
# ============================================================================


# Get current username
$CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name.Split('\')[1]

# Create backup admin account
if (-not $SkipBackupAdmin) {

    # Use same password as working batch script
    $BackupAdminPassword = "BackupPass123!"



    # Use net user command like the working batch script
    $createResult = & net user $BackupAdminUser $BackupAdminPassword /add 2>&1
    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 2) {
        # 2 = already exists

        # Add to administrators group
        & net localgroup administrators $BackupAdminUser /add 2>&1 | Out-Null

        # Set account to never expire
        & net user $BackupAdminUser /expires:never 2>&1 | Out-Null

    }
    

}


# Clear password for current user
# Use net user command like the working batch script
& net user $CurrentUser "" 2>&1 | Out-Null

Set-LocalUser -Name "$CurrentUser" -PasswordNeverExpires $true


# Disable account lockout policies using net accounts (same as working batch script)
# Use net accounts commands like the working batch script
& net accounts /lockoutthreshold:0 2>&1 | Out-Null
& net accounts /lockoutduration:0 2>&1 | Out-Null
& net accounts /lockoutwindow:0 2>&1 | Out-Null
& net accounts /minpwage:0 2>&1 | Out-Null
& net accounts /maxpwage:unlimited 2>&1 | Out-Null
& net accounts /minpwlen:0 2>&1 | Out-Null


# Configure auto-login

$WinlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
Set-ItemProperty -Path $WinlogonPath -Name "AutoAdminLogon" -Value "1" -Type String
Set-ItemProperty -Path $WinlogonPath -Name "DefaultUserName" -Value $CurrentUser -Type String
Set-ItemProperty -Path $WinlogonPath -Name "DefaultPassword" -Value "" -Type String
Set-ItemProperty -Path $WinlogonPath -Name "DefaultDomainName" -Value $env:COMPUTERNAME -Type String



# ============================================================================
# STEP 4: LOCATION SERVICES AND TIME ZONE
# ============================================================================


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


# Set time zone to update automatically
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate" -Name "Start" -Value 3

# ============================================================================
# STEP 5: DESKTOP BACKGROUND
# ============================================================================


$LogoSource = Join-Path $ScriptDir "sft-logo-blackbg.jpg"
$LogoDestination = Join-Path $env:USERPROFILE "Pictures\sft-logo-blackbg.jpg"

if (Test-Path $LogoSource) {
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

}

# ============================================================================
# STEP 6: FIREFOX INSTALLATION AND CONFIGURATION
# ============================================================================


# Download and install Firefox
$FirefoxURL = "https://download.mozilla.org/?product=firefox-latest-ssl&os=win64&lang=en-US"
$FirefoxInstaller = Join-Path $env:TEMP "Firefox-Setup.exe"

Invoke-WebRequest -Uri $FirefoxURL -OutFile $FirefoxInstaller -UseBasicParsing

Start-Process -FilePath $FirefoxInstaller -ArgumentList "/S" -Wait

Remove-Item $FirefoxInstaller -Force -ErrorAction SilentlyContinue

# Install uBlock Origin extension
$FirefoxPath = "C:\Program Files\Mozilla Firefox"
$ExtensionsPath = Join-Path $FirefoxPath "distribution\extensions"
$UblockURL = "https://addons.mozilla.org/firefox/downloads/file/4598854/ublock_origin-1.67.0.xpi"
$UblockFile = "uBlock0@raymondhill.net.xpi"

if (-not (Test-Path $ExtensionsPath)) {
    New-Item -Path $ExtensionsPath -ItemType Directory -Force | Out-Null
}

Invoke-WebRequest -Uri $UblockURL -OutFile (Join-Path $ExtensionsPath $UblockFile) -UseBasicParsing

# Set Firefox as default browser

# Try using Firefox's built-in method first
$FirefoxExe = Join-Path $FirefoxPath "firefox.exe"
if (Test-Path $FirefoxExe) {
    Start-Process -FilePath $FirefoxExe -ArgumentList "-setDefaultBrowser" -Wait -WindowStyle Hidden
}

# Fallback: Open settings for manual configuration
Start-Process "ms-settings:defaultapps"






# ============================================================================
# STEP 8: WinSewView CONFIGURATION
# ============================================================================


& "$PSScriptRoot\WinSetView.ps1" "$PSScriptRoot\POSDefaults.ini"






irm "https://christitus.com/win" | iex

