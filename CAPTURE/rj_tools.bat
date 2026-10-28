@echo off
color 0A
title Rj's Network Tools
setlocal enabledelayedexpansion

:: Create information.txt
if not exist "information.txt" (
    echo ======================================== > "information.txt"
    echo          STUN IP CAPTURE LOG             >> "information.txt"
    echo ======================================== >> "information.txt"
    echo. >> "information.txt"
)

:menu
cls
echo.
echo ========================================
echo         RJ'S NETWORK TOOLS
echo ========================================
echo               by: rjewi
echo ========================================
echo.
echo Select an option:
echo.
echo [1] STUN IP Puller with Auto-Lookup
echo [2] IP Info Lookup Only
echo [3] View information.txt
echo [4] Exit
echo.
set /p "choice=Option: "

if "%choice%"=="1" goto stun_puller
if "%choice%"=="2" goto ip_lookup
if "%choice%"=="3" goto view_log
if "%choice%"=="4" exit /b
echo Invalid option!
pause
goto menu

:view_log
cls
if exist "information.txt" (
    type "information.txt"
) else (
    echo No log file found yet.
)
echo.
pause
goto menu

:stun_puller
cls
echo Getting your public IP...
for /f "usebackq delims=" %%i in (`PowerShell -NoProfile -Command "(Invoke-WebRequest -Uri 'https://ifconfig.me/ip' -UseBasicParsing).Content.Trim()" 2^>nul`) do set "PublicIP=%%i"

if not defined PublicIP (
    echo Failed to retrieve public IP.
    pause
    goto menu
)
echo Your Public IP: %PublicIP%
echo.

:: Find tshark
set "tshark="
if exist "C:\Program Files\Wireshark\tshark.exe" set "tshark=C:\Program Files\Wireshark\tshark.exe"
if exist "C:\Program Files (x86)\Wireshark\tshark.exe" set "tshark=C:\Program Files (x86)\Wireshark\tshark.exe"

if not defined tshark (
    echo Wireshark not found. Please install Wireshark first.
    pause
    goto menu
)

echo tshark found at: %tshark%
echo.
echo Available network interfaces:
echo.
"%tshark%" -D
echo.
set /p "interface=Enter interface number (or 0 to cancel): "

if "%interface%"=="0" goto menu

:: Validate input
echo %interface%|findstr /r "^[0-9][0-9]*$" >nul
if errorlevel 1 (
    echo Invalid interface number!
    pause
    goto stun_puller
)

cls
echo ============================================================
echo STUN IP Puller - Monitoring for new IPs
echo ============================================================
echo.
echo Your Public IP: %PublicIP%
echo Using interface: %interface%
echo Saving to: information.txt
echo.
echo Press Ctrl+C to stop monitoring
echo.
echo Discovered IPs:
echo.

set "tempfile=%temp%\stun_ips_%random%.txt"
type nul > "%tempfile%"

:: SIMPLIFIED VERSION - Just capture all STUN packets first
echo Waiting for STUN packets...
echo.

:loop
:: Use a simple filter first to test
for /f "usebackq delims=" %%a in (`""%tshark%" -i %interface% -Y "stun" -T fields -e ip.src -a duration:2 2>nul"`) do (
    set "ip=%%a"
    if defined ip (
        echo !ip! | findstr /r "^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$" >nul
        if not errorlevel 1 (
            if not "!ip!"=="%PublicIP%" (
                findstr /x "!ip!" "%tempfile%" >nul 2>&1
                if errorlevel 1 (
                    echo !ip!>> "%tempfile%"
                    echo.
                    echo [NEW] Found IP: !ip!
                    call :get_info !ip!
                    echo.
                    echo ----------------------------------------
                )
            )
        )
    )
)
goto loop

:get_info
for /f "usebackq delims=" %%a in (`PowerShell -NoProfile -Command "try { $response = Invoke-WebRequest -Uri 'http://ip-api.com/json/%1' -UseBasicParsing; if ($response.StatusCode -eq 200) { $response.Content } else { 'ERROR' } } catch { 'ERROR' }" 2^>nul`) do set "json=%%a"

