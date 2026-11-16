#!/bin/bash
# Uploads one build to TestFlight from this Mac, iPhone/iPad then Mac (build 305).
#
#   Tools/ship.sh 305            # the commit at HEAD, as 1.0.305 (305.1)
#
# **The rule tests and the launch check run first and stop the upload when one fails**
# (the Core package's tests, build 326; Tools/launch-check.sh, build 305).
# Builds 301–303 went out hanging at start; this is the gate that would have stopped them.
#
# The App Store Connect key stays outside this public repository: ship.env next to the key
# sets KEY_PATH, KEY_ID and ISSUER_ID.
set -euo pipefail
BUILD=${1:?build number, e.g. 305}
R="$(cd "$(dirname "$0")/.." && pwd)"
ENV="$HOME/Documents/01 Leisure/30 App Development/Apple Developer/AMS PARA/ship.env"
# shellcheck disable=SC1090
source "$ENV"
OUT=${SHIP_OUT:-/tmp/paragon-ship-$BUILD}
W="$OUT/wt"
AUTH=(-allowProvisioningUpdates -authenticationKeyPath "$KEY_PATH" -authenticationKeyID "$KEY_ID" -authenticationKeyIssuerID "$ISSUER_ID")
mkdir -p "$OUT"

# iCloud Drive parks a second copy as "name 2" when two writes meet (build 308, hardening-15).
# A stray copy in the repository or in .git means something was lost or doubled: stop and look.
STRAY=$( { git -C "$R" ls-files; ls -1 "$R/.git"; } | grep -E ' [2-9](\.[^/. ]+)?(/|$)' || true)
if [ -n "$STRAY" ]; then
  echo "NOT UPLOADED: stray iCloud copies found (names ending in \" 2\"):"; echo "$STRAY"; exit 1
fi

COMMIT=$(git -C "$R" rev-parse HEAD)
git -C "$R" worktree add --detach "$W" "$COMMIT" >/dev/null
trap 'git -C "$R" worktree remove --force "$W" 2>/dev/null || true' EXIT
cd "$W"

# Build 326: the rule tests (the Core package) run before every upload. One of them was red
# from build 318 to 325 and nothing here noticed: the upload only asked the launch check.
echo "== Rule tests"
if ! swift test --package-path Core > "$OUT/rule-tests.log" 2>&1; then
  grep -E "error: -\[|with [1-9][0-9]* failure" "$OUT/rule-tests.log" | sort -u | head -20
  echo "NOT UPLOADED: a rule test failed (full log: $OUT/rule-tests.log)."; exit 1
fi
grep -E "Executed [0-9]+ tests" "$OUT/rule-tests.log" | tail -1

echo "== Launch check"
LAUNCH_CHECK_DD="$OUT/check" Tools/launch-check.sh || { echo "NOT UPLOADED: the launch check failed."; exit 1; }

for p in App/Config/Paragon/Info.plist App/Config/ParagonShare/Info.plist App/Config/ParagonWidgets/Info.plist; do
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD.1" "$p"
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 1.0.$BUILD" "$p"
done
/usr/libexec/PlistBuddy -c "Add :ITSAppUsesNonExemptEncryption bool false" App/Config/Paragon/Info.plist 2>/dev/null || true
xattr -cr . 2>/dev/null || true
for plat in iOS macOS; do
  xcodebuild archive -project Paragon.xcodeproj -scheme Paragon -destination generic/platform=$plat \
    -archivePath "$OUT/p$BUILD-$plat.xcarchive" "${AUTH[@]}" -quiet
  xcodebuild -exportArchive -archivePath "$OUT/p$BUILD-$plat.xcarchive" \
    -exportOptionsPlist Tools/ExportOptions.plist -exportPath "$OUT/p$BUILD-$plat-out" "${AUTH[@]}"
  echo "UPLOADED $plat"
done
date
