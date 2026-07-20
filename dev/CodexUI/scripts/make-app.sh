#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h}/.."
APP="$ROOT/CodexUI.app"
swift build --package-path "$ROOT" -c release
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/.build/release/CodexUI" "$APP/Contents/MacOS/CodexUI"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
codesign --force --deep --sign - "$APP"
echo "Built $APP"