if "!json!"=="ERROR" (
    echo   Could not retrieve location data
    goto :eof
)

for /f "usebackq delims=" %%a in (`PowerShell -NoProfile -Command "$data = '%json%' | ConvertFrom-Json; Write-Output $data.country" 2^>nul`) do set "country=%%a"
for /f "usebackq delims=" %%a in (`PowerShell -NoProfile -Command "$data = '%json%' | ConvertFrom-Json; Write-Output $data.city" 2^>nul`) do set "city=%%a"
for /f "usebackq delims=" %%a in (`PowerShell -NoProfile -Command "$data = '%json%' | ConvertFrom-Json; Write-Output $data.isp" 2^>nul`) do set "isp=%%a"

echo   Location: !city!, !country!
if defined isp echo   ISP: !isp!

for /f "usebackq delims=" %%a in (`PowerShell -NoProfile -Command "Get-Date -Format 'yyyy-MM-dd HH:mm:ss'" 2^>nul`) do set "ts=%%a"
(
echo.
echo [%1] - STUN PACKET [%ts%]
echo Country: !country!
echo City: !city!
echo ISP: !isp!
echo ----------------------------------------
) >> information.txt
goto :eof

:ip_lookup
cls
echo.
echo ========================================
echo         IP INFO LOOKUP
echo ========================================
echo.
echo Enter IP address (or 'back' to return):
set /p "target="

if "%target%"=="back" goto menu
if "%target%"=="" goto ip_lookup

echo.
echo Looking up %target%...
for /f "usebackq delims=" %%a in (`PowerShell -NoProfile -Command "try { $response = Invoke-WebRequest -Uri 'http://ip-api.com/json/%target%' -UseBasicParsing; if ($response.StatusCode -eq 200) { $response.Content } else { 'ERROR' } } catch { 'ERROR' }" 2^>nul`) do set "json=%%a"

if "!json!"=="ERROR" (
    echo Failed to retrieve data
    pause
    goto ip_lookup
)

for /f "usebackq delims=" %%a in (`PowerShell -NoProfile -Command "$data = '%json%' | ConvertFrom-Json; Write-Output $data.query" 2^>nul`) do set "ip=%%a"
for /f "usebackq delims=" %%a in (`PowerShell -NoProfile -Command "$data = '%json%' | ConvertFrom-Json; Write-Output $data.country" 2^>nul`) do set "country=%%a"
for /f "usebackq delims=" %%a in (`PowerShell -NoProfile -Command "$data = '%json%' | ConvertFrom-Json; Write-Output $data.city" 2^>nul`) do set "city=%%a"
for /f "usebackq delims=" %%a in (`PowerShell -NoProfile -Command "$data = '%json%' | ConvertFrom-Json; Write-Output $data.isp" 2^>nul`) do set "isp=%%a"
for /f "usebackq delims=" %%a in (`PowerShell -NoProfile -Command "$data = '%json%' | ConvertFrom-Json; Write-Output $data.lat" 2^>nul`) do set "lat=%%a"
for /f "usebackq delims=" %%a in (`PowerShell -NoProfile -Command "$data = '%json%' | ConvertFrom-Json; Write-Output $data.lon" 2^>nul`) do set "lon=%%a"

echo.
echo ========================================
echo IP: %ip%
echo Country: %country%
echo City: %city%
echo ISP: %isp%
echo Coordinates: %lat%, %lon%
echo ========================================

for /f "usebackq delims=" %%a in (`PowerShell -NoProfile -Command "Get-Date -Format 'yyyy-MM-dd HH:mm:ss'" 2^>nul`) do set "ts=%%a"
(
echo.
echo [%ip%] - MANUAL LOOKUP [%ts%]
echo Country: %country%
echo City: %city%
echo ISP: %isp%
echo Coordinates: %lat%, %lon%
echo ----------------------------------------
) >> information.txt

echo.
echo Press any key to look up another IP...
pause >nul
goto ip_lookup
