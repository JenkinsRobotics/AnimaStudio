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

echo
echo "All built. Launch the lab:  ./OcctSwift/.build/debug/TestLab"
