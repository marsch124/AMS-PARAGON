#!/bin/bash
# Uploads one build to TestFlight from this Mac, iPhone/iPad then Mac (build 305).
#
#   Tools/ship.sh 305            # the commit at HEAD, as 1.0.305 (305.1)
#
# **The launch check runs first and stops the upload when it fails** (Tools/launch-check.sh).
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
COMMIT=$(git -C "$R" rev-parse HEAD)
git -C "$R" worktree add --detach "$W" "$COMMIT" >/dev/null
trap 'git -C "$R" worktree remove --force "$W" 2>/dev/null || true' EXIT
cd "$W"

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
