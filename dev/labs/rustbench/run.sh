#!/bin/bash
# Pipeline 2 wrapper: Rust (truck) kernel -> Three.js browser viewer.
# Usage: run.sh <file.step> [scale-ignored]
set -e
cd "$(dirname "$0")"
if [ ! -x target/release/rustbench ]; then
  echo "building rustbench (first run)…"
  cargo build --release 2>&1 | tail -1
fi
OUT=/tmp/rustbench.html
./target/release/rustbench "$1" "$OUT"
open "$OUT"
echo "opened $OUT in your browser"
