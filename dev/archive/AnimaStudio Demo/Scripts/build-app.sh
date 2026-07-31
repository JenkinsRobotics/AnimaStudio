#!/bin/bash
# Rebuilds the double-clickable AnimaStudioDemo.app from the current source, so
# launching it from Finder always runs the latest code. Run after making changes.
#   ./Scripts/build-app.sh          # release (default)
#   ./Scripts/build-app.sh debug
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
APP="apps/AnimaStudioDemo.app"
BIN=".build/$CONFIG/AnimaStudioDemo"

echo "[build-app] building ($CONFIG)..."
swift build -c "$CONFIG"

echo "[build-app] updating $APP ..."
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp -f "$BIN" "$APP/Contents/MacOS/AnimaStudioDemo"
rm -rf "$APP/Contents/Resources/RawWebGPU" "$APP/Contents/Resources/ThreeJSWeb"
[ -d Resources/RawWebGPU ] && cp -R Resources/RawWebGPU "$APP/Contents/Resources/"
[ -d Resources/ThreeJSWeb ] && cp -R Resources/ThreeJSWeb "$APP/Contents/Resources/"

echo "[build-app] re-signing (ad-hoc)..."
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

echo "[build-app] done ($CONFIG). Launch $APP from Finder."
