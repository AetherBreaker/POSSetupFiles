
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





# ============================================================================
# STEP 1: SECURITY AND USER ACCOUNT CONFIGURATION
# ============================================================================



# Disable account lockout policies using net accounts (same as working batch script)
# Use net accounts commands like the working batch script
& net accounts /lockoutthreshold:0 2>&1 | Out-Null
& net accounts /lockoutduration:0 2>&1 | Out-Null
& net accounts /lockoutwindow:0 2>&1 | Out-Null
& net accounts /minpwage:0 2>&1 | Out-Null
& net accounts /maxpwage:unlimited 2>&1 | Out-Null
& net accounts /minpwlen:0 2>&1 | Out-Null




# ============================================================================
# STEP 3: POWER AND SLEEP SETTINGS
# ============================================================================


# Set power settings to never sleep when plugged in
powercfg /change monitor-timeout-ac 0
powercfg /change disk-timeout-ac 0
powercfg /change standby-timeout-ac 0
powercfg /change hibernate-timeout-ac 0

# Disable hybrid sleep
powercfg /h off



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

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

$LogoSource = Join-Path $ScriptDir "sft-logo-blackbg.jpg"
$LogoDestination = Join-Path $env:USERPROFILE "Pictures\sft-logo-blackbg.jpg"

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



# ============================================================================
# STEP 8: WinSewView CONFIGURATION
# ============================================================================

& "$PSScriptRoot\WinSetView.ps1" "$PSScriptRoot\POSDefaults.ini"

