# Self-elevate the script if required
if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
  if ([int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000) {
    $CommandLine = "-File `"" + $MyInvocation.MyCommand.Path + "`" " + $MyInvocation.UnboundArguments
    Start-Process -FilePath PowerShell.exe -Verb Runas -ArgumentList $CommandLine
    Exit
  }
}


Write-Output "Disabling Windows Firewall..."
Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled False


Write-Output "Creating backup user account..."
$backupUser = "BackupAdmin"
$backupPass = "BackupPass123!"
New-LocalUser -Name "$backupUser" -Password (ConvertTo-SecureString "$backupPass" -AsPlainText -Force) -FullName "Backup Administrator" -Description "User account for backup operations" -PasswordNeverExpires -AccountNeverExpires
Add-LocalGroupMember -Group "Administrators" -Member "$backupUser"

Write-Output "Resetting current user's password..."
$currentUser = (Get-WmiObject -Class Win32_ComputerSystem).UserName.Split("\")[1]
$UserAccount = Get-LocalUser -Name "$currentUser"
$UserAccount | Set-LocalUser -Password ([securestring]::new())


Write-Output "Configuring Auto Admin Logon..."
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoAdminLogon" -Value "1"
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "DefaultUserName" -Value "$currentUser"
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "DefaultPassword" -Value ""

Write-Output "Setting security policies..."
secedit /configure /db c:\windows\security\local.sdb /cfg "$PSScriptRoot\secpol.cfg" /areas SECURITYPOLICY


$FirefoxSource = "https://download.mozilla.org/?product=firefox-latest-ssl&os=win64&lang=en-US"
$Installer = "$ENV:TEMP\MozillaFirefox.exe"

Invoke-WebRequest -Uri $FirefoxSource -OutFile $Installer
Start-Process -FilePath $Installer -ArgumentList "/s" -Wait -Verb RunAs
Remove-Item $Installer


$UblockSource = "https://addons.mozilla.org/firefox/downloads/file/4598854/ublock_origin-1.67.0.xpi"
$ExtensionFolderPath = "C:\Program Files\Mozilla Firefox\distribution\extensions"
$ExtensionFileName = "uBlock0@raymondhill.net.xpi"

if (-not (Test-Path $ExtensionFolderPath)) {
  New-Item -Path $ExtensionFolderPath -ItemType Directory
}
Invoke-WebRequest -Uri $UblockSource -OutFile "$ExtensionFolderPath\$ExtensionFileName"

.\WinSetView.ps1 .\POSDefaults.ini

Write-Host "Press Enter to exit..." -NoNewline
$null = Read-Host