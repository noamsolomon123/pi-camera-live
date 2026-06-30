#!/usr/bin/env bash
# ============================================================
#  stream.sh  —  DEFAULT low-latency live view (H.264 over USB)
# ============================================================
#  Auto-detects the camera command:
#     rpicam-vid     (current Raspberry Pi OS "Bookworm")
#     libcamera-vid  (older Raspberry Pi OS "Bullseye")
#
#  The Pi WAITS here until the laptop connects, then streams.
#  Start this FIRST, then run  laptop\view.bat  on the laptop.
#  Stop with Ctrl+C.
# ============================================================
set -e

# ----- settings (edit if you want) --------------------------
PORT=8888       # the laptop connects to this port
WIDTH=1280      # smaller = less latency (try 640)
HEIGHT=720      # smaller = less latency (try 480)
FPS=30          # frames per second
INTRA=30        # keyframe every N frames (30 = once per second)
ROTATION=0      # 0 or 180   (for 90/270 rotate on the laptop instead)
HFLIP=0         # 1 = mirror left <-> right
VFLIP=0         # 1 = mirror up <-> down
# ------------------------------------------------------------

# pick whichever camera command exists
if command -v rpicam-vid >/dev/null 2>&1; then
  CAM=rpicam-vid
elif command -v libcamera-vid >/dev/null 2>&1; then
  CAM=libcamera-vid
else
  echo "ERROR: no camera command found (rpicam-vid / libcamera-vid)."
  echo "Run:  bash pi/diagnose.sh"
  exit 1
fi

# optional rotate / mirror flags
EXTRA=""
[ "$ROTATION" = "180" ] && EXTRA="$EXTRA --rotation 180"
[ "$HFLIP" = "1" ] && EXTRA="$EXTRA --hflip"
[ "$VFLIP" = "1" ] && EXTRA="$EXTRA --vflip"

echo "Camera : $CAM"
echo "Video  : ${WIDTH}x${HEIGHT} @ ${FPS}fps   on port ${PORT}"
echo "Waiting for the laptop to connect..."
echo "(now run  laptop\\view.bat  on the laptop.   Ctrl+C here to stop.)"

#  -t 0      run forever
#  -n        no preview window (the Pi is headless)
#  --inline  put H.264 headers in the stream so the laptop can join anytime
#  --flush   push each frame out immediately  (lowest latency)
#  --listen  the Pi becomes a TCP server and waits for the laptop
exec "$CAM" -t 0 -n --inline --flush \
  --width "$WIDTH" --height "$HEIGHT" --framerate "$FPS" \
  --intra "$INTRA" --profile baseline --level 4.2 \
  $EXTRA \
  --listen -o "tcp://0.0.0.0:${PORT}"
