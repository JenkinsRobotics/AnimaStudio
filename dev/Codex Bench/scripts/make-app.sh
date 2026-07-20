#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h}/.."
APP="$ROOT/Codex Bench.app"
BIN="$ROOT/.build/release/GeomBench"
swift build --package-path "$ROOT" -c release
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
rm -rf "$APP/Contents/MacOS/GeomBenchQtGL.app" "$APP/Contents/MacOS/GeomBenchQtWebGL.app"
cp "$BIN" "$APP/Contents/MacOS/GeomBench"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
rm -rf "$APP/Contents/Resources/OpenGeometryWeb"
rm -rf "$APP/Contents/Resources/ThreeJSWeb"
rm -rf "$APP/Contents/Resources/RawWebGPU"
if [[ -f "$ROOT/Resources/ThreeJSWeb/index.html" ]]; then
  cp -R "$ROOT/Resources/ThreeJSWeb" "$APP/Contents/Resources/ThreeJSWeb"
fi
if [[ -f "$ROOT/Resources/RawWebGPU/index.html" ]]; then
  cp -R "$ROOT/Resources/RawWebGPU" "$APP/Contents/Resources/RawWebGPU"
fi
codesign --force --deep --sign - "$APP"
