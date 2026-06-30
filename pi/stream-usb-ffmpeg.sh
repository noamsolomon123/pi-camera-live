#!/usr/bin/env bash
# ============================================================
#  stream-usb-ffmpeg.sh  —  LAST RESORT: a USB webcam (not the
#  Pi CSI camera). Use only if you plugged in a USB webcam, or
#  the Pi camera stack is broken.
# ============================================================
#  Needs ffmpeg on the Pi:   sudo apt install -y ffmpeg
#  On the LAPTOP run:        laptop\view.bat ts
#  Ctrl+C to stop.
# ============================================================
set -e

# ----- settings ---------------------------------------------
PORT=8888; WIDTH=640; HEIGHT=480; FPS=30
DEV=/dev/video0          # check yours with:  ls /dev/video*
# ------------------------------------------------------------

command -v ffmpeg >/dev/null 2>&1 || {
  echo "ffmpeg missing on the Pi. Install it:  sudo apt install -y ffmpeg"
  exit 1
}

echo "USB webcam $DEV  ${WIDTH}x${HEIGHT}@${FPS}  -> port ${PORT} (Ctrl+C to stop)"
# Software H.264 (ultrafast + zerolatency) wrapped in MPEG-TS.
# The Pi listens; the laptop connects.
exec ffmpeg -f v4l2 -framerate "$FPS" -video_size "${WIDTH}x${HEIGHT}" -i "$DEV" \
  -c:v libx264 -preset ultrafast -tune zerolatency -pix_fmt yuv420p -g "$FPS" \
  -f mpegts -listen 1 "tcp://0.0.0.0:${PORT}"
