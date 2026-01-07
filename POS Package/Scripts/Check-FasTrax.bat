@echo off 
REM Quick check if FasTrax is running properly after updates 
tasklist /FI "IMAGENAME eq FasTraxPOSWPF.exe" 2>NUL | find /I /N "FasTraxPOSWPF.exe">NUL 
if "%ERRORLEVEL%"=="0" ( 
    echo %date% %time% - FasTrax POS is running normally >> C:\Scripts\Logs\fastrax-status.log 
) else ( 
    echo %date% %time% - WARNING: FasTrax POS not detected >> C:\Scripts\Logs\fastrax-status.log 
) 
