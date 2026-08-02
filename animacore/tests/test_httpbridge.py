"""HTTP bridge: the same protocol as stdio, plus asset reads and saves."""

import json
import threading
import urllib.request
from pathlib import Path

import pytest

from animacore.httpbridge import serve

EXAMPLES_DIR = Path(__file__).resolve().parents[2] / "examples"


@pytest.fixture()
def server(tmp_path):
    (tmp_path / "assets").mkdir()
    (tmp_path / "assets" / "probe.obj").write_text("v 0 0 0\n")
    httpd = serve(port=0, root=tmp_path)
    thread = threading.Thread(target=httpd.serve_forever, daemon=True)
    thread.start()
    yield f"http://127.0.0.1:{httpd.server_address[1]}", tmp_path
    httpd.shutdown()


def _post(base: str, path: str, payload: dict) -> tuple[int, dict]:
    request = urllib.request.Request(
        base + path, data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(request) as response:
        return response.status, json.loads(response.read())


def test_rpc_round_trip_and_session_persistence(server):
    base, _ = server
    text = (EXAMPLES_DIR / "pan_tilt_head.character.anima").read_text()
    status, loaded = _post(base, "/rpc", {
        "id": 1, "method": "load_character", "params": {"text": text}})
    assert status == 200 and loaded["ok"], loaded
    handle = loaded["result"]["handle"]
    # The session persists across requests: the handle resolves again.
    status, posed = _post(base, "/rpc", {
        "id": 2, "method": "resolve_pose", "params": {"handle": handle}})
    assert status == 200 and posed["ok"]
    assert "base" in posed["result"]["parts"]


def test_asset_get_serves_and_confines(server):
    base, _ = server
    with urllib.request.urlopen(base + "/assets/assets/probe.obj") as response:
        assert response.read() == b"v 0 0 0\n"
    for escape in ("/assets/../pyproject.toml", "/assets/%2e%2e/x"):
        try:
            urllib.request.urlopen(base + escape)
            raised = False
        except urllib.error.HTTPError as error:
            raised = error.code == 404
        assert raised, escape


def test_save_writes_under_root_only(server):
    base, root = server
    status, body = _post(base, "/files/save", {
        "path": "characters/x/x.character.anima", "text": "hello"})
    assert status == 200 and body["saved"]
    assert (root / "characters/x/x.character.anima").read_text() == "hello"
    try:
        _post(base, "/files/save", {"path": "../outside.txt", "text": "no"})
        escaped = False
    except urllib.error.HTTPError as error:
        escaped = error.code == 400
    assert escaped
