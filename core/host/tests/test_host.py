import hashlib
import json
import threading
import urllib.error
import urllib.request
import zipfile
from http.server import ThreadingHTTPServer

import pytest

from core.host.backup import restore
from core.host.server import StudioHost, make_handler, validate_settings
from core.host.state import DEFAULT_SETTINGS, Problem, Store

PASSWORD = "test-password-not-for-real-use"


@pytest.fixture
def host(tmp_path):
    instance = StudioHost(tmp_path / "data")
    uid = instance.store.create_user("owner", PASSWORD, "admin", False)
    token = instance.store.sign_in("owner", PASSWORD, "127.0.0.1")
    return instance, uid, token


def call(host, path, data, token=None):
    instance, _, admin_token = host
    with instance.lock:
        return instance.dispatch(
            path, data, token if token is not None else admin_token, "127.0.0.1"
        )


def member(host):
    uid = host[0].store.create_user("member", PASSWORD, "member", False)
    return uid, host[0].store.sign_in("member", PASSWORD, "127.0.0.1")


def test_setup_is_claimed_once_and_password_is_hashed(tmp_path):
    instance = StudioHost(tmp_path)
    with pytest.raises(Problem) as error:
        instance.dispatch(
            "/api/setup",
            {"token": "wrong", "username": "owner", "password": PASSWORD},
            "",
            "127.0.0.1",
        )
    assert error.value.status == 403
    token = instance.store.setup_path.read_text()
    instance.dispatch(
        "/api/setup",
        {
            "token": token,
            "username": "owner",
            "password": PASSWORD,
            "full_name": "Test Owner",
            "email": "owner@example.test",
        },
        "",
        "127.0.0.1",
    )
    assert not instance.store.setup_path.exists()
    assert (
        instance.store.db.execute("SELECT password FROM users").fetchone()[0]
        != PASSWORD
    )
    with pytest.raises(Problem) as error:
        instance.dispatch("/api/setup", {"token": token}, "", "127.0.0.1")
    assert error.value.status == 409


def test_member_cannot_admin_or_read_other_user_files(host):
    uid, token = member(host)
    with pytest.raises(Problem) as error:
        call(host, "/api/admin/apps", {"id": "cad", "enabled": False}, token)
    assert error.value.status == 403
    root = host[0].root_for(uid)
    outside = root.parent / host[1] / "secret.txt"
    outside.parent.mkdir(exist_ok=True)
    outside.write_text("private")
    with pytest.raises(Problem) as error:
        call(
            host,
            "/cad/files/save",
            {"path": f"../{host[1]}/secret.txt", "text": "overwrite"},
            token,
        )
    assert error.value.status == 403
    assert outside.read_text() == "private"


def test_engine_handles_are_isolated_by_login_and_app(host):
    instance, _, token = host
    second = instance.store.sign_in("owner", PASSWORD, "127.0.0.1")
    for app, credential in [("cad", token), ("animation", token), ("cad", second)]:
        result = call(
            host,
            f"/{app}/rpc",
            {"id": 1, "method": "new_workspace", "params": {"name": "Test"}},
            credential,
        )
        assert result["ok"]
    assert len(instance.engines) == 3
    assert len({id(session) for session in instance.engines.values()}) == 3


def test_file_save_conflict_and_restart_persistence(host):
    result = call(host, "/animation/files/save", {"path": "scene.txt", "text": "first"})
    assert result["revision"] == hashlib.sha256(b"first").hexdigest()
    with pytest.raises(Problem) as error:
        call(host, "/animation/files/save", {"path": "scene.txt", "text": "stale"})
    assert error.value.status == 409
    call(
        host,
        "/animation/files/save",
        {
            "path": "scene.txt",
            "text": "second",
            "expected_revision": result["revision"],
        },
    )
    reopened = StudioHost(host[0].store.directory)
    assert reopened.store.user_for(host[2])["id"] == host[1]
    assert (reopened.root_for(host[1]) / "scene.txt").read_text() == "second"


def test_reset_revokes_sessions_and_requires_password_change(host):
    uid, token = member(host)
    call(
        host,
        "/api/admin/user",
        {"id": uid, "action": "reset_password", "password": PASSWORD + "new"},
    )
    assert host[0].store.user_for(token) is None
    temporary = host[0].store.sign_in("member", PASSWORD + "new", "127.0.0.1")
    with pytest.raises(Problem) as error:
        call(host, "/cad/rpc", {"method": "hello"}, temporary)
    assert error.value.status == 403
    call(
        host,
        "/api/password",
        {"current_password": PASSWORD + "new", "password": PASSWORD + "final"},
        temporary,
    )
    assert host[0].store.user_for(temporary) is None
    final = host[0].store.sign_in("member", PASSWORD + "final", "127.0.0.1")
    assert not host[0].store.user_for(final)["must_change"]


