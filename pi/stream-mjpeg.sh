#!/usr/bin/env bash
# ============================================================
#  stream-mjpeg.sh  —  MJPEG fallback.
# ============================================================
#  Use if the H.264 view is black or glitchy.
#  MJPEG = every frame is a full JPEG (simple, robust),
#  but uses more bandwidth. Lower the resolution if choppy.
#
#  On the LAPTOP run:   laptop\view.bat mjpeg
#  Ctrl+C to stop.
# ============================================================
set -e

# ----- settings ---------------------------------------------
PORT=8888; WIDTH=640; HEIGHT=480; FPS=30
ROTATION=0; HFLIP=0; VFLIP=0
# ------------------------------------------------------------

if command -v rpicam-vid >/dev/null 2>&1; then CAM=rpicam-vid
elif command -v libcamera-vid >/dev/null 2>&1; then CAM=libcamera-vid
else echo "no camera command found; run: bash pi/diagnose.sh"; exit 1; fi

EXTRA=""
[ "$ROTATION" = "180" ] && EXTRA="$EXTRA --rotation 180"
[ "$HFLIP" = "1" ] && EXTRA="$EXTRA --hflip"
[ "$VFLIP" = "1" ] && EXTRA="$EXTRA --vflip"

echo "$CAM  MJPEG  ${WIDTH}x${HEIGHT}@${FPS}  port ${PORT} — waiting for laptop (Ctrl+C to stop)"
exec "$CAM" -t 0 -n --codec mjpeg --flush \
  --width "$WIDTH" --height "$HEIGHT" --framerate "$FPS" \
  $EXTRA \
  --listen -o "tcp://0.0.0.0:${PORT}"
