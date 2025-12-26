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


# ============================================================================
# STEP 1: SECURITY AND USER ACCOUNT CONFIGURATION
# ============================================================================


# Get current username
$CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name.Split('\')[1]
Write-LogMessage "Current user: $CurrentUser" "Info"


# Clear password for current user
# Use net user command like the working batch script
& net user $CurrentUser "" 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-LogMessage "Password removed from $CurrentUser" "Success"
}
else {
    Write-LogMessage "Failed to remove password from $CurrentUser" "Warning"
}
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


# press enter to exit
Write-Host "Press Enter to exit..."