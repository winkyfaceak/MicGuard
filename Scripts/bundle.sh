#!/bin/bash
# Wrap the SwiftPM executable in a real .app bundle.
#
# MenuBarExtra and SMAppService both need bundle metadata (LSUIElement, a
# bundle identifier, a code signature), which `swift build` alone does not
# produce. This script supplies them.
set -euo pipefail

CONFIG="${1:-release}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/build/MicGuard.app"
BUNDLE_ID="com.winkyfaceak.MicGuard"

# Regenerate the .icns if the source art is newer than it.
"$ROOT/Scripts/icon.sh" >/dev/null

cd "$ROOT"
swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/MicGuard"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/MicGuard"
cp "$ROOT/Resources/MicGuard.icns" "$APP/Contents/Resources/MicGuard.icns"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

# Ad-hoc signature ("-"). Enough for personal use on your own machine;
# distributing to anyone else would need a Developer ID identity instead.
codesign --force --sign - --identifier "$BUNDLE_ID" "$APP" >/dev/null 2>&1

echo "Built $APP"
