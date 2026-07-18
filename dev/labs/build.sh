#!/bin/bash
# Build every standalone lab app. Requires: brew install opencascade
set -e
cd "$(dirname "$0")"
OCCT=$(brew --prefix opencascade)

echo "== OcctSwift package (GeomBench, OcctSwiftViewer, TestLab) =="
(cd OcctSwift && swift build)

echo "== StlViewer (ModelIO baseline) =="
(cd StlViewer && swift build)

echo "== OCCT kernel report =="
mkdir -p bin
clang++ -std=c++17 -O2 kernel_test/occt_test.cpp -o bin/occt_test \
  -I"$OCCT/include/opencascade" -L"$OCCT/lib" -Wl,-rpath,"$OCCT/lib" \
  -lTKernel -lTKMath -lTKG2d -lTKG3d -lTKGeomBase -lTKBRep -lTKGeomAlgo \
  -lTKTopAlgo -lTKPrim -lTKBO -lTKBool -lTKShHealing -lTKFillet -lTKMesh \
  -lTKDESTL -lTKDESTEP -lTKXSBase -Wno-deprecated-declarations

echo "== Qt bench (Pipeline 3) — built only when qt is installed =="
if brew list --versions qt >/dev/null 2>&1; then
  (cd qtbench && cmake -B build -DCMAKE_BUILD_TYPE=Release >/dev/null && cmake --build build 2>&1 | tail -1)
else
  echo "   qt not installed — skipping (brew install qt)"
fi

echo "== Test Lab.app (double-clickable, at the repo root) =="
APP="../../Test Lab.app"
mkdir -p "$APP/Contents/MacOS"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>TestLab</string>
  <key>CFBundleIdentifier</key><string>org.animastudio.testlab</string>
  <key>CFBundleName</key><string>Anima Studio Test Lab</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
</dict></plist>
PLIST
cp OcctSwift/.build/debug/TestLab "$APP/Contents/MacOS/TestLab"
codesign --force --sign - "$APP" 2>/dev/null || true

echo
echo "All built. Double-click 'Test Lab.app' at the repo root,"
echo "or run: ./OcctSwift/.build/debug/TestLab"
