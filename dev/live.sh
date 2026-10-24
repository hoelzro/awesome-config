#!/usr/bin/env bash
# Run this Awesome configuration in a disposable, automatically reloading
# nested X server.
#
# The default 1280x30 screen shows only the wibar. Use SCREEN=1280x720 when
# working on popups or anything else that needs a desktop-sized root window.

set -u

DEV_DIR=$(cd "$(dirname "$0")" && pwd)
CONFIG_DIR=$(cd "$DEV_DIR/.." && pwd)
RC=${RC:-$DEV_DIR/screenshot-rc.lua}
SCREEN=${SCREEN:-1280x30}
HOST_SESSION_BUS_ADDRESS=${DONUT_DBUS_SESSION_BUS_ADDRESS:-${DBUS_SESSION_BUS_ADDRESS:-}}

fail() {
  echo "awesome-live: $*" >&2
  exit 1
}

if [[ -n $HOST_SESSION_BUS_ADDRESS ]]; then
  export DONUT_DBUS_SESSION_BUS_ADDRESS=$HOST_SESSION_BUS_ADDRESS
else
  echo "awesome-live: warning: no host session bus; MPRIS will be unavailable" >&2
fi

for command in Xephyr awesome awesome-client dbus-run-session inotifywait; do
  command -v "$command" >/dev/null || {
    case $command in
      Xephyr)
        fail "Xephyr is required (on Arch Linux: sudo pacman -S xorg-server-xephyr)"
        ;;
      inotifywait)
        fail "inotifywait is required (on Arch Linux: sudo pacman -S inotify-tools)"
        ;;
      *)
        fail "$command is required"
        ;;
    esac
  }
done

if [[ -n ${DISPLAY_NUM:-} ]]; then
  [[ $DISPLAY_NUM =~ ^:[0-9]+$ ]] || fail "DISPLAY_NUM must look like :99"
else
  for number in $(seq 90 110); do
    if [[ ! -e /tmp/.X11-unix/X$number && ! -e /tmp/.X$number-lock ]]; then
      DISPLAY_NUM=:$number
      break
    fi
  done
  [[ -n ${DISPLAY_NUM:-} ]] || fail "no free X display found between :90 and :110"
fi

RUNTIME_DIR=$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/awesome-live.XXXXXX") || \
  fail "could not create a runtime directory"
DBUS_ADDRESS_FILE=$RUNTIME_DIR/dbus-address

cleanup() {
  set +e
  [[ -n ${WATCHER_PID:-} ]] && kill "$WATCHER_PID" 2>/dev/null
  [[ -n ${AWESOME_PID:-} ]] && kill "$AWESOME_PID" 2>/dev/null
  [[ -n ${XEPHYR_PID:-} ]] && kill "$XEPHYR_PID" 2>/dev/null
  wait 2>/dev/null
  rm -rf "$RUNTIME_DIR"
}
trap cleanup EXIT
trap 'exit 0' INT TERM

Xephyr "$DISPLAY_NUM" -screen "$SCREEN" -ac -br -noreset 2>&1 &
XEPHYR_PID=$!

DISPLAY_SOCKET=/tmp/.X11-unix/X${DISPLAY_NUM#:}
for _ in {1..50}; do
  [[ -S $DISPLAY_SOCKET ]] && break
  kill -0 "$XEPHYR_PID" 2>/dev/null || \
    fail "Xephyr exited before its display was ready"
  sleep 0.1
done
[[ -S $DISPLAY_SOCKET ]] || fail "Xephyr did not create $DISPLAY_SOCKET"

DISPLAY=$DISPLAY_NUM dbus-run-session -- sh -c '
  printf "%s" "$DBUS_SESSION_BUS_ADDRESS" >"$1"
  exec awesome -c "$2"
' sh "$DBUS_ADDRESS_FILE" "$RC" 2>&1 &
AWESOME_PID=$!

for _ in {1..50}; do
  [[ -s $DBUS_ADDRESS_FILE ]] && break
  kill -0 "$AWESOME_PID" 2>/dev/null || \
    fail "Awesome exited before creating its D-Bus session"
  sleep 0.1
done
[[ -s $DBUS_ADDRESS_FILE ]] || fail "Awesome did not create its D-Bus session"
DBUS_SESSION_BUS_ADDRESS=$(<"$DBUS_ADDRESS_FILE")
export DBUS_SESSION_BUS_ADDRESS

for _ in {1..50}; do
  if DISPLAY=$DISPLAY_NUM awesome-client 'return awesome.version' >/dev/null 2>&1; then
    break
  fi
  kill -0 "$AWESOME_PID" 2>/dev/null || \
    fail "Awesome exited before it was ready"
  sleep 0.1
done
DISPLAY=$DISPLAY_NUM awesome-client 'return awesome.version' >/dev/null 2>&1 || \
  fail "Awesome did not become ready"

coproc FILE_WATCHER {
  exec inotifywait --monitor --recursive --quiet \
    --exclude '(^|/)\.git(/|$)' \
    --event close_write,delete,move \
    --format '%w%f' \
    "$CONFIG_DIR"
}
WATCHER_PID=$FILE_WATCHER_PID
WATCHER_FD=${FILE_WATCHER[0]}

echo "awesome-live: watching $CONFIG_DIR on $DISPLAY_NUM ($SCREEN)"
if [[ -n $HOST_SESSION_BUS_ADDRESS ]]; then
  echo "awesome-live: widget services use the host D-Bus session"
fi
echo "awesome-live: press Ctrl-C to stop"

while kill -0 "$AWESOME_PID" 2>/dev/null && kill -0 "$XEPHYR_PID" 2>/dev/null; do
  if ! IFS= read -r -t 1 changed <&"$WATCHER_FD"; then
    kill -0 "$WATCHER_PID" 2>/dev/null || \
      fail "inotifywait exited"
    continue
  fi

  # Coalesce the burst of events produced by an editor's save operation.
  while IFS= read -r -t 0.1 next_changed <&"$WATCHER_FD"; do
    changed=$next_changed
  done

  printf 'awesome-live: change detected (%s); reloading ... ' "$changed"
  if DISPLAY=$DISPLAY_NUM awesome-client "require('safe-restart')()" >/dev/null 2>&1; then
    echo ok
  else
    echo failed
  fi
done

fail "the nested Awesome or Xephyr process exited"
