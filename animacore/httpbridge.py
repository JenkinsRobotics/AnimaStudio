"""HTTP transport for the Studio ↔ AnimaCore bridge.

Web front-ends (Aether Animation web) cannot spawn a stdio subprocess, so
this serves the SAME ``handle_request`` protocol over local HTTP:

    POST /rpc             {id, method, params} →  bridge response envelope
    GET  /workspace/<path>                      →  files under --root
                                                   (character assets for the
                                                   viewport; read-only)
    POST /files/save      {path, text}          →  write a text file under
                                                   --root (Save support —
                                                   browsers cannot write the
                                                   workspace themselves)
    GET  /<anything else>                       →  the built web app when
                                                   --app <dist> is given
                                                   (index.html fallback), so
                                                   one port serves app +
                                                   engine with no CORS.

Run: ``python -m animacore.httpbridge [--port 8787] [--root <dir>]
[--app <dist dir>]`` (root defaults to the repository checkout).

# ponytail: plain request/response over ThreadingHTTPServer, stdlib only —
# no websockets dependency until live streaming (hardware preview) needs
# server push. One Session guarded by a lock: handlers are pure dict work,
# so contention is negligible for a single local user.
"""

from __future__ import annotations

import argparse
import json
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from animacore.bridge import Session, handle_request

_REPO_ROOT = Path(__file__).resolve().parents[1]


def _safe_join(root: Path, relative: str) -> Path | None:
    """Resolve ``relative`` under ``root``; None when it escapes."""
    candidate = (root / relative.lstrip("/")).resolve()
    return candidate if candidate.is_relative_to(root.resolve()) else None


def make_handler(session: Session, lock: threading.Lock, root: Path,
                 app_dir: Path | None = None):
    class BridgeHandler(BaseHTTPRequestHandler):
        # Local development server; the web app runs on another port.
        def _cors(self) -> None:
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Access-Control-Allow-Headers", "Content-Type")

        def _reply(self, status: int, payload: dict | bytes,
                   content_type: str = "application/json") -> None:
            body = (json.dumps(payload).encode()
                    if isinstance(payload, dict) else payload)
            self.send_response(status)
            self._cors()
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_OPTIONS(self) -> None:  # noqa: N802 (http.server API)
            self.send_response(204)
            self._cors()
            self.send_header("Access-Control-Allow-Methods", "GET, POST")
            self.end_headers()

        def do_GET(self) -> None:  # noqa: N802
            if self.path.startswith("/workspace/"):
                target = _safe_join(root, self.path[len("/workspace/"):])
                if target is None or not target.is_file():
                    self._reply(404, {"error": "not found"})
                    return
                self._reply(200, target.read_bytes(),
                            content_type="application/octet-stream")
                return
            if app_dir is not None:
                relative = self.path.split("?", 1)[0].lstrip("/") or "index.html"
                target = _safe_join(app_dir, relative)
                if target is None or not target.is_file():
                    target = app_dir / "index.html"  # SPA fallback
                if target.is_file():
                    self._reply(200, target.read_bytes(),
                                content_type=_content_type(target))
                    return
            self._reply(404, {"error": "unknown path"})

        def do_POST(self) -> None:  # noqa: N802
            length = int(self.headers.get("Content-Length", "0"))
            try:
                payload = json.loads(self.rfile.read(length) or b"{}")
            except json.JSONDecodeError:
                self._reply(400, {"error": "invalid JSON"})
                return
            if self.path == "/rpc":
                with lock:
                    response = handle_request(session, payload)
                self._reply(200, response)
                return
            if self.path == "/files/save":
                relative = payload.get("path")
                text = payload.get("text")
                if not isinstance(relative, str) or not isinstance(text, str):
                    self._reply(400, {"error": "'path' and 'text' required"})
                    return
                target = _safe_join(root, relative)
                if target is None:
                    self._reply(400, {"error": "path escapes root"})
                    return
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text(text)
                self._reply(200, {"saved": relative})
                return
            self._reply(404, {"error": "unknown path"})

        def log_message(self, *_args) -> None:  # quiet local server
            pass

    return BridgeHandler


_CONTENT_TYPES = {
    ".html": "text/html", ".js": "text/javascript", ".css": "text/css",
    ".json": "application/json", ".svg": "image/svg+xml",
    ".wasm": "application/wasm", ".png": "image/png",
}


def _content_type(path: Path) -> str:
    return _CONTENT_TYPES.get(path.suffix, "application/octet-stream")


def serve(port: int = 8787, root: Path | None = None,
          app_dir: Path | None = None) -> ThreadingHTTPServer:
    """Build the server (caller decides threading/serve_forever)."""
    workspace_root = (root or _REPO_ROOT).resolve()
    session = Session(workspace_root=workspace_root)
    lock = threading.Lock()
    handler = make_handler(session, lock, workspace_root, app_dir)
    return ThreadingHTTPServer(("127.0.0.1", port), handler)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8787)
    parser.add_argument("--root", type=Path, default=_REPO_ROOT)
    parser.add_argument("--app", type=Path, default=None,
                        help="built web app (dist) to serve at /")
    arguments = parser.parse_args()
    server = serve(arguments.port, arguments.root, arguments.app)
    print(f"animacore http bridge on http://127.0.0.1:{arguments.port} "
          f"(root: {arguments.root})")
    server.serve_forever()


if __name__ == "__main__":
    main()
