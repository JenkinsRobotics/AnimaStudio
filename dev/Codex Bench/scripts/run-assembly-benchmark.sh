#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}/.."
APP="$ROOT/Codex Bench.app"
CORPUS="${1:?usage: run-assembly-benchmark.sh /path/to/step-corpus [output-directory]}"
OUTPUT="${2:-$ROOT/Reports/2026-07-19-assembly-benchmark/raw}"
files=("$CORPUS"/**/*.(step|stp)(N))

if (( ${#files} < 2 )); then
  echo "Expected at least two STEP/STP files under $CORPUS" >&2
  exit 1
fi

file_arguments=()
for file in "${files[@]}"; do
  file_arguments+=(--file "$file")
done

mkdir -p "$OUTPUT"
pipelines=(${=CODEX_BENCH_PIPELINES:-1 2 5 7})
for pipeline in "${pipelines[@]}"; do
  result="$OUTPUT/pipeline-$pipeline.json"
  rm -f "$result"
  open -n -F -W --env CODEX_BENCH_MERGE_FILES=1 "$APP" --args \
    --pipeline "$pipeline" \
    "${file_arguments[@]}" \
    --benchmark-output "$result" \
    --benchmark-warmup 3 \
    --benchmark-duration 5 &
  launcher_pid=$!
  sleep 0.5
  osascript -e 'tell application id "com.animastudio.codexbench" to activate' >/dev/null \
    2>&1 || true

  deadline=$((SECONDS + 600))
  while [[ ! -f "$result" ]]; do
    if ! kill -0 "$launcher_pid" 2>/dev/null; then
      echo "Pipeline $pipeline exited before writing a result" >&2
      break
    fi
    if (( SECONDS >= deadline )); then
      echo "Timed out waiting for Pipeline $pipeline" >&2
      kill "$launcher_pid" 2>/dev/null || true
      wait "$launcher_pid" 2>/dev/null || true
      continue 2
    fi
    sleep 0.25
  done
  wait "$launcher_pid" 2>/dev/null || true
  if [[ ! -f "$result" ]]; then
    continue
  elif jq -e '.success == true' "$result" >/dev/null; then
    echo "Pipeline $pipeline complete: $result"
  else
    echo "Pipeline $pipeline reported a failure: $result" >&2
  fi
done
