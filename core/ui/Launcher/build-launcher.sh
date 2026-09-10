#!/bin/zsh
set -euo pipefail
script_dir="${0:A:h}"
repo_root="${script_dir:h:h:h}"
cd "$repo_root"
npm run build --prefix 'core/ui'
.venv/bin/python core/host/build-browser-launcher.py ui
