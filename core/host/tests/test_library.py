import base64

import pytest

from core.host.backup import restore
from core.host.server import StudioHost
from core.host.state import Problem

PASSWORD = "library-test-password-2026"


@pytest.fixture
def library(tmp_path):
    host = StudioHost(tmp_path / "data")
    owner = host.store.create_user(
        "owner", PASSWORD, "admin", False, full_name="Test Owner"
    )
    member = host.store.create_user(
        "member", PASSWORD, "member", False, full_name="Test Member"
    )
    tokens = [
        host.store.sign_in(name, PASSWORD, "local") for name in ("owner", "member")
    ]

    def call(action, data=None, who=0):
        with host.lock:
            return host.dispatch(
                "/api/library/" + action,
                {"app": "cad", **(data or {})},
                tokens[who],
                "local",
            )

    return host, owner, member, tokens, call


def create(call, **extra):
    return call(
        "create",
        {
            "name": "Part.cadpart",
            "data_base64": base64.b64encode(b"original").decode(),
            **extra,
        },
    )


def test_personal_files_are_private_and_workspace_files_are_read_only_to_others(
    library,
):
    host, _, _, _, call = library
    file = create(call)
    assert call("list", who=1)["files"] == []
    for action in ("read", "save", "copy", "share"):
        with pytest.raises(Problem) as exc:
            call(action, {"id": file["id"], "expected_revision": 1}, who=1)
        assert exc.value.status == 404
    shared = call(
        "share", {"id": file["id"], "expected_revision": 1, "scope": "workspace"}
    )
    assert call("list", {"view": "workspace"}, who=1)["files"][0]["writable"] is False
    assert (
        call("read", {"id": file["id"]}, who=1)["data_base64"]
        == base64.b64encode(b"original").decode()
    )
    for action in ("save", "rename", "share"):
        with pytest.raises(Problem):
            call(
                action,
                {"id": file["id"], "expected_revision": shared["revision"]},
                who=1,
            )
    copied = call("copy", {"id": file["id"]}, who=1)
    assert copied["scope"] == "personal" and copied["writable"]
    assert copied["id"] != file["id"]
    call(
        "share",
        {
            "id": file["id"],
            "expected_revision": shared["revision"],
            "scope": "personal",
        },
    )
    assert call("list", {"view": "recent"}, who=1)["files"] == []
    assert len(call("list", who=1)["files"]) == 1
    assert host.store.ready()


def test_revision_conflict_preserves_newer_content_and_restart(library):
    host, _, _, tokens, call = library
    file = create(call)
    saved = call(
        "save", {"id": file["id"], "expected_revision": 1, "data_base64": "bmV3"}
    )
    assert saved["revision"] == 2
    with pytest.raises(Problem) as exc:
        call(
            "save",
            {"id": file["id"], "expected_revision": 1, "data_base64": "c3RhbGU="},
        )
    assert exc.value.status == 409
    reopened = StudioHost(host.store.directory)
    result = reopened.dispatch(
        "/api/library/read", {"app": "cad", "id": file["id"]}, tokens[0], "local"
    )
    assert result["data_base64"] == "bmV3"


def test_folder_permissions_app_boundary_and_search(library):
    _, _, _, _, call = library
    folder = call("create", {"name": "Models", "kind": "folder"})
    file = create(call, parent=folder["id"])
    assert [f["name"] for f in call("list")["files"]] == ["Models"]
    assert call("list", {"parent": folder["id"]})["files"][0]["id"] == file["id"]
    assert call("list", {"query": "part"})["files"][0]["id"] == file["id"]
    with pytest.raises(Problem):
        call(
            "create",
            {"name": "Invalid", "kind": "folder", "parent": folder["id"]},
            who=1,
        )
    with pytest.raises(Problem):
        create(call, parent=folder["id"], scope="workspace")
    with pytest.raises(Problem):
        call("read", {"id": file["id"], "app": "animation"})


def test_invalid_content_and_name_do_not_create_files(library):
    call = library[-1]
    for extra in (
        {"data_base64": "not base64"},
        {"name": "../outside"},
        {"name": ""},
        {"scope": "public"},
    ):
        with pytest.raises(Problem):
            create(call, **extra)
    assert call("list")["files"] == []


def test_disabled_app_blocks_library(library):
    host, _, _, tokens, call = library
    host.dispatch(
        "/api/admin/apps", {"id": "cad", "enabled": False}, tokens[0], "local"
    )
    with pytest.raises(Problem) as exc:
        call("list")
    assert exc.value.status == 403


def test_backup_contains_library_and_preferences(library, tmp_path):
    host, _, _, tokens, call = library
    file = create(call)
    host.dispatch("/api/preferences", {"theme": "light"}, tokens[0], "local")
    name = host.dispatch("/api/admin/backup", {}, tokens[0], "local")["name"]
    restore(host.store.directory / "backups" / name, tmp_path / "restored")
    reopened = StudioHost(tmp_path / "restored")
    token = reopened.store.sign_in("owner", PASSWORD, "local")
    assert reopened.store.user_for(token)["theme"] == "light"
    assert (
        reopened.dispatch(
            "/api/library/read", {"app": "cad", "id": file["id"]}, token, "local"
        )["name"]
        == file["name"]
    )


def test_preferences_are_shared_by_sessions_and_validate_image_type(library):
    host, owner, _, tokens, _ = library
    another = host.store.sign_in("owner", PASSWORD, "local")
    host.dispatch("/api/preferences", {"theme": "light"}, tokens[0], "local")
    assert host.store.user_for(another)["theme"] == "light"
    for body in (
        {"theme": "pink"},
        {"avatar": "https://untrusted.example/avatar"},
        {"avatar": "data:image/svg+xml;base64,PHN2Zz4="},
    ):
        with pytest.raises(Problem):
            host.dispatch("/api/preferences", body, tokens[0], "local")
    assert host.store.user_for(tokens[1])["theme"] == "dark"
    assert host.store.user_for(tokens[0])["id"] == owner



def test_pdm_branches_and_commits(library):
    import base64

    host, owner, member, tokens, call = library
    created = call(
        "create",
        {
            "name": "part.acpart",
            "scope": "personal",
            "parent": None,
            "data_base64": base64.b64encode(b'{"v":1}').decode(),
        },
    )
    fid = created["id"]
    call(
        "version",
        {"id": fid, "name": "V1", "message": "first checkpoint", "expected_revision": created["revision"]},
    )
    branch = call(
        "branch_create",
        {"id": fid, "name": "concept-b", "expected_revision": created["revision"]},
    )
    saved = call(
        "save",
        {
            "id": fid,
            "branch": "concept-b",
            "expected_revision": branch["head_revision"],
            "data_base64": base64.b64encode(b'{"v":2}').decode(),
        },
    )
    assert saved["branch"] == "concept-b"
    assert saved["revision"] > branch["head_revision"]
    assert base64.b64decode(call("read", {"id": fid})["data_base64"]) == b'{"v":1}'
    assert (
        base64.b64decode(call("read", {"id": fid, "branch": "concept-b"})["data_base64"])
        == b'{"v":2}'
    )
    history = call("history", {"id": fid})
    assert any(v["name"] == "V1" and v["message"] == "first checkpoint" for v in history["versions"])
    assert {b["name"] for b in history["branches"]} == {"Main", "concept-b"}
    with pytest.raises(Problem):
        call(
            "save",
            {
                "id": fid,
                "branch": "concept-b",
                "expected_revision": branch["head_revision"],
                "data_base64": base64.b64encode(b'{"v":3}').decode(),
            },
        )
