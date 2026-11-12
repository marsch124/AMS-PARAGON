#!/bin/bash
# The launch check (build 305).
#
# Builds 301 to 303 hung at start: the iPhone app looped on a toolbar layout until the watchdog
# killed it ("crash on launch"), and the Mac app looped in its menu bar label at full speed with
# no window. Both compiled cleanly and nothing noticed. This script starts the Debug app on an
# iPhone simulator and on the Mac with the test vault, waits, and asks two questions of each:
# is it still running, and is it quiet? A layout loop answers "100 %" for ever.
#
# Exit 0 = both settled. Anything else = do NOT upload. The ship script runs this first.
#
#   Tools/launch-check.sh            # both
#   Tools/launch-check.sh ios|mac    # one
set -u
cd "$(dirname "$0")/.."
WAIT=${LAUNCH_CHECK_WAIT:-20}
LIMIT=${LAUNCH_CHECK_CPU:-30}
DD=${LAUNCH_CHECK_DD:-/tmp/paragon-launch-check}
WHICH=${1:-both}
FAILED=0

cpu_of() { ps -o %cpu= -p "$1" 2>/dev/null | tr -d ' ' | cut -d. -f1; }

judge() { # name pid
  local name=$1 pid=$2 cpu
  if ! kill -0 "$pid" 2>/dev/null; then
    echo "FAIL $name: the app stopped within $WAIT s of starting."; FAILED=1; return
  fi
  # Three samples a second apart: one busy moment is not a loop, three are.
  local busy=0
  for _ in 1 2 3; do
    cpu=$(cpu_of "$pid"); cpu=${cpu:-0}
    echo "  $name CPU ${cpu} %"
    [ "$cpu" -gt "$LIMIT" ] && busy=$((busy + 1))
    sleep 1
  done
  if [ "$busy" -eq 3 ]; then
    echo "FAIL $name: still busy after $WAIT s — it is hanging at start."; FAILED=1
  else
    echo "OK   $name settled."
  fi
}

if [ "$WHICH" != mac ]; then
  echo "== iPhone simulator"
  UDID=$(xcrun simctl list devices booted | grep -E "^ +iPhone" | head -1 | sed -E 's/.*\(([0-9A-Fa-f-]{36})\).*/\1/')
  if [ -z "$UDID" ]; then
    UDID=$(xcrun simctl list devices available | grep -E "^ +iPhone" | head -1 | sed -E 's/.*\(([0-9A-Fa-f-]{36})\).*/\1/')
    xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
  fi
  if ! xcodebuild -project Paragon.xcodeproj -scheme Paragon -configuration Debug \
      -destination "id=$UDID" -derivedDataPath "$DD/ios" build -quiet >"$DD-ios.log" 2>&1; then
    echo "FAIL iPhone: the Debug build did not compile (see $DD-ios.log)"; FAILED=1
  else
    APP="$DD/ios/Build/Products/Debug-iphonesimulator/PARAGON.app"
    xcrun simctl terminate "$UDID" com.schabbauer.AMSPara >/dev/null 2>&1 || true
    xcrun simctl install "$UDID" "$APP"
    OUT=$(xcrun simctl launch "$UDID" com.schabbauer.AMSPara -paragon-test-vault 2>&1)
    PID=$(echo "$OUT" | awk -F': ' '{print $2}' | tr -d ' ')
    sleep "$WAIT"
    if [ -z "$PID" ]; then echo "FAIL iPhone: could not start ($OUT)"; FAILED=1
    else judge iPhone "$PID"; fi
    xcrun simctl terminate "$UDID" com.schabbauer.AMSPara >/dev/null 2>&1 || true
  fi
fi

if [ "$WHICH" != ios ]; then
  echo "== Mac"
  if ! xcodebuild -project Paragon.xcodeproj -scheme Paragon -configuration Debug \
      -destination 'platform=macOS' -derivedDataPath "$DD/mac" build -quiet >"$DD-mac.log" 2>&1; then
    echo "FAIL Mac: the Debug build did not compile (see $DD-mac.log)"; FAILED=1
  else
    BIN="$DD/mac/Build/Products/Debug/PARAGON.app/Contents/MacOS/PARAGON"
    "$BIN" -paragon-test-vault >/dev/null 2>&1 &
    PID=$!
    sleep "$WAIT"
    judge Mac "$PID"
    kill "$PID" 2>/dev/null; sleep 1; kill -9 "$PID" 2>/dev/null
  fi
fi

[ "$FAILED" -eq 0 ] && echo "LAUNCH CHECK PASSED" || echo "LAUNCH CHECK FAILED — do not upload"
exit "$FAILED"
