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
# STEP 10: Enable Force Biometrics in FTX config
# ============================================================================

Write-LogMessage ("=" * 70) "Info"
Write-LogMessage "STEP 10: Enable Force Biometrics in FTX config" "Info"
Write-LogMessage ("=" * 70) "Info"

$iniFilePath = "C:\ProgramData\FasTraxPOS\Config\FTXConfiguration.ini" # Replace with your INI file path
$targetSection = "[POS]" # Replace with your target section name
$newLineToAdd = "ForceBiometricTimeClock=1" # Replace with the line you want to add

$iniContent = Get-Content -Path $iniFilePath
$newContent = @()
$inTargetSection = $false
$lineAlreadyExists = $false

# First check if the file exists
if (Test-Path $iniFilePath) {
    foreach ($line in $iniContent) {
        $newContent += $line # Add the current line to the new content

        if ($line.Trim() -eq $targetSection) {
            $inTargetSection = $true
            # Check if the line to add already exists in the section (after the section header)
            # This assumes the line would appear immediately after the section header or later within the section.
            # A more robust check might involve iterating until the next section or end of file.
            $remainingContent = $iniContent | Select-Object -Skip (($iniContent.IndexOf($line)) + 1)
            if ($remainingContent -match "^$([regex]::Escape($newLineToAdd))$") {
                $lineAlreadyExists = $true
            }
        }
        elseif ($inTargetSection -and $line.Trim().StartsWith("[")) {
            # If we encounter another section header, we are no longer in the target section
            $inTargetSection = $false
        }

        # If we are in the target section and the line hasn't been added yet, and it doesn't already exist
        if ($inTargetSection -and -not $lineAlreadyExists -and $line.Trim() -notmatch "^$([regex]::Escape($newLineToAdd))$") {
            # This condition will add the line only once, right after the section header.
            # If you want it at the end of the section, you would need to buffer lines until the next section or end of file.
            if ($line.Trim() -eq $targetSection) {
                $newContent += $newLineToAdd
                $lineAlreadyExists = $true # Mark as added to prevent multiple additions
            }
        }
    }

    # If the section was found and the line was not added within the loop (e.g., if it needs to be at the very end of the section)
    # This part is more complex and depends on where exactly you want the line if the section is empty or the line should be last.
    # For simplicity, the above code adds it directly after the section header if not present.

    $newContent | Set-Content -Path $iniFilePath -Force
}
else {
    Write-LogMessage "INI file not found: $iniFilePath" "Error"
}


# ============================================================================
# STEP 11: DEVICE DRIVER INSTALLATIONS
# ============================================================================

Write-LogMessage ("=" * 70) "Info"
Write-LogMessage "STEP 11: DEVICE DRIVER INSTALLATIONS" "Info"
Write-LogMessage ("=" * 70) "Info"

$ManualInstallRequired = @()

# Epson OPOS ADK
$EpsonInstaller = Join-Path $ScriptDir "Installer Files Directory\FTX Device Drivers\EPSON_OPOS_ADK_V3.00ER26.exe"
if (Test-Path $EpsonInstaller) {
    $Result = Install-SilentlyIfPossible -InstallerPath $EpsonInstaller -ProductName "Epson OPOS ADK" -SilentArgs @("/SILENT", "/VERYSILENT", "/S")
    if (-not $Result) { $ManualInstallRequired += "Epson OPOS ADK" }
}
else {
    Write-LogMessage "Epson OPOS ADK installer not found" "Warning"
}

# Zebra Scanner SDK
$ZebraSDKInstaller = Join-Path $ScriptDir "Installer Files Directory\FTX Device Drivers\Zebra_Scanner_SDK_(64bit)_v3.05.0005.exe"
if (Test-Path $ZebraSDKInstaller) {
    Write-LogMessage "Zebra Scanner SDK requires manual installation due to custom interface" "Warning"
    if (-not $SkipManualInstallers) {
        Start-Process -FilePath $ZebraSDKInstaller -Wait
    }
    else {
        $ManualInstallRequired += "Zebra Scanner SDK"
    }
}
else {
    Write-LogMessage "Zebra Scanner SDK installer not found" "Warning"
}

# HP Pole Display OPOS Drivers
$HPPoleInstaller = Join-Path $ScriptDir "Installer Files Directory\FTX Device Drivers\HP Pole Display OPOS\setup.exe"
if (Test-Path $HPPoleInstaller) {
    Write-LogMessage "HP Pole Display installer requires manual installation - launching installer" "Warning"
    if (-not $SkipManualInstallers) {
        Start-Process -FilePath $HPPoleInstaller -Wait
        Write-LogMessage "Please ensure ALL checkboxes are selected in the HP Pole Display installer" "Warning"
    }
    else {
        $ManualInstallRequired += "HP Pole Display OPOS Drivers"
    }
}
else {
    Write-LogMessage "HP Pole Display installer not found" "Warning"
}