def test_last_admin_and_self_disable_guard(host):
    with pytest.raises(Problem) as error:
        call(
            host,
            "/api/admin/user",
            {"id": host[1], "action": "update", "role": "member", "active": True},
        )
    assert error.value.status == 409


def test_disabled_user_revoked_immediately(host):
    uid, token = member(host)
    call(
        host,
        "/api/admin/user",
        {"id": uid, "action": "update", "role": "member", "active": False},
    )
    assert host[0].store.user_for(token) is None
    with pytest.raises(Problem):
        host[0].store.sign_in("member", PASSWORD, "127.0.0.1")


def test_app_disable_blocks_rpc(host):
    call(host, "/api/admin/apps", {"id": "cad", "enabled": False})
    with pytest.raises(Problem) as error:
        call(host, "/cad/rpc", {"method": "hello"})
    assert error.value.status == 403


def test_team_membership_enforces_restricted_apps(host):
    uid, token = member(host)
    call(host, "/api/admin/access", {"id": "cad", "restricted": True})
    with pytest.raises(Problem):
        call(
            host,
            "/cad/rpc",
            {"id": 1, "method": "hello", "params": {"protocol_version": 1}},
            token,
        )
    call(host, "/api/admin/team", {"name": "Design", "members": [uid], "apps": ["cad"]})
    assert call(
        host,
        "/cad/rpc",
        {"id": 1, "method": "hello", "params": {"protocol_version": 1}},
        token,
    )["ok"]
    team = host[0].store.db.execute("SELECT id FROM teams").fetchone()[0]
    call(host, "/api/admin/team", {"id": team, "action": "delete"})
    with pytest.raises(Problem):
        call(host, "/cad/rpc", {"method": "hello"}, token)


def test_service_scope_expiry_and_revocation(host):
    secret = call(
        host, "/api/admin/service", {"name": "robot", "apps": ["animation"], "days": 1}
    )["token"]
    assert call(
        host,
        "/animation/rpc",
        {"method": "hello", "params": {"protocol_version": 1}},
        secret,
    )["ok"]
    for path in ("/cad/rpc", "/api/admin/apps"):
        with pytest.raises(Problem) as error:
            call(host, path, {"method": "hello"}, secret)
        assert error.value.status == 403
    service = host[0].store.db.execute("SELECT * FROM services").fetchone()
    assert service["token"] != secret
    call(host, "/api/admin/service", {"id": service["id"], "action": "revoke"})
    assert host[0].store.user_for(secret) is None


def test_network_validation(host):
    validate_settings(DEFAULT_SETTINGS)
    for settings in [
        {**DEFAULT_SETTINGS, "bind_address": "0.0.0.0"},
        {**DEFAULT_SETTINGS, "port": 80},
        {
            **DEFAULT_SETTINGS,
            "public_url": "https://localhost:8780",
            "tls_cert": "/missing",
        },
    ]:
        with pytest.raises(Problem):
            validate_settings(settings)
    call(host, "/api/admin/settings", {**DEFAULT_SETTINGS, "name": "Workshop"})
    assert Store(host[0].store.directory).settings()["name"] == "Workshop"


def test_backup_restore_preserves_saved_work_but_revokes_credentials(host, tmp_path):
    call(host, "/cad/files/save", {"path": "saved.txt", "text": "project"})
    name = call(host, "/api/admin/backup", {})["name"]
    archive = host[0].store.directory / "backups" / name
    with zipfile.ZipFile(archive) as zipped:
        assert "studio.sqlite3" in zipped.namelist()
        assert "setup-token" not in zipped.namelist()
    destination = tmp_path / "restored"
    restore(archive, destination)
    recovered = StudioHost(destination)
    assert recovered.store.ready()
    assert recovered.store.user_for(host[2]) is None
    assert (recovered.root_for(host[1]) / "saved.txt").read_text() == "project"
    with pytest.raises(Problem):
        restore(archive, destination)


def test_restore_rejects_traversal(tmp_path):
    archive = tmp_path / "bad.zip"
    with zipfile.ZipFile(archive, "w") as zipped:
        zipped.writestr("backup.json", '{"version":1}')
        zipped.writestr("../escape", "bad")
    with pytest.raises(Problem):
        restore(archive, tmp_path / "restore")
    assert not (tmp_path / "escape").exists()


