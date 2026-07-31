#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}/.."
APP="$ROOT/Codex Bench.app"
MODEL="${1:?usage: run-kept-pipelines.sh /path/to/model.step [output-directory]}"
OUTPUT="${2:-$ROOT/Reports/2026-07-19-kept-pipelines/raw}"

mkdir -p "$OUTPUT"
for pipeline in 1 2 5 7; do
  result="$OUTPUT/pipeline-$pipeline.json"
  rm -f "$result"
  open -n "$APP" --args \
    --pipeline "$pipeline" \
    --file "$MODEL" \
    --benchmark-output "$result" \
    --benchmark-warmup 3 \
    --benchmark-duration 5

  deadline=$((SECONDS + 90))
  while [[ ! -f "$result" ]]; do
    if (( SECONDS >= deadline )); then
      echo "Timed out waiting for Pipeline $pipeline" >&2
      exit 1
    fi
    sleep 0.25
  done
  jq -e '.success == true' "$result" >/dev/null
  echo "Pipeline $pipeline complete: $result"
done
