#!/usr/bin/env bash
# ===========================================================
#  view.sh  —  open the live camera view on mac / Linux.
# ===========================================================
#  Usage:  ./view.sh [host] [port] [fps]
#     ./view.sh                         raspberrypi.local:8888 @30
#     ./view.sh 169.254.10.20 8888 30
#
#  Install ffmpeg first:
#     macOS:  brew install ffmpeg
#     Linux:  sudo apt install ffmpeg
# ===========================================================
PIHOST="${1:-raspberrypi.local}"
PORT="${2:-8888}"
FPS="${3:-30}"

command -v ffplay >/dev/null 2>&1 || {
  echo "ffplay not found. Install ffmpeg (brew install ffmpeg / sudo apt install ffmpeg)."
  exit 1
}

exec ffplay -hide_banner -fflags nobuffer -flags low_delay -framedrop \
  -probesize 32 -analyzeduration 0 -sync ext -an \
  -vf "setpts=N/${FPS}" \
  -window_title "Pi Camera" "tcp://${PIHOST}:${PORT}"
