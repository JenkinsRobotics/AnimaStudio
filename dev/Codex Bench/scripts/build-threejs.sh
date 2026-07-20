#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h}/.."
WEB="$ROOT/web/threejs"
cd "$WEB"
npm install --ignore-scripts
npm run build
test -f "$ROOT/Resources/ThreeJSWeb/index.html"
test -f "$ROOT/Resources/ThreeJSWeb/app.js"
if find "$ROOT/Resources/ThreeJSWeb" -type f -name '*opengeometry*' | grep -q .; then
  echo "OpenGeometry unexpectedly remained in the Three.js bundle." >&2
  exit 1
fi
echo "Bundled Three.js WebGPURenderer with a reported WebGL 2 fallback."
