#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h}/.."
APP="$ROOT/Codex Bench.app"
test -x "$APP/Contents/MacOS/GeomBench" || "$ROOT/scripts/build.sh"
open "$APP"