def test_login_rate_limit_and_audit_excludes_password(host):
    store = host[0].store
    for _ in range(10):
        with pytest.raises(Problem):
            store.sign_in("owner", "wrong-password", "127.0.0.1")
    with pytest.raises(Problem) as error:
        store.sign_in("owner", PASSWORD, "127.0.0.1")
    assert error.value.status == 429
    assert PASSWORD not in str(
        [tuple(row) for row in store.db.execute("SELECT * FROM audit")]
    )


def test_http_cookie_csrf_and_host_boundary(host):
    instance = host[0]
    server = ThreadingHTTPServer(("127.0.0.1", 0), make_handler(instance))
    worker = threading.Thread(target=server.serve_forever, daemon=True)
    worker.start()
    origin = f"http://127.0.0.1:{server.server_port}"
    try:

        def request(path, data=None, headers=None):
            return urllib.request.urlopen(
                urllib.request.Request(
                    origin + path,
                    data=json.dumps(data).encode() if data is not None else None,
                    headers=headers or {},
                )
            )

        for headers in [
            {"Content-Type": "application/json"},
            {"Content-Type": "application/json", "Origin": "https://evil.example"},
            {
                "Host": "evil.example",
                "Origin": origin,
                "Content-Type": "application/json",
            },
        ]:
            with pytest.raises(urllib.error.HTTPError) as error:
                request(
                    "/api/login", {"username": "owner", "password": PASSWORD}, headers
                )
            assert error.value.code == 403
        response = request(
            "/api/login",
            {"username": "owner", "password": PASSWORD},
            {"Origin": origin, "Content-Type": "application/json"},
        )
        cookie = response.headers["Set-Cookie"]
        assert "HttpOnly" in cookie and "SameSite=Strict" in cookie
        state = json.load(request("/api/admin/state", headers={"Cookie": cookie}))
        assert "password" not in state["mail"]
        assert all("password" not in user for user in state["users"])
        with pytest.raises(urllib.error.HTTPError) as error:
            request("/api/admin/state")
        assert error.value.code == 401
        with pytest.raises(urllib.error.HTTPError) as error:
            request(
                "/api/login", [], {"Origin": origin, "Content-Type": "application/json"}
            )
        assert error.value.code == 400
    finally:
        server.shutdown()
        server.server_close()


def test_setup_persists_workspace_and_app_choices_atomically(tmp_path):
    packages = {}
    for app in ("cad", "animation", "ui"):
        directory = tmp_path / app
        directory.mkdir()
        (directory / "index.html").write_text("built")
        packages[app] = (app, app, directory)
    instance = StudioHost(tmp_path / "data", packages)
    token = instance.store.setup_path.read_text()
    payload = {
        "token": token,
        "username": "owner",
        "password": PASSWORD,
        "full_name": "Test Owner",
        "email": "owner@example.test",
        "name": "Workshop",
        "apps": ["animation"],
    }
    with pytest.raises(Problem):
        instance.dispatch(
            "/api/setup", {**payload, "password": "short"}, "", "127.0.0.1"
        )
    assert not instance.store.ready()
    assert instance.store.settings()["name"] == "Aether Studio"
    assert instance.store.setup_path.exists()
    with pytest.raises(Problem):
        instance.dispatch(
            "/api/setup", {**payload, "apps": ["uninstalled"]}, "", "127.0.0.1"
        )
    assert not instance.store.ready()
    instance.dispatch("/api/setup", payload, "", "127.0.0.1")
    assert instance.store.settings()["name"] == "Workshop"
    assert instance.running_settings["name"] == "Workshop"
    assert dict(instance.store.db.execute("SELECT id,enabled FROM applications")) == {
        "cad": 0,
        "animation": 1,
        "ui": 0,
    }
    reopened = Store(instance.store.directory)
    assert reopened.ready() and reopened.settings()["name"] == "Workshop"
    assert not instance.store.setup_path.exists()


def test_theme_settings_flow(tmp_path):
    from core.host.state import Store

    store = Store(tmp_path / "state")
    assert store.settings()["theme"] == {"base": "aether-default", "apps": {}}
    store.db.execute(
        "UPDATE settings SET value=? WHERE key='theme'",
        ('{"base": "community-neon", "apps": {"cad": "aether-default"}}',),
    )
    store.db.commit()
    assert store.settings()["theme"]["base"] == "community-neon"
    assert store.settings()["theme"]["apps"]["cad"] == "aether-default"
