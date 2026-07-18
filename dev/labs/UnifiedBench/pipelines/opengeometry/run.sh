#!/bin/bash
# OpenGeometry bench — serve locally (WASM+ES modules need http, not file://)
# and open the page. Ctrl-C to stop the server.
set -e
cd "$(dirname "$0")"
[ -d node_modules/opengeometry ] || npm install opengeometry
PORT=8777
python3 -m http.server $PORT >/dev/null 2>&1 &
SERVER=$!
sleep 1
open "http://localhost:$PORT/index.html"
echo "OpenGeometry bench at http://localhost:$PORT/  (server PID $SERVER — Ctrl-C to stop)"
wait $SERVER
