#!/usr/bin/env bash
# Headless screenshot of the awesome bar.
#
# Usage:
#   dev/take-screenshot.sh                        # bar.png only
#   MOUSE_X=875 MOUSE_Y=11 dev/take-screenshot.sh # bar.png + hover.png
#
# Env knobs:
#   RC          awesome rc to launch    (default: dev/screenshot-rc.lua)
#   DISPLAY_NUM Xvfb display            (default: :99)
#   SCREEN      WxHxDepth               (default: 1280x720x24)
#   OUTDIR      output directory        (default: /tmp/awesome-shots)
#   SETTLE      seconds before scrot    (default: 4)
#   MOUSE_X,
#   MOUSE_Y     hover target            (no hover if unset)
#
# Exits non-zero if Xvfb fails to come up. Inspect $OUTDIR/awesome.log
# if the screenshot looks empty.

set -u

DEV_DIR=$(cd "$(dirname "$0")" && pwd)
RC=${RC:-$DEV_DIR/screenshot-rc.lua}
DISPLAY_NUM=${DISPLAY_NUM:-:99}
SCREEN=${SCREEN:-1280x720x24}
OUTDIR=${OUTDIR:-/tmp/awesome-shots}
SETTLE=${SETTLE:-4}

DISPLAY_SOCKET=/tmp/.X11-unix/X${DISPLAY_NUM#:}
mkdir -p "$OUTDIR"
rm -f "$OUTDIR"/*.png

cleanup() {
  set +e
  [[ -n ${A_PID:-} ]] && kill "$A_PID" 2>/dev/null
  [[ -n ${X_PID:-} ]] && kill "$X_PID" 2>/dev/null
  wait 2>/dev/null
}
trap cleanup EXIT

Xvfb "$DISPLAY_NUM" -screen 0 "$SCREEN" >"$OUTDIR/xvfb.log" 2>&1 &
X_PID=$!
for _ in {1..50}; do [[ -S $DISPLAY_SOCKET ]] && break; sleep 0.1; done
[[ -S $DISPLAY_SOCKET ]] || { echo "Xvfb didn't come up"; cat "$OUTDIR/xvfb.log"; exit 1; }

DISPLAY=$DISPLAY_NUM dbus-run-session -- awesome -c "$RC" \
  >"$OUTDIR/awesome.log" 2>&1 &
A_PID=$!
sleep "$SETTLE"

DISPLAY=$DISPLAY_NUM scrot "$OUTDIR/bar.png"

if [[ -n ${MOUSE_X:-} && -n ${MOUSE_Y:-} ]]; then
  DISPLAY=$DISPLAY_NUM xdotool mousemove "$MOUSE_X" "$MOUSE_Y"
  sleep 1
  DISPLAY=$DISPLAY_NUM scrot "$OUTDIR/hover.png"
fi

echo "Screenshots in $OUTDIR/"
ls "$OUTDIR"/*.png 2>/dev/null
