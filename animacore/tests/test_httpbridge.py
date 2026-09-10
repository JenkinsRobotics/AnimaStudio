"""HTTP bridge: the same protocol as stdio, plus asset reads and saves."""

import json
import socket
import subprocess
import sys
import threading
import time
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
    with urllib.request.urlopen(base + "/workspace/assets/probe.obj") as response:
        assert response.read() == b"v 0 0 0\n"
    for escape in ("/workspace/../pyproject.toml", "/workspace/%2e%2e/x"):
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


def test_aether_workspace_rpc_persists_mutates_and_reopens(server):
    base, root = server
    status, created = _post(base, "/rpc", {
        "id": "new", "method": "new_workspace",
        "params": {"name": "HTTP Assembly"},
    })
    assert status == 200 and created["ok"], created
    workspace = created["result"]
    handle = workspace["handle"]
    assembly_id = workspace["root_assembly_id"]

    status, mutated = _post(base, "/rpc", {
        "id": "part", "method": "add_part_definition",
        "params": {
            "handle": handle,
            "expected_revision": workspace["revision"],
            "assembly_id": assembly_id,
            "part_definition": {
                "name": "Bracket", "part_number": "BRK-01", "mass_kg": 0.25,
                "source": {"kind": "authored", "label": "Bracket.step"},
            },
        },
    })
    assert status == 200 and mutated["ok"], mutated
    snapshot = mutated["result"]
    assert snapshot["assembly"]["part_definitions"][0]["name"] == "Bracket"
    assert snapshot["assembly"]["revision"] == snapshot["revision"]
    assert snapshot["solution"]["revision"] == snapshot["revision"]
    assert snapshot["bom"]["revision"] == snapshot["revision"]

    status, saved = _post(base, "/rpc", {
        "id": "save", "method": "save_workspace",
        "params": {
            "handle": handle, "expected_revision": snapshot["revision"],
            "path": "projects/http-assembly.aether",
        },
    })
    assert status == 200 and saved["ok"], saved
    assert (root / "projects" / "http-assembly.aether").is_file()

    _post(base, "/rpc", {
        "id": "release", "method": "release", "params": {"handle": handle}
    })
    status, loaded = _post(base, "/rpc", {
        "id": "load", "method": "load_workspace",
        "params": {"path": "projects/http-assembly.aether"},
    })
    assert status == 200 and loaded["ok"], loaded
    status, described = _post(base, "/rpc", {
        "id": "describe", "method": "describe_assembly",
        "params": {
            "handle": loaded["result"]["handle"], "assembly_id": assembly_id
        },
    })
    assert status == 200 and described["ok"], described
    assert described["result"]["part_definitions"][0]["id"].startswith("part-")


def test_aether_workspace_http_paths_are_confined(server):
    base, _ = server
    _, created = _post(base, "/rpc", {
        "id": "new", "method": "new_workspace", "params": {}
    })
    _, response = _post(base, "/rpc", {
        "id": "save", "method": "save_workspace",
        "params": {"handle": created["result"]["handle"], "path": "../escape.aether"},
    })
    assert response["ok"] is False
    assert response["error"]["code"] == "bad_request"


def test_aether_workspace_rpc_through_real_http_subprocess(tmp_path):
    with socket.socket() as probe:
        probe.bind(("127.0.0.1", 0))
        port = probe.getsockname()[1]
    repo_root = Path(__file__).resolve().parents[2]
    process = subprocess.Popen(
        [
            sys.executable,
            "-m",
            "animacore.httpbridge",
            "--port",
            str(port),
            "--root",
            str(tmp_path),
        ],
        cwd=repo_root,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    base = f"http://127.0.0.1:{port}"
    try:
        deadline = time.monotonic() + 10
        while True:
            try:
                status, created = _post(base, "/rpc", {
                    "id": "new", "method": "new_workspace",
                    "params": {"name": "Subprocess Assembly"},
                })
                break
            except OSError:
                if process.poll() is not None or time.monotonic() >= deadline:
                    stdout, stderr = process.communicate(timeout=1)
                    pytest.fail(
                        f"HTTP bridge did not start (stdout={stdout!r}, stderr={stderr!r})"
                    )
                time.sleep(0.05)
        assert status == 200 and created["ok"], created
        workspace = created["result"]
        status, described = _post(base, "/rpc", {
            "id": "describe", "method": "describe_assembly",
            "params": {
                "handle": workspace["handle"],
                "assembly_id": workspace["root_assembly_id"],
            },
        })
        assert status == 200 and described["ok"], described
        assert described["result"]["workspace_id"] == workspace["workspace_id"]
    finally:
        process.terminate()
        process.wait(timeout=10)
