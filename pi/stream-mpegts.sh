#!/usr/bin/env bash
# ============================================================
#  stream-mpegts.sh  —  last-resort: H.264 wrapped in MPEG-TS.
# ============================================================
#  Use ONLY if the raw H.264 stream (stream.sh) refuses to play
#  in your viewer. MPEG-TS carries timestamps, so the laptop
#  side is simpler (no setpts needed).
#
#  IMPORTANT: this path uses  ?listen=1  in the URL,
#  NOT  --listen  (that is how libav listens). Do not mix them.
#
#  If you see:  "libav: unable to open video codec: -22"
#  then update and retry:
#     sudo apt update && sudo apt full-upgrade -y
#
#  On the LAPTOP run:   laptop\view.bat ts
#  Ctrl+C to stop.
# ============================================================
set -e

# ----- settings ---------------------------------------------
PORT=8888; WIDTH=1280; HEIGHT=720; FPS=30; INTRA=30
ROTATION=0; HFLIP=0; VFLIP=0
# ------------------------------------------------------------

if command -v rpicam-vid >/dev/null 2>&1; then CAM=rpicam-vid
elif command -v libcamera-vid >/dev/null 2>&1; then CAM=libcamera-vid
else echo "no camera command found; run: bash pi/diagnose.sh"; exit 1; fi

EXTRA=""
[ "$ROTATION" = "180" ] && EXTRA="$EXTRA --rotation 180"
[ "$HFLIP" = "1" ] && EXTRA="$EXTRA --hflip"
[ "$VFLIP" = "1" ] && EXTRA="$EXTRA --vflip"

echo "$CAM  H.264/MPEG-TS  ${WIDTH}x${HEIGHT}@${FPS}  port ${PORT} — waiting for laptop (Ctrl+C to stop)"
exec "$CAM" -t 0 -n --codec libav --libav-format mpegts --flush \
  --width "$WIDTH" --height "$HEIGHT" --framerate "$FPS" --intra "$INTRA" \
  $EXTRA \
  -o "tcp://0.0.0.0:${PORT}?listen=1"
