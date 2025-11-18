
# Steps

1. Run Winutil to perform tweaks cmd: "irm "https://christitus.com/win" | iex"
2. Disable the windows firewall for public, private, and domain networks
3. Setup automatic windows updates [Setup-POS-Updates.bat](https://github.com/AetherBreaker/POSSetupFiles/blob/main/Update%20Scripts/Setup-POS-Updates.bat)
    - Fastrax updates
    - Windows updates
    - Nightly Windows restarts
4. Configure the backup admin account. (Note: Please do not save the account credentials on any files on the computer. I don't want store employees finding and using these credentials)
    - Disabling Windows GPO policies for account lockout after too many failed password attempts (As done in [run-security-scripts.bat](https://github.com/AetherBreaker/POSSetupFiles/blob/main/run-security-scripts.bat))
    - Setup autologin (as done in [run-security-scripts.bat](https://github.com/AetherBreaker/POSSetupFiles/blob/main/run-security-scripts.bat))
5. Change windows power and sleep settings so the PC never goes to sleep while plugged in.
6. Move [sft-logo-blackbg.jpg](https://github.com/AetherBreaker/POSSetupFiles/blob/main/sft-logo-blackbg.jpg) file to the current user's pictures directory then set it as the desktop background in "Fit" mode.
7. Make Windows set the time zone automatically
    - Note: Location services will need to be enabled first (and allow other apps to access location info) before Windows will let this setting be enabled
    - The windows image I use automatically has location services disabled, so you cannot assume location services will be on before this script is ran.
8. Download and install FireFox.
    - Set Firefox as the default browser in Windows
    - Add UBlock Origin extension to FireFox (Source: <https://addons.mozilla.org/en-US/firefox/addon/ublock-origin/>)
    - Pin Firefox to taskbar
    - Unpin edge from taskbar and delete it's shortcut from the desktop so it isn't used accidentally
9. Install Zoho Assist via the following link: [FTX Zoho Unattended Installer Download](https://assist.zoho.com/unattended-installer?encapiKey=wSsVRa0g%2FhDzCPgvnjKpIb05zV9RB1mlQxx80VL163euTfDBosc8khDLUFKhTfgfFDQ4RmFGp%2B4rykwHgDMIidp5yF9UACiF9mqRe1U4J3x1p7rvlz7JVm1dkxOIL4wMzw5jmw%3D%3D&x-com-zoho-assist-orgid=767936559)
   - This link doesn't automatically download, as it has you pick between an exe or msi installer first. See if you can find a way to get this downloaded and ran from command line.
10. Turn on the following Windows features:
    - .NET Framework 3.5
    - .NET Framework 4.8 Advanced Services/ASP.NET 4.8 (This is required by .NET Framework 3.5)
    - Note: This step tends to stall and error out on the first attempt, so it may require retry logic, or may even have to be done manually.
11. Install MSODBC SQL Driver
    - [msodbcsql_x64.msi](https://github.com/AetherBreaker/POSSetupFiles/blob/main/Installer%20Files%20Directory/FTX%20Pre-reqs/msodbcsql_x64.msi) for 64 bit systems
    - [msodbcsql_x86.msi](https://github.com/AetherBreaker/POSSetupFiles/blob/main/Installer%20Files%20Directory/FTX%20Pre-reqs/msodbcsql_x86.msi) for 32 bit systems
12. Install [PosForDotNet-1.14.1.msi](https://github.com/AetherBreaker/POSSetupFiles/blob/main/Installer%20Files%20Directory/FTX%20Pre-reqs/PosForDotNet-1.14.1.msi)
13. Install [SSCERuntime_x64-ENU.exe](https://github.com/AetherBreaker/POSSetupFiles/blob/main/Installer%20Files%20Directory/FTX%20Pre-reqs/SSCERuntime_x64-ENU.exe)
14. Install [Epson OPOS ADK](https://github.com/AetherBreaker/POSSetupFiles/blob/main/Installer%20Files%20Directory/FTX%20Device%20Drivers/EPSON_OPOS_ADK_V3.00ER26.exe)
    - This will likely need to be done manually, but attempt to make it work in a script anyway please
15. Install the [Zebra Scanner SDK](https://github.com/AetherBreaker/POSSetupFiles/blob/main/Installer%20Files%20Directory/FTX%20Device%20Drivers/Zebra_Scanner_SDK_(64bit)_v3.05.0005.exe)
    - Likely won't work from command line due to it's unique installer interface. But please test if the installer accepts command line arguements just incase
16. Install [Zebra 123Scan](https://drive.google.com/file/d/12mLVMZkAGPiADoUY7aBnQk-SRWv5jWoX/view?usp=sharing)
    - This file was too big to upload to Github so the link provided is through google drive. But this file will be located in [this folder](https://github.com/AetherBreaker/POSSetupFiles/tree/main/Installer%20Files%20Directory/FTX%20Device%20Drivers)
    - Likely won't work from command line due to it's unique installer interface. But please test if the installer accepts command line arguements just incase
17. Install the [HP Pole Display OPOS Drivers](https://github.com/AetherBreaker/POSSetupFiles/blob/main/Installer%20Files%20Directory/FTX%20Device%20Drivers/HP%20Pole%20Display%20OPOS/setup.exe)
    - Requires the full contents of the folder it is located in: [Folder](https://github.com/AetherBreaker/POSSetupFiles/tree/main/Installer%20Files%20Directory/FTX%20Device%20Drivers/HP%20Pole%20Display%20OPOS)
    - Every box in the installer should be checked.
18. Install the [Touchpoint Fingerprint Driver](https://github.com/AetherBreaker/POSSetupFiles/blob/main/Installer%20Files%20Directory/FTX%20Device%20Drivers/touchpoint%20Fingerprint%20Driver/setup.msi)
    - Requires the full contents of the folder it is located in: [Folder](https://github.com/AetherBreaker/POSSetupFiles/tree/main/Installer%20Files%20Directory/FTX%20Device%20Drivers/touchpoint%20Fingerprint%20Driver)
    - This installer prompts the user for a restart upon completion, which may prevent running this from command line. But if possible from command line, do not restart after this install. We will be restarting after all the other installs are finished.
19. Install the [PAX USB Driver](https://github.com/AetherBreaker/POSSetupFiles/blob/main/Installer%20Files%20Directory/FTX%20Device%20Drivers/PAX%20USBDriver_v2.26_20190508/USBDriver.exe)
    - Requires the full contents of the [folder](https://github.com/AetherBreaker/POSSetupFiles/tree/main/Installer%20Files%20Directory/FTX%20Device%20Drivers/PAX%20USBDriver_v2.26_20190508) it is located in
20. Install the Datacap Drivers:
    - [dsiEMVUS-179-Install20240702-W8.exe](https://github.com/AetherBreaker/POSSetupFiles/blob/main/Installer%20Files%20Directory/FTX%20Device%20Drivers/dsiEMVUS-179-Install20240702-W8.exe)
    - [dsiPDCX-194-Install20240702-W8.exe](https://github.com/AetherBreaker/POSSetupFiles/blob/main/Installer%20Files%20Directory/FTX%20Device%20Drivers/dsiPDCX-194-Install20240702-W8.exe)
    - Note: These installs request some info like organization name, domain, etc. These can be left blank, but will likely prevent these from being installed by command line
21. Install [NET ePay Director Manager](https://github.com/AetherBreaker/POSSetupFiles/blob/main/Installer%20Files%20Directory/FTX%20Device%20Drivers/NETePay-Director-Manager-Install20200814-W8%20(6).exe):
    - Once installed, it will request activation. User must hit cancel on the activation as this step is performed later when the credit card machine is setup by FTX. Likely cannot be done from command line.
22. Install [Epson TM-T88VI Utility](https://drive.google.com/file/d/11KmFe2KBC-5q2LPrVfuaJMBUzd3E2CGZ/view?usp=sharing)
    - This file was also too big to be uploaded to github, but it will be located in [this folder](https://github.com/AetherBreaker/POSSetupFiles/tree/main/Installer%20Files%20Directory/FTX%20Device%20Drivers)
23. Enable ForceBiometricTimeClock=1
    - File location is: C:\ProgramData\FasTraxPOS\Config\FTXConfiguration.ini