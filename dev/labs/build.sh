#!/bin/bash
# Build Unified Bench (the one benchmark app) + its external pipelines.
# Requires: brew install opencascade  (qt optional, for the Qt pipeline)
set -e
cd "$(dirname "$0")"

echo "== Unified Bench (Swift + Open CASCADE + RealityKit/Metal/SceneKit/...) =="
(cd UnifiedBench && swift build)

echo "== app bundle at dev/labs/apps/UnifiedBench.app =="
APP="apps/UnifiedBench.app"
mkdir -p "$APP/Contents/MacOS"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>UnifiedBench</string>
  <key>CFBundleIdentifier</key><string>org.animastudio.lab.UnifiedBench</string>
  <key>CFBundleName</key><string>Unified Bench</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
</dict></plist>
PLIST
cp UnifiedBench/.build/debug/UnifiedBench "$APP/Contents/MacOS/UnifiedBench"
codesign --force --sign - "$APP" 2>/dev/null || true

echo "== Qt pipeline (only if qt installed) =="
if brew list --versions qt >/dev/null 2>&1; then
  (cd UnifiedBench/pipelines/qt && cmake -B build -DCMAKE_BUILD_TYPE=Release >/dev/null && cmake --build build 2>&1 | tail -1)
else
  echo "   qt not installed — Qt pipeline shows 'build first' (brew install qt)"
fi

echo
echo "All built. Launch:  open dev/labs/apps/UnifiedBench.app"
echo "(archive/ holds the superseded standalone experiments.)"
