#!/usr/bin/env bash
# Builds an unsigned-for-distribution .ipa you can sideload with AltStore/Sideloadly on a free account.
# Usage: scripts/build-ipa.sh  (run after bootstrap.sh; needs a connected or previously-registered device)
set -euo pipefail
cd "$(dirname "$0")/.."
xcodebuild -project Ledger.xcodeproj -scheme Ledger -configuration Release -sdk iphoneos \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
APP=build/DerivedData/Build/Products/Release-iphoneos/Ledger.app
rm -rf build/Payload build/Ledger.ipa && mkdir -p build/Payload && cp -R "$APP" build/Payload/
(cd build && zip -qr Ledger.ipa Payload)
echo "Wrote build/Ledger.ipa — sideload it with AltStore or Sideloadly (re-sign every 7 days on a free account)."
