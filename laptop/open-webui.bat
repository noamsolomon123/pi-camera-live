@echo off
setlocal
echo ==============================================
echo    Pi Camera WebUI
echo ==============================================
echo  First, on the Pi (over SSH), make sure this is running:
echo      python3 pi/webui.py
echo.
set PIHOST=raspberrypi.local
set /p PIHOST=Pi IP or hostname [raspberrypi.local]:
echo.
echo  Opening http://%PIHOST%:8080/ ...
start "" "http://%PIHOST%:8080/"
