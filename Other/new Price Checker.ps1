
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
# STEP 8: WinSewView CONFIGURATION
# ============================================================================

Write-LogMessage ("=" * 70) "Info"
Write-LogMessage "STEP 8: WinSetView CONFIGURATION" "Info"
Write-LogMessage ("=" * 70) "Info"

& "$PSScriptRoot\WinSetView.ps1" "$PSScriptRoot\POSDefaults.ini"

Write-LogMessage "WinSetView configuration applied from POSDefaults.ini" "Success"

irm "https://christitus.com/win" | iex

