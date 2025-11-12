$LogTimestamp = Get-Date -Format "yyyyMMdd_HHmmss"

$Logfile = "C:\ProgramData\FTX_Uninstaller_Nuke\Uninstall_Log_$LogTimestamp.log"

#Create New Folder for Uninstall
if (-not (Test-Path "C:\ProgramData\FTX_Uninstaller_Nuke")) {New-Item -ItemType Directory -Path "C:\ProgramData\FTX_Uninstaller_Nuke" | Out-Null }

function WriteLog
{
    Param ([string]$LogString)
    $LogString = $LogString.Trim()
    $LogString = "$LogString`r`n"
    $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $LogMessage = "$Stamp $LogString"
    Add-content $LogFile -value $LogMessage
    Write-Host "$LogString"
}

function WriteLogYellow
{
    Param ([string]$LogString)
    $LogString = $LogString.Trim()
    $LogString = "$LogString`r`n"
    $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $LogMessage = "$Stamp $LogString"
    Add-content $LogFile -value $LogMessage
    Write-Host "$LogString" -ForegroundColor Yellow
}

function WriteLogGreen
{
    Param ([string]$LogString)
    $LogString = $LogString.Trim()
    $LogString = "$LogString`r`n"
    $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $LogMessage = "$Stamp $LogString"
    Add-content $LogFile -value $LogMessage
    Write-Host "$LogString" -ForegroundColor Green
}

function WriteLogRed
{
    Param ([string]$LogString)
    $LogString = $LogString.Trim()
    $LogString = "$LogString`r`n"
    $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $LogMessage = "$Stamp $LogString"
    Add-content $LogFile -value $LogMessage
    Write-Host "$LogString" -ForegroundColor Red
}


Function Execute-Command ($commandTitle, $commandPath, $commandArguments)
{
  Try {
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $commandPath
    $pinfo.RedirectStandardError = $true
    $pinfo.RedirectStandardOutput = $true
    $pinfo.UseShellExecute = $false
    $pinfo.Verb = "runas";
    $pinfo.WindowStyle = "hidden"
    $pinfo.Arguments = $commandArguments
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    $p.WaitForExit()
    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()

    if (-not ([string]::IsNullOrEmpty($stderr)))
    {
        WriteLogRed "Error Output`r`n$stderr"

        if (-not ([string]::IsNullOrEmpty($p.ExitCode)))
        {
            WriteLogRed "Exit Code`r`n" + $p.ExitCode
        }
    }
    else 
    {
        WriteLog "$stdout`r`n"
    }
  }
  Catch {
    WriteLogRed "Exception occurred during command execution: $_"
  }
}

#Remove RabbitMQ
Function Remove-RabbitMQ
{
$userCookiePath = "$env:USERPROFILE\.erlang.cookie";

If ((Get-WmiObject win32_operatingsystem | select osarchitecture).osarchitecture -like "64*")
{
    $erlangSystem = "C:\Windows\SysWOW64\config\systemprofile\.erlang.cookie"
}
Else
{
    $erlangSystem = "C:\Windows\system32\config\systemprofile\.erlang.cookie"
}

if (Test-Path $userCookiePath) 
{
    WriteLog "Removing User Cookuie"
    Remove-Item $userCookiePath -Force
    WriteLogGreen "User Cookie Removed Successfully"
}
else
{
    WriteLogRed "User Cookie does not exist"
}

if (Test-Path $erlangSystem) 
{
    WriteLog "Removing System Cookuie"
    Remove-Item $erlangSystem -Force
    WriteLogGreen "System Cookie Removed Successfully"
}
else
{
    WriteLogRed "System Cookie does not exist"
}

# Check if service exists
$service = Get-Service -Name RabbitMQ -ErrorAction SilentlyContinue

WriteLogYellow "Checking if RabbitMQ service is installed..."

if ($service.Length -gt 0)
{
    WriteLogYellow "RabbitMQ service is setup and enabled..."

    WriteLogYellow "Removing Service..."
    Execute-Command "RemoveService" "C:\ProgramData\FTX_RabbitMQ\RabbitMQ\rabbitmq_server-3.11.10\sbin\rabbitmq-service.bat" "remove"
}
else 
{
    WriteLogGreen "Service is already removed"
}

WriteLogYellow "Checking RabbitMQ Log/DB Folders..."

$dbFolder = "C:\ProgramData\FTX_RabbitMQ\RabbitMQ\db";
$logFolder = "C:\ProgramData\FTX_RabbitMQ\RabbitMQ\log";

if (Test-Path $dbFolder) 
{
    WriteLog "Removing DB Folder"
    Remove-Item $dbFolder -Force -Recurse
    WriteLogGreen "DB Folder Removed Successfully"
}
else
{
    WriteLogRed "DB Folder does not exist"
}

if (Test-Path $logFolder) 
{
    WriteLog "Removing Log Folder"
    Remove-Item $logFolder -Force -Recurse
    WriteLogGreen "Log Folder Removed Successfully"
}
else
{
    WriteLogRed "Log Folder does not exist"
}

WriteLogYellow "Checking Registry..."

if (Test-path HKLM:\SOFTWARE\Wow6432Node\Ericsson\Erlang\ErlSrv)
{
    WriteLogYellow "Removing 64-Bit Registry Key..."
    Remove-Item -Path HKLM:\SOFTWARE\Wow6432Node\Ericsson\Erlang\ErlSrv -Force -Verbose -Recurse
}

if (Test-path HKLM:\SOFTWARE\Ericsson\Erlang\ErlSrv)
{
    WriteLogYellow "Removing 32-Bit Registry Key..."
    Remove-Item -Path HKLM:\SOFTWARE\Ericsson\Erlang\ErlSrv -Force -Verbose -Recurse
}

WriteLogGreen "Successfully cleared RabbitMQ service from system"
}

