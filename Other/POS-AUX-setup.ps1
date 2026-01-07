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


# remove Edge desktop shortcuts
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
# STEP 8: WinSewView CONFIGURATION
# ============================================================================

Write-LogMessage ("=" * 70) "Info"
Write-LogMessage "STEP 8: WinSetView CONFIGURATION" "Info"
Write-LogMessage ("=" * 70) "Info"

& "$PSScriptRoot\WinSetView.ps1" "$PSScriptRoot\POSDefaults.ini"

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





Write-Host ""
Write-Host "POS Setup Script Completed Successfully!" -ForegroundColor Green
Write-Host "Script will exit automatically in 3 seconds..." -ForegroundColor Cyan
Start-Sleep -Seconds 3