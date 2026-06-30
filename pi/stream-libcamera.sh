#!/usr/bin/env bash
# ============================================================
#  stream-libcamera.sh  —  FORCE the OLD command (libcamera-vid).
# ============================================================
#  Use this only on older Raspberry Pi OS "Bullseye".
#  NOTE: current "Bookworm" removed libcamera-vid (June 2025) —
#        on Bookworm use stream-rpicam.sh instead.
#  Same low-latency H.264 TCP stream. Ctrl+C to stop.
# ============================================================
set -e

# ----- settings ---------------------------------------------
PORT=8888; WIDTH=1280; HEIGHT=720; FPS=30; INTRA=30
ROTATION=0; HFLIP=0; VFLIP=0
# ------------------------------------------------------------

command -v libcamera-vid >/dev/null 2>&1 || {
  echo "libcamera-vid not found. On current Bookworm use: bash pi/stream-rpicam.sh"
  exit 1
}

EXTRA=""
[ "$ROTATION" = "180" ] && EXTRA="$EXTRA --rotation 180"
[ "$HFLIP" = "1" ] && EXTRA="$EXTRA --hflip"
[ "$VFLIP" = "1" ] && EXTRA="$EXTRA --vflip"

echo "libcamera-vid  ${WIDTH}x${HEIGHT}@${FPS}  port ${PORT} — waiting for laptop (Ctrl+C to stop)"
exec libcamera-vid -t 0 -n --inline --flush \
  --width "$WIDTH" --height "$HEIGHT" --framerate "$FPS" \
  --intra "$INTRA" --profile baseline --level 4.2 \
  $EXTRA \
  --listen -o "tcp://0.0.0.0:${PORT}"
