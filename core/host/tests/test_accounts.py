import json
import sqlite3
from unittest.mock import MagicMock, patch

import pytest

from core.host.mail import Mailer, identity
from core.host.server import StudioHost
from core.host.state import Problem, Store, password_hash

PASSWORD = "account-test-password-2026"


def test_legacy_account_migration(tmp_path):
    db = sqlite3.connect(tmp_path / "studio.sqlite3")
    db.execute(
        "CREATE TABLE users (id TEXT PRIMARY KEY, username TEXT UNIQUE NOT NULL, password TEXT NOT NULL, role TEXT NOT NULL, active INTEGER NOT NULL DEFAULT 1, must_change INTEGER NOT NULL DEFAULT 0)"
    )
    db.execute(
        "INSERT INTO users VALUES (?,?,?,?,1,0)",
        ("old", "owner", password_hash(PASSWORD), "admin"),
    )
    db.commit()
    db.close()
    store = Store(tmp_path)
    token = store.sign_in("owner", PASSWORD, "local")
    assert store.user_for(token)["full_name"] == ""
    assert store.user_for(token)["id"] == "old"


def test_identity_and_recovery_lifecycle(tmp_path):
    store = Store(tmp_path)
    name, email = identity(" Test Owner ", "OWNER@example.test")
    uid = store.create_user(
        "owner", PASSWORD, "admin", False, full_name=name, email=email
    )
    session = store.sign_in("OWNER@example.test", PASSWORD, "local")
    assert store.user_for(session)["full_name"] == "Test Owner"
    with pytest.raises(Problem):
        store.create_user(
            "duplicate", PASSWORD, "member", False, full_name=name, email=email.upper()
        )
    token = store.recovery_token(uid)
    assert store.db.execute("SELECT token FROM recovery_tokens").fetchone()[0] != token
    with pytest.raises(Problem):
        store.recover_password(token, "short")
    store.recover_password(token, PASSWORD + "-new")
    assert store.user_for(session) is None
    with pytest.raises(Problem):
        store.recover_password(token, PASSWORD)
    session = store.sign_in(email, PASSWORD + "-new", "local")
    assert store.user_for(session)["email_verified"] == 1
    token = store.recovery_token(uid)
    store.update_identity(uid, name, "new@example.test")
    with pytest.raises(Problem):
        store.recover_password(token, PASSWORD)
    token = store.recovery_token(uid)
    store.db.execute("UPDATE recovery_tokens SET expires=0")
    with pytest.raises(Problem):
        store.recover_password(token, PASSWORD)
    token = store.recovery_token(uid)
    store.db.execute("UPDATE users SET active=0")
    with pytest.raises(Problem):
        store.recover_password(token, PASSWORD)


def test_setup_authorization_survives_store_reopen_and_is_consumed(tmp_path):
    host = StudioHost(tmp_path)
    session = host.dispatch(
        "/api/setup/authorize",
        {"token": host.store.setup_path.read_text()},
        "",
        "local",
    )["_setup_cookie"]
    assert Store(tmp_path).setup_authorized(session)
    assert not host.store.setup_authorized("wrong")
    host.dispatch(
        "/api/setup",
        {
            "username": "owner",
            "password": PASSWORD,
            "full_name": "Test Owner",
            "email": "owner@example.test",
        },
        "",
        "local",
        session,
    )
    assert not host.store.setup_authorized(session)
    with pytest.raises(Problem):
        host.store.authorize_setup(session)


def test_recovery_uses_configured_origin_generic_response_and_throttling(tmp_path):
    host = StudioHost(tmp_path)
    host.store.create_user(
        "owner",
        PASSWORD,
        "admin",
        False,
        full_name="Test Owner",
        email="owner@example.test",
    )
    host.mailer.save(
        {"enabled": True, "host": "smtp.example.test", "sender": "studio@example.test"}
    )
    host.running_settings["public_url"] = "https://studio.example.test"
    sent = []
    host.enqueue_mail = lambda *args: sent.append(args)
    unknown = host.dispatch(
        "/api/recovery/request", {"account": "missing"}, "", "local"
    )
    known = host.dispatch(
        "/api/recovery/request", {"account": "owner@example.test"}, "", "local"
    )
    assert unknown == known
    assert len(sent) == 1
    assert "https://studio.example.test/#reset=" in sent[0][2]
    assert PASSWORD not in sent[0][2]
    for _ in range(5):
        assert (
            host.dispatch(
                "/api/recovery/request", {"account": "owner@example.test"}, "", "local"
            )
            == known
        )
    assert len(sent) == 3


@pytest.mark.parametrize("security", ["tls", "starttls"])
def test_smtp_secrets_and_encryption(tmp_path, security):
    mailer = Mailer(tmp_path)
    mailer.save(
        {
            "enabled": True,
            "host": "smtp.example.test",
            "security": security,
            "sender": "studio@example.test",
            "username": "smtp-user",
            "password": "smtp-secret",
        }
    )
    mailer.save({"password": ""})
    assert mailer.config()["password"] == "smtp-secret"
    assert "password" not in mailer.public_config()
    assert mailer.path.stat().st_mode & 0o777 == 0o600
    connection = MagicMock()
    connection.__enter__.return_value = connection
    with (
        patch("core.host.mail.smtplib.SMTP", return_value=connection) as smtp,
        patch("core.host.mail.smtplib.SMTP_SSL", return_value=connection) as tls,
    ):
        mailer.send("owner@example.test", "Test", "Test delivery")
        assert (tls if security == "tls" else smtp).call_count == 1
        assert connection.starttls.call_count == (security == "starttls")
        connection.login.assert_called_once_with("smtp-user", "smtp-secret")
        connection.send_message.assert_called_once()
    assert "smtp-secret" not in json.dumps(mailer.public_config())