#Uninstall FTX-POS
# Function to uninstall FTX POS
function UninstallFTXPOS
{
    WriteLog "Starting FTX POS uninstallation..."

        $uninstallKey32 = Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -eq "FTX POS" }
        if ($uninstallKey32) {
            $uninstallString32 = $uninstallKey32.QuietUninstallString
            WriteLog "Found FTX POS uninstall string in 32-bit registry location."
            try {
                Start-Process cmd.exe -ArgumentList "/c $uninstallString32 /uninstall " -Wait -NoNewWindow -PassThru
                WriteLogGreen "FTX POS uninstallation completed successfully."
            } catch {
                WriteLogRed "Error occurred during FTX POS uninstallation: $_"
            }
        } else {
            WriteLogYellow "FTX POS not found."
       # }
    }
}

#UninstallPostgres
function UninstallPostgres
{
    WriteLog "Starting Postgres uninstallation..."
	WriteLogYellow "Please Note: Uninstallation may take a few minutes..."
	
    $uninstallString = "C:\Program Files (x86)\PostgreSQL\10\uninstall-postgresql.exe"
    try {
        Start-Process $uninstallString -ArgumentList "--mode unattended" -Wait -NoNewWindow -PassThru
        WriteLogGreen "Postgres uninstallation completed successfully."
    } catch {
        WriteLogRed "Error occurred during Posgres uninstallation: $_"
    }
	
	#Remove CHild items in Folder
	$programFilesFolder = "C:\Program Files (x86)\PostgreSQL"
	if (Test-Path $programFilesFolder) { 
	Get-ChildItem -path $ProgramFilesFolder -Recurse | Remove-Item -Force -Recurse
	
	#Remove the empty Folder 
	Remove-Item -path $programFilesFolder -Force
	WriteLogGreen "PostGreSQL Program Files Folder has been Deleted." 
	}
	Else{
	WriteLogRed "PostgresSQL Program Files Folder not found" }
	
}

#Final Cleanup
function FinalCleanup
{

	$folders = @(
    "$env:ProgramData\Prerequisites",
    "$env:ProgramData\FasTraxPOS",
    "$env:ProgramData\FasTraxPOSMasterUtility",
    "$env:ProgramData\FTX_RabbitMQ",
    "$env:ProgramFiles(x86)\FasTraxPOS\FTX POS",
	"$env:APPDATA\pgAdmin",
    "$env:LOCALAPPDATA\VirtualStore\Program Files (x86)\FasTraxPOS",
    "$env:LOCALAPPDATA\VirtualStore\ProgramData\FasTraxPOS"
	)



foreach ($folder in $folders) {
    WriteLog "Checking if folder exists: $folder"
    if (Test-Path $folder) {
        WriteLogGreen "Folder $folder exists."
        try {
            Remove-Item -Path $folder -Force -Recurse -ErrorAction Stop
            WriteLogGreen "Folder $folder and all its content have been removed."
        } catch {
            WriteLogRed "Error occurred while deleting $folder,: $_"
        }
    } else {
        WriteLogRed "Folder $folder does not exist."
    }
}
}


#Execution of Script 

Remove-RabbitMQ
UninstallFTXPOS
UninstallPostgres
FinalCleanup
