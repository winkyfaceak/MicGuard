#!/bin/bash
# Resources/AppIcon.png  ->  Resources/MicGuard.icns
#
# .icns is a container holding the same artwork at ten sizes. macOS picks
# whichever fits the context — 16pt in a Finder list, 512pt in Get Info —
# so shipping only one size gives you blurry icons at the other nine.
#
# There is no asset-catalog alternative here: .xcassets needs `actool`,
# which ships with Xcode, not Command Line Tools.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/Resources/AppIcon.png"
ICONSET="$ROOT/build/MicGuard.iconset"
OUT="$ROOT/Resources/MicGuard.icns"

if [[ ! -f "$SRC" ]]; then
  echo "No $SRC — generating a placeholder." >&2
  swift "$ROOT/Scripts/make-icon.swift" "$SRC"
fi

# Reject undersized art early: iconutil will happily upscale and the result
# looks soft at 512pt in a way that is easy to miss until it ships.
WIDTH="$(sips -g pixelWidth "$SRC" | awk '/pixelWidth/ {print $2}')"
if (( WIDTH < 1024 )); then
  echo "error: $SRC is ${WIDTH}px wide; needs to be at least 1024." >&2
  exit 1
fi

rm -rf "$ICONSET"
mkdir -p "$ICONSET"

# name              pixels
render() { sips -z "$2" "$2" "$SRC" --out "$ICONSET/$1" >/dev/null; }
render icon_16x16.png         16
render icon_16x16@2x.png      32
render icon_32x32.png         32
render icon_32x32@2x.png      64
render icon_128x128.png      128
render icon_128x128@2x.png   256
render icon_256x256.png      256
render icon_256x256@2x.png   512
render icon_512x512.png      512
render icon_512x512@2x.png  1024

iconutil --convert icns "$ICONSET" --output "$OUT"
rm -rf "$ICONSET"

echo "Built $OUT"
