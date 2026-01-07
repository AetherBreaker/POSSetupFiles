
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
# STEP 8: WinSewView CONFIGURATION
# ============================================================================

& "$PSScriptRoot\WinSetView.ps1" "$PSScriptRoot\POSDefaults.ini"

