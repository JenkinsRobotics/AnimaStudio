#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h}/.."
cmake -S "$ROOT/qt" -B "$ROOT/build/qt" -DCMAKE_BUILD_TYPE=Release
cmake --build "$ROOT/build/qt" --target GeomBenchQtGL GeomBenchQtWebGL --parallel
echo "Archived Qt prototypes built under $ROOT/build/qt."
echo "They are not packaged in the Apple Codex Bench app."
