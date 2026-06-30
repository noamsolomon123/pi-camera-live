@echo off
setlocal
REM ===========================================================
REM  view.bat  —  open the live camera view on this laptop.
REM ===========================================================
REM  Just DOUBLE-CLICK for the normal case, or from a terminal:
REM     view.bat            normal H.264 stream  (default)
REM     view.bat mjpeg      if the Pi runs stream-mjpeg.sh
REM     view.bat ts         if the Pi runs stream-mpegts.sh or stream-usb-ffmpeg.sh
REM
REM  If raspberrypi.local does not work, change PIHOST below to
REM  the Pi's IP address (e.g. 169.254.10.20).
REM ===========================================================

set PIHOST=raspberrypi.local
set PORT=8888
set FPS=30
set MODE=%1
if "%MODE%"=="" set MODE=h264

where ffplay >nul 2>nul
if errorlevel 1 (
  echo.
  echo ffplay was not found. Install FFmpeg, then reopen this window:
  echo     winget install -e --id Gyan.FFmpeg
  echo.
  pause
  exit /b 1
)

set LOWLAT=-hide_banner -fflags nobuffer -flags low_delay -framedrop -probesize 32 -analyzeduration 0 -sync ext -an

echo Connecting to tcp://%PIHOST%:%PORT%   (mode: %MODE%)
echo Close the video window to stop.

if /i "%MODE%"=="mjpeg" (
  ffplay %LOWLAT% -f mjpeg -window_title "Pi Camera" tcp://%PIHOST%:%PORT%
) else if /i "%MODE%"=="ts" (
  ffplay %LOWLAT% -window_title "Pi Camera" tcp://%PIHOST%:%PORT%
) else (
  ffplay %LOWLAT% -vf "setpts=N/%FPS%" -window_title "Pi Camera" tcp://%PIHOST%:%PORT%
)
pause
