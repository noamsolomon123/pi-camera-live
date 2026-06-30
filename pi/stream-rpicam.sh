#!/usr/bin/env bash
# ============================================================
#  stream-rpicam.sh  —  FORCE the NEW command (rpicam-vid).
# ============================================================
#  Use this if stream.sh picked the wrong tool.
#  (rpicam-vid = current Raspberry Pi OS "Bookworm")
#  Same low-latency H.264 TCP stream. Ctrl+C to stop.
# ============================================================
set -e

# ----- settings ---------------------------------------------
PORT=8888; WIDTH=1280; HEIGHT=720; FPS=30; INTRA=30
ROTATION=0; HFLIP=0; VFLIP=0
# ------------------------------------------------------------

command -v rpicam-vid >/dev/null 2>&1 || {
  echo "rpicam-vid not found. You may have the old OS -> try: bash pi/stream-libcamera.sh"
  exit 1
}

EXTRA=""
[ "$ROTATION" = "180" ] && EXTRA="$EXTRA --rotation 180"
[ "$HFLIP" = "1" ] && EXTRA="$EXTRA --hflip"
[ "$VFLIP" = "1" ] && EXTRA="$EXTRA --vflip"

echo "rpicam-vid  ${WIDTH}x${HEIGHT}@${FPS}  port ${PORT} — waiting for laptop (Ctrl+C to stop)"
exec rpicam-vid -t 0 -n --inline --flush \
  --width "$WIDTH" --height "$HEIGHT" --framerate "$FPS" \
  --intra "$INTRA" --profile baseline --level 4.2 \
  $EXTRA \
  --listen -o "tcp://0.0.0.0:${PORT}"
