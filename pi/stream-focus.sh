#!/usr/bin/env bash
# ============================================================
#  stream-focus.sh  —  FOCUS HELPER: digital zoom into the CENTER.
# ============================================================
#  Best way to nail focus: magnify the middle of the frame so
#  the tiniest blur is obvious, while keeping the resolution
#  LOW so it stays smooth and responsive as you turn the lens.
#  (Cranking full sensor res just makes it laggy — zoom beats res.)
#
#  Set focus razor-sharp here, then switch to pi/stream.sh for
#  the full frame. Focus carries over to your photos unchanged.
#
#  On the LAPTOP run:   laptop\view.bat
#  Ctrl+C to stop.
# ============================================================
set -e

# ----- settings ---------------------------------------------
PORT=8888; WIDTH=1280; HEIGHT=720; FPS=30; INTRA=30
ZOOM=0.4        # fraction of the frame to show. 0.4 = center 40%.
                # SMALLER = more zoom (try 0.25 to pixel-peep, 0.6 for wider).
ROTATION=0; HFLIP=0; VFLIP=0
# ------------------------------------------------------------

if command -v rpicam-vid >/dev/null 2>&1; then CAM=rpicam-vid
elif command -v libcamera-vid >/dev/null 2>&1; then CAM=libcamera-vid
else echo "no camera command found; run: bash pi/diagnose.sh"; exit 1; fi

# centered region-of-interest:  offset = (1 - ZOOM) / 2  on each side
OFF=$(awk "BEGIN{printf \"%.4f\", (1-$ZOOM)/2}")

EXTRA=""
[ "$ROTATION" = "180" ] && EXTRA="$EXTRA --rotation 180"
[ "$HFLIP" = "1" ] && EXTRA="$EXTRA --hflip"
[ "$VFLIP" = "1" ] && EXTRA="$EXTRA --vflip"

echo "$CAM  CENTER-ZOOM x${ZOOM}  ${WIDTH}x${HEIGHT}@${FPS}  port ${PORT} — waiting for laptop (Ctrl+C to stop)"
echo "(image may look a little stretched while zoomed — that's fine, you're judging sharpness.)"
#  --roi x,y,w,h  = crop a sub-region of the sensor (digital zoom), values 0..1
exec "$CAM" -t 0 -n --inline --flush \
  --width "$WIDTH" --height "$HEIGHT" --framerate "$FPS" \
  --intra "$INTRA" --profile baseline --level 4.2 \
  --roi "${OFF},${OFF},${ZOOM},${ZOOM}" \
  $EXTRA \
  --listen -o "tcp://0.0.0.0:${PORT}"
