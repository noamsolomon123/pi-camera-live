#!/usr/bin/env bash
# ============================================================
#  diagnose.sh  —  run this FIRST on the Pi (over SSH).
# ============================================================
#  It changes NOTHING. It just tells you:
#    - which OS you have,
#    - which camera command works (rpicam-vid vs libcamera-vid),
#    - which cameras are connected,
#  then it recommends which stream script to run.
# ============================================================

echo "==================== Pi Camera Diagnose ===================="

echo
echo "--- OS version ---"
grep PRETTY_NAME /etc/os-release 2>/dev/null || echo "unknown"

echo
echo "--- Which camera command is installed? ---"
CAM=""
if command -v rpicam-vid >/dev/null 2>&1; then
  echo "rpicam-vid    : YES   (new name, Raspberry Pi OS 'Bookworm')"
  CAM=rpicam
else
  echo "rpicam-vid    : no"
fi
if command -v libcamera-vid >/dev/null 2>&1; then
  echo "libcamera-vid : YES   (old name, Raspberry Pi OS 'Bullseye')"
  [ -z "$CAM" ] && CAM=libcamera
else
  echo "libcamera-vid : no"
fi

echo
echo "--- Cameras detected ---"
if command -v rpicam-hello >/dev/null 2>&1; then
  rpicam-hello --list-cameras
elif command -v libcamera-hello >/dev/null 2>&1; then
  libcamera-hello --list-cameras
else
  echo "No rpicam-hello / libcamera-hello found."
fi

echo
echo "--- USB webcams (only matters if you use a USB cam, not the Pi camera) ---"
ls /dev/video* 2>/dev/null || echo "none"

echo
echo "==================== Recommendation ===================="
case "$CAM" in
  rpicam)    echo "Run:  bash pi/stream.sh          (or pi/stream-rpicam.sh)";;
  libcamera) echo "Run:  bash pi/stream.sh          (or pi/stream-libcamera.sh)";;
  *)         echo "No Pi camera command found.";
             echo "  - Reseat the camera ribbon and re-run this script, OR";
             echo "  - using a USB webcam? run: bash pi/stream-usb-ffmpeg.sh";;
esac
echo "Then on the LAPTOP run:  laptop\\view.bat"
echo "==========================================================="
