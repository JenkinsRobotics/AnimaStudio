#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h}/.."
test -d "$ROOT/CodexUI.app" || "$ROOT/scripts/make-app.sh"
open "$ROOT/CodexUI.app"
