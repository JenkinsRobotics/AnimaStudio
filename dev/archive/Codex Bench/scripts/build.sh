#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
"$PWD/scripts/build-threejs.sh"
swift test
swift build -c release
"$PWD/scripts/make-app.sh"
echo "Built: $PWD/Codex Bench.app"