# TouchPoint Fingerprint Driver
$TouchPointInstaller = Join-Path $ScriptDir "Installer Files Directory\FTX Device Drivers\touchpoint Fingerprint Driver\setup.msi"
if (Test-Path $TouchPointInstaller) {
    try {
        Write-LogMessage "Installing TouchPoint Fingerprint Driver..." "Info"
        $msiArgs = @(
            "/i",
            "`"$TouchPointInstaller`"",
            "/quiet",
            "/norestart"
        )
        $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru
        if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
            Write-LogMessage "TouchPoint Fingerprint Driver installed (restart will be performed later)" "Success"
        }
        else {
            Write-LogMessage "TouchPoint installation returned code: $($process.ExitCode)" "Warning"
        }
    }
    catch {
        Write-LogMessage "Failed to install TouchPoint Fingerprint Driver: $_" "Error"
    }
}
else {
    Write-LogMessage "TouchPoint Fingerprint Driver installer not found" "Warning"
}

# PAX USB Driver
$PAXInstaller = Join-Path $ScriptDir "Installer Files Directory\FTX Device Drivers\PAX USBDriver_v2.26_20190508\USBDriver.exe"
if (Test-Path $PAXInstaller) {
    $Result = Install-SilentlyIfPossible -InstallerPath $PAXInstaller -ProductName "PAX USB Driver" -SilentArgs @("/S", "/silent")
    if (-not $Result) { $ManualInstallRequired += "PAX USB Driver" }
}
else {
    Write-LogMessage "PAX USB Driver installer not found" "Warning"
}

# Datacap Drivers
$DatacapEMV = Join-Path $ScriptDir "Installer Files Directory\FTX Device Drivers\dsiEMVUS-179-Install20240702-W8.exe"
$DatacapPDCX = Join-Path $ScriptDir "Installer Files Directory\FTX Device Drivers\dsiPDCX-194-Install20240702-W8.exe"

if (Test-Path $DatacapEMV) {
    Write-LogMessage "Datacap EMV driver requires manual installation due to setup prompts" "Warning"
    if (-not $SkipManualInstallers) {
        Start-Process -FilePath $DatacapEMV -Wait
        Write-LogMessage "Organization name and domain can be left blank" "Info"
    }
    else {
        $ManualInstallRequired += "Datacap EMV Driver"
    }
}
else {
    Write-LogMessage "Datacap EMV driver installer not found" "Warning"
}

if (Test-Path $DatacapPDCX) {
    Write-LogMessage "Datacap PDCX driver requires manual installation due to setup prompts" "Warning"
    if (-not $SkipManualInstallers) {
        Start-Process -FilePath $DatacapPDCX -Wait
        Write-LogMessage "Organization name and domain can be left blank" "Info"
    }
    else {
        $ManualInstallRequired += "Datacap PDCX Driver"
    }
}
else {
    Write-LogMessage "Datacap PDCX driver installer not found" "Warning"
}

# NET ePay Director Manager
$NetEpayInstaller = Join-Path $ScriptDir "Installer Files Directory\FTX Device Drivers\NETePay-Director-Manager-Install20200814-W8 (6).exe"
if (Test-Path $NetEpayInstaller) {
    Write-LogMessage "NET ePay Director Manager requires manual installation" "Warning"
    if (-not $SkipManualInstallers) {
        Start-Process -FilePath $NetEpayInstaller -Wait
        Write-LogMessage "IMPORTANT: Click CANCEL on the activation prompt - activation is done later during FTX setup" "Warning"
        Write-Host ""
        Write-Host "CRITICAL: When prompted for activation, click CANCEL!" -ForegroundColor Red -BackgroundColor Yellow
        Write-Host "Activation will be done later during credit card machine setup by FTX" -ForegroundColor Yellow
        Write-Host ""
    }
    else {
        $ManualInstallRequired += "NET ePay Director Manager"
    }
}
else {
    Write-LogMessage "NET ePay Director Manager installer not found" "Warning"
}

# ============================================================================
# STEP 12: SCHEDULED TASKS AND UPDATES
# =======================================================================

Write-LogMessage ("=" * 70) "Info"
Write-LogMessage "STEP 12: SCHEDULED TASKS AND UPDATES" "Info"
Write-LogMessage ("=" * 70) "Info"

# Create Scripts directory structure
$ScriptsPath = "C:\Scripts"
$LogsPath = "C:\Scripts\Logs"
$BackupPath = "C:\Scripts\Backup"

foreach ($path in @($ScriptsPath, $LogsPath, $BackupPath)) {
    if (-not (Test-Path $path)) {
        New-Item -Path $path -ItemType Directory -Force | Out-Null
        Write-LogMessage "Created directory: $path" "Info"
    }
}

# Copy update scripts if they exist
$UpdateScriptsSource = Join-Path $ScriptDir "Scripts"
if (Test-Path $UpdateScriptsSource) {
    Write-LogMessage "Copying update scripts..." "Info"
    try {
        Copy-Item -Path "$UpdateScriptsSource\*" -Destination $ScriptsPath -Force -Recurse
        Write-LogMessage "Update scripts copied to C:\Scripts" "Success"
    }
    catch {
        Write-LogMessage "Failed to copy update scripts: $_" "Error"
    }
}

# Configure Windows Update service
try {
    Set-Service -Name "wuauserv" -StartupType Automatic
    Start-Service -Name "wuauserv" -ErrorAction SilentlyContinue

    # Configure automatic updates
    $WUPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    $AUPath = "$WUPath\AU"

    if (-not (Test-Path $WUPath)) {
        New-Item -Path $WUPath -Force | Out-Null
    }
    if (-not (Test-Path $AUPath)) {
        New-Item -Path $AUPath -Force | Out-Null
    }

    Set-ItemProperty -Path $AUPath -Name "NoAutoUpdate" -Value 0
    Set-ItemProperty -Path $AUPath -Name "AUOptions" -Value 4  # Auto download and schedule install
    Set-ItemProperty -Path $AUPath -Name "ScheduledInstallDay" -Value 0  # Every day
    Set-ItemProperty -Path $AUPath -Name "ScheduledInstallTime" -Value 2  # 2 AM

    Write-LogMessage "Windows Update configured for automatic updates" "Success"
}
catch {
    Write-LogMessage "Failed to configure Windows Update: $_" "Error"
}

# Create scheduled task for FasTrax updates (2 AM)
try {
    $UpdateScriptPath = Join-Path $ScriptsPath "POS-Update.bat"
    if (Test-Path $UpdateScriptPath) {
        # Remove existing task if it exists
        & schtasks /delete /tn "FasTrax_NightlyUpdate" /f 2>$null

        # Create new scheduled task
        $taskXml = @"
<?xml version=`"1.0`" encoding=`"UTF-16`"?>
<Task version=`"1.2`" xmlns=`"http://schemas.microsoft.com/windows/2004/02/mit/task`">
  <Triggers>
    <CalendarTrigger>
      <StartBoundary>2024-01-01T02:00:00</StartBoundary>
      <Enabled>true</Enabled>
      <ScheduleByDay>
        <DaysInterval>1</DaysInterval>
      </ScheduleByDay>
    </CalendarTrigger>
  </Triggers>
  <Principals>
    <Principal id=`"Author`">
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>false</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>true</WakeToRun>
    <ExecutionTimeLimit>PT2H</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context=`"Author`">
    <Exec>
      <Command>$UpdateScriptPath</Command>
    </Exec>
  </Actions>
</Task>
"@
        $taskXmlPath = Join-Path $env:TEMP "fastrax_update_task.xml"
        $taskXml | Out-File -FilePath $taskXmlPath -Encoding Unicode

        & schtasks /create /tn "FasTrax_NightlyUpdate" /xml $taskXmlPath /f

        if ($LASTEXITCODE -eq 0) {
            Write-LogMessage "Scheduled task for FasTrax nightly updates created successfully (2:00 AM)" "Success"
        }
        else {
            Write-LogMessage "Failed to create FasTrax update scheduled task" "Error"
        }

        Remove-Item $taskXmlPath -Force -ErrorAction SilentlyContinue
    }
    else {
        Write-LogMessage "POS-Update.bat not found - FasTrax update task not created" "Warning"
    }
}
catch {
    Write-LogMessage "Failed to create FasTrax update task: $_" "Error"
}

# Create scheduled task for nightly Windows updates (2 AM - matches the batch file)
try {
    # Create Windows update script
    $WindowsUpdateScript = @'
@echo off
echo %date% %time% - Windows Update check initiated >> C:\Scripts\Logs\windows-update.log
powershell -Command "Install-Module PSWindowsUpdate -Force -ErrorAction SilentlyContinue; Get-WindowsUpdate -Install -AcceptAll -IgnoreReboot" >> C:\Scripts\Logs\windows-update.log 2>&1
echo %date% %time% - Windows Update check completed >> C:\Scripts\Logs\windows-update.log
'@

    $WindowsUpdateScriptPath = Join-Path $ScriptsPath "Windows-Update.bat"
    $WindowsUpdateScript | Out-File -FilePath $WindowsUpdateScriptPath -Encoding ASCII

    # Create scheduled task
    & schtasks /delete /tn "POS_WindowsUpdate" /f 2>$null
    & schtasks /create /tn "POS_WindowsUpdate" `
        /tr "`"$WindowsUpdateScriptPath`"" `
        /sc daily `
        /st 02:00 `
        /rl highest `
        /f

    Write-LogMessage "Scheduled task for Windows updates created (2:00 AM daily)" "Success"
}
catch {
    Write-LogMessage "Failed to create Windows update task: $_" "Error"
}

# Create scheduled task for nightly restart (3 AM)
try {
    # Create restart script
    $RestartScript = @'
@echo off
echo %date% %time% - Nightly restart initiated >> C:\Scripts\Logs\restart.log
shutdown /r /t 60 /c "Scheduled nightly restart for POS system maintenance"
'@

    $RestartScriptPath = Join-Path $ScriptsPath "Nightly-Restart.bat"
    $RestartScript | Out-File -FilePath $RestartScriptPath -Encoding ASCII

    # Create scheduled task
    & schtasks /delete /tn "POS_NightlyRestart" /f 2>$null
    & schtasks /create /tn "POS_NightlyRestart" `
        /tr "`"$RestartScriptPath`"" `
        /sc daily `
        /st 03:00 `
        /rl highest `
        /f

    Write-LogMessage "Scheduled task for nightly restart created (3:00 AM daily)" "Success"
}
catch {
    Write-LogMessage "Failed to create nightly restart task: $_" "Error"
}

# ============================================================================
# STEP 13: ADDITIONAL SOFTWARE (ZOHO ASSIST & ZEBRA 123SCAN)
# ============================================================================

Write-LogMessage ("=" * 70) "Info"
Write-LogMessage "STEP 13: ADDITIONAL SOFTWARE" "Info"
Write-LogMessage ("=" * 70) "Info"

# Zoho Assist
Write-LogMessage "Zoho Assist requires manual download and installation from the FTX web link" "Warning"
Write-LogMessage "Visit the FTX Zoho Unattended Installer link to download and install" "Info"
$ManualInstallRequired += "Zoho Assist (download from FTX link)"

# Zebra 123Scan
$Zebra123ScanPath = Join-Path $ScriptDir "Installer Files Directory\FTX Device Drivers\123Scan2_v2.1.exe"
if (Test-Path $Zebra123ScanPath) {
    Write-LogMessage "Found Zebra 123Scan installer locally" "Info"
    if (-not $SkipManualInstallers) {
        Start-Process -FilePath $Zebra123ScanPath -Wait
    }
    else {
        $ManualInstallRequired += "Zebra 123Scan"
    }
}
else {
    Write-LogMessage "Zebra 123Scan installer not found locally - requires download from Google Drive" "Warning"
    $ManualInstallRequired += "Zebra 123Scan (download from Google Drive link)"
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

if ($ManualInstallRequired.Count -gt 0) {
    Write-Host "The following components require manual installation:" -ForegroundColor Yellow
    Write-Host "=" * 60 -ForegroundColor Yellow
    foreach ($component in $ManualInstallRequired) {
        Write-Host "  - $component" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "Manual Installation Notes:" -ForegroundColor Cyan
    Write-Host "1. Epson OPOS ADK - May require interaction with installer" -ForegroundColor White
    Write-Host "2. Zebra Scanner SDK - Custom installer interface" -ForegroundColor White
    Write-Host "3. Zebra 123Scan - Download from Google Drive link if not found" -ForegroundColor White
    Write-Host "4. HP Pole Display - Check ALL boxes in installer" -ForegroundColor White
    Write-Host "5. Datacap Drivers - Leave organization/domain fields blank" -ForegroundColor White
    Write-Host "6. NET ePay Director - Click CANCEL on activation prompt" -ForegroundColor White
    Write-Host "7. Zoho Assist - Download from FTX unattended installer link" -ForegroundColor White
    Write-Host ""
}

Write-Host "Completed Configurations:" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Green
Write-Host "  [OK] Windows Update configured" -ForegroundColor Green
Write-Host "  [OK] Scheduled tasks created:" -ForegroundColor Green
Write-Host "    • FasTrax updates: 2:00 AM daily" -ForegroundColor Green
Write-Host "    • Windows updates: 2:00 AM daily" -ForegroundColor Green
Write-Host "    • System restart: 3:00 AM daily" -ForegroundColor Green
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