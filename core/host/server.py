"""Authenticated same-origin host for the bundled Aether applications."""

from __future__ import annotations

import hashlib
import ipaddress
import json
import queue
import mimetypes
import os
import secrets
import shutil
import ssl
import socket
import threading
import time
import sqlite3
import tempfile
import zipfile
from http.cookies import SimpleCookie
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import quote, unquote, urlsplit

from animacore.bridge import Session, handle_request
from core.host.state import Problem, Store, password_matches
from core.host.library import Library
from core.host.mail import Mailer, identity

REPO = Path(__file__).resolve().parents[2]
PACKAGES = {
    "cad": ("Aether CAD", "Design parts and assemblies", REPO / "Aether CAD/dist"),
    "animation": (
        "Aether Animation",
        "Rig, pose and animate characters",
        REPO / "aether-animation/web/dist",
    ),
    "ui": ("Aether UI", "Shared components and design review", REPO / "core/ui/dist"),
}


def safe_path(root, relative):
    target = (root / relative).resolve()
    if not target.is_relative_to(root.resolve()):
        raise Problem(403, "Path is outside your workspace.")
    return target


def validate_settings(settings):
    if set(settings) - {"theme"} != {
        "name",
        "bind_address",
        "port",
        "public_url",
        "tls_cert",
        "tls_key",
    }:
        raise Problem(400, "Invalid server settings.")
    if (
        not isinstance(settings["name"], str)
        or not 1 <= len(settings["name"].strip()) <= 80
    ):
        raise Problem(400, "Server name must be 1–80 characters.")
    try:
        address = ipaddress.IPv4Address(settings["bind_address"])
        if type(settings["port"]) is not int or not 1024 <= settings["port"] <= 65535:
            raise ValueError()
        url = urlsplit(settings["public_url"])
        if (
            url.scheme not in ("http", "https")
            or not url.hostname
            or url.username
            or url.password
            or url.path not in ("", "/")
            or url.query
            or url.fragment
        ):
            raise ValueError()
        if (url.port or (443 if url.scheme == "https" else 80)) != settings["port"]:
            raise Problem(400, "Public URL port must match the listening port.")
        if address.is_loopback and not (
            url.hostname == "localhost"
            or ipaddress.ip_address(url.hostname).is_loopback
        ):
            raise Problem(400, "A local-only server needs a localhost public URL.")
    except (ValueError, TypeError):
        raise Problem(
            400, "Enter a valid IPv4 bind address, port and public URL."
        ) from None
    if not address.is_loopback and url.scheme != "https":
        raise Problem(
            400, "Network access requires HTTPS and a certificate/key on this host."
        )
    if url.scheme == "https":
        try:
            context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            context.load_cert_chain(settings["tls_cert"], settings["tls_key"])
        except (OSError, ssl.SSLError, TypeError):
            raise Problem(
                400, "The TLS certificate and private key could not be loaded."
            ) from None
    elif settings["tls_cert"] or settings["tls_key"]:
        raise Problem(400, "Use an HTTPS public URL with TLS certificate settings.")


class StudioHost:
    def __init__(self, directory: Path, packages=None):
        self.store = Store(directory)
        self.library = Library(self.store)
        self.mailer = Mailer(directory)
        self.mail_queue = queue.Queue(maxsize=32)
        self.mail_worker_started = False
        self.packages = packages or PACKAGES
        self.running_settings = self.store.settings()
        self.lock = threading.RLock()
        self.engines = {}
        self.started = time.time()
        self.server = None
        self.restart_requested = False

    def enqueue_mail(self, recipient, subject, body, kind):
        if not self.mail_worker_started:
            self.mail_worker_started = True

            def worker():
                while True:
                    job = self.mail_queue.get()
                    try:
                        to, title, text, category = job
                        self.mailer.send(to, title, text)
                        with self.lock:
                            self.store.audit("mail", "email_sent", category)
                    except Exception:
                        with self.lock:
                            self.store.audit(
                                "mail",
                                "email_delivery_failed",
                                "Check SMTP settings and retry",
                            )
                    finally:
                        self.mail_queue.task_done()

            threading.Thread(target=worker, daemon=True).start()
        try:
            self.mail_queue.put_nowait((recipient, subject, body, kind))
            return True
        except queue.Full:
            self.store.audit("mail", "email_queue_full", kind)
            return False

    def app_allowed(self, app, user):
        if user["role"] == "admin":
            return True
        if app == "ui":
            return False
        if user["role"] == "service":
            return app in user["apps"]
        restricted = self.store.db.execute(
            "SELECT restricted FROM app_access WHERE id=?", (app,)
        ).fetchone()[0]
        return not restricted or any(
            user["id"] in json.loads(row["members"]) and app in json.loads(row["apps"])
            for row in self.store.db.execute("SELECT * FROM teams")
        )

    def backup(self):
        directory = self.store.directory / "backups"
        directory.mkdir(exist_ok=True, mode=0o700)
        name = f"studio-{time.strftime('%Y%m%d-%H%M%S')}-{secrets.token_hex(3)}.zip"
        with tempfile.TemporaryDirectory() as temporary:
            snapshot = Path(temporary) / "studio.sqlite3"
            connection = sqlite3.connect(snapshot)
            self.store.db.backup(connection)
            connection.execute("DELETE FROM sessions")
            connection.execute("DELETE FROM recovery_tokens")
            connection.execute("DELETE FROM setup_sessions")
            connection.execute("DELETE FROM attempts")
            connection.execute("UPDATE services SET token='', active=0")
            connection.commit()
            connection.close()
            with zipfile.ZipFile(
                directory / name, "w", zipfile.ZIP_DEFLATED
            ) as archive:
                archive.write(snapshot, "studio.sqlite3")
                archive.writestr(
                    "backup.json", json.dumps({"version": 1, "created": time.time()})
                )
                workspace = self.store.directory / "workspaces"
                if workspace.exists():
                    for item in workspace.rglob("*"):
                        if (
                            item.is_file()
                            and not item.is_symlink()
                            and item.resolve().is_relative_to(workspace.resolve())
                        ):
                            archive.write(
                                item, str(item.relative_to(self.store.directory))
                            )
        (directory / name).chmod(0o600)
        return name

    def apps(self, user):
        enabled = dict(self.store.db.execute("SELECT id,enabled FROM applications"))
        return [
            {
                "id": key,
                "name": value[0],
                "description": value[1],
                "enabled": bool(enabled[key]),
                "installed": (value[2] / "index.html").is_file(),
                "url": f"/{key}/",
                "admin_only": key == "ui",
            }
            for key, value in self.packages.items()
            if self.app_allowed(key, user)
        ]

    def root_for(self, uid):
        root = self.store.directory / "workspaces" / uid
        if not root.exists():
            root.mkdir(parents=True, mode=0o700)
            examples = root / "examples"
            examples.mkdir()
            # Seed only the working animation sample, never the repository or host config.
            source = REPO / "examples/pan_tilt_head.character.anima"
            if source.is_file():
                shutil.copy2(source, examples / source.name)
                for name in ("base.stl", "yoke.stl", "head.usdz"):
                    asset = REPO / "examples/assets" / name
                    if asset.is_file():
                        (examples / "assets").mkdir(exist_ok=True)
                        shutil.copy2(asset, examples / "assets" / name)
        return root

    def require_user(self, token, admin=False, allow_change=False):
        user = self.store.user_for(token)
        if not user:
            raise Problem(401, "Sign in to Aether Studio.")
        if user["must_change"] and not allow_change:
            raise Problem(
                403, "Change your temporary password before opening applications."
            )
        if admin and user["role"] != "admin":
            raise Problem(403, "Administrator access is required.")
        return user

    def dispatch(self, path, data, token, address, setup_token=""):
        store = self.store
        if path == "/api/setup/authorize":
            return {
                "ok": True,
                "_setup_cookie": store.authorize_setup(data.get("token", "")),
            }
        if path == "/api/recovery/request":
            account = str(data.get("account", "")).strip().lower()[:254]
            allowed_ip = store.throttle_recovery("recovery-ip:" + address, 20)
            allowed_account = store.throttle_recovery(
                "recovery-account:" + store.token_hash(account), 3
            )
            user = store.db.execute(
                "SELECT * FROM users WHERE (username=? OR (email<>'' AND email=?)) AND active=1",
                (account, account),
            ).fetchone()
            if (
                allowed_ip
                and allowed_account
                and user
                and user["email"]
                and self.mailer.config()["enabled"]
            ):
                secret = store.recovery_token(user["id"])
                url = (
                    self.running_settings["public_url"].rstrip("/")
                    + "/#reset="
                    + secret
                )
                self.enqueue_mail(
                    user["email"],
                    "Aether Studio account recovery",
                    f"Hello {user['full_name'] or user['username']},\n\nYour Aether Studio username is {user['username']}.\n\nTo choose a new password, open this link within 30 minutes:\n{url}\n\nThis link works once. If you did not request it, you can ignore this email. Your password has not changed.\n",
                    "account_recovery",
                )
            return {
                "ok": True,
                "message": "If that account has an email address and delivery is configured, a recovery link will be sent. Check your inbox and spam folder.",
            }
        if path == "/api/recovery/reset":
            if not store.throttle_recovery("reset-ip:" + address, 20):
                raise Problem(429, "Too many attempts. Try again in 15 minutes.")
            user = store.recover_password(data.get("token", ""), data.get("password"))
            if self.mailer.config()["enabled"]:
                self.enqueue_mail(
                    user["email"],
                    "Your Aether Studio password changed",
                    "Your password was changed using a recovery link. All existing sign-ins have been revoked. If this was not you, contact your server administrator.",
                    "password_changed",
                )
            return {"ok": True, "_cookie": ""}
        if path == "/api/setup":
            if store.ready():
                raise Problem(409, "This server is already configured.")
            if not store.setup_authorized(setup_token) and not secrets.compare_digest(
                str(data.get("token", "")), store.setup_path.read_text().strip()
            ):
                raise Problem(
                    403, "Open the local setup link to claim this installation."
                )
            full_name, email = identity(data.get("full_name"), data.get("email"))
            name = data.get("name", "Aether Studio")
            selected = data.get(
                "apps",
                [
                    key
                    for key, package in self.packages.items()
                    if (package[2] / "index.html").is_file()
                ],
            )
            if not isinstance(name, str) or not 1 <= len(name.strip()) <= 80:
                raise Problem(400, "Workspace name must be 1–80 characters.")
            if not isinstance(selected, list) or any(
                not isinstance(app, str)
                or app not in self.packages
                or not (self.packages[app][2] / "index.html").is_file()
                for app in selected
            ):
                raise Problem(400, "Choose only installed applications.")
            with store.db:
                store.create_user(
                    data.get("username"),
                    data.get("password"),
                    "admin",
                    False,
                    commit=False,
                    full_name=full_name,
                    email=email,
                )
                store.db.execute(
                    "UPDATE settings SET value=? WHERE key='name'",
                    (json.dumps(name.strip()),),
                )
                for app in self.packages:
                    store.db.execute(
                        "UPDATE applications SET enabled=? WHERE id=?",
                        (int(app in selected), app),
                    )
            self.running_settings["name"] = name.strip()
            store.audit(data["username"], "server_setup")
            store.setup_path.unlink(missing_ok=True)
            store.db.execute("DELETE FROM setup_sessions")
            store.db.commit()
            return {"ok": True, "_setup_cookie": ""}
        if path == "/api/login":
            new_token = store.sign_in(
                data.get("username", ""), data.get("password", ""), address
            )
            return {"ok": True, "_cookie": new_token}
        user = self.require_user(
            token, allow_change=path in ("/api/logout", "/api/password")
        )
        uid = user["id"]
        if user["role"] == "service" and path.startswith("/api/"):
            raise Problem(
                403, "Service tokens can only call their scoped application APIs."
            )
        if path == "/api/logout":
            store.db.execute(
                "DELETE FROM sessions WHERE token=?", (store.token_hash(token),)
            )
            store.audit(user["username"], "sign_out")
            return {"ok": True, "_cookie": ""}
        if path.startswith("/api/library/"):
            if user["role"] == "service":
                raise Problem(403, "Sign in with a user account to open the library.")
            self.require_app(data.get("app"), user)
            return self.library.dispatch(path.rsplit("/", 1)[-1], user, data)
        if path == "/api/preferences":
            if user["role"] == "service":
                raise Problem(403, "User account required.")
            theme = data.get("theme", user["theme"])
            avatar = data.get("avatar", user["avatar"])
            theme_id = data.get("theme_id", user.get("theme_id", ""))
            if theme not in ("dark", "light", "system"):
                raise Problem(400, "Choose dark, light or system appearance.")
            if not isinstance(theme_id, str) or len(theme_id) > 64:
                raise Problem(400, "Choose a valid theme.")
            if not isinstance(avatar, str) or len(avatar) > 350000:
                raise Problem(400, "Choose a profile picture smaller than 256 KB.")
            if avatar:
                import base64
                import binascii

                try:
                    prefix, content = avatar.split(",", 1)
                    raw = base64.b64decode(content, validate=True)
                    valid = (
                        prefix == "data:image/png;base64"
                        and raw.startswith(b"\x89PNG\r\n\x1a\n")
                    ) or (
                        prefix == "data:image/jpeg;base64"
                        and raw.startswith(b"\xff\xd8\xff")
                    )
                    if not valid or len(raw) > 262144:
                        raise ValueError()
                except (ValueError, binascii.Error):
                    raise Problem(
                        400, "Choose a PNG or JPEG profile picture under 256 KB."
                    ) from None
            store.db.execute(
                "UPDATE users SET theme=?,avatar=?,theme_id=? WHERE id=?",
                (theme, avatar, theme_id.strip(), uid),
            )
            store.audit(user["username"], "preferences_updated")
            return {"ok": True}
        if path == "/api/profile":
            full_name, email = identity(data.get("full_name"), data.get("email"))
            row = store.db.execute(
                "SELECT password FROM users WHERE id=?", (uid,)
            ).fetchone()
            if not password_matches(data.get("current_password", ""), row[0]):
                raise Problem(
                    400, "Enter your current password to update account details."
                )
            store.update_identity(uid, full_name, email)
            store.audit(user["username"], "profile_updated")
            return {"ok": True}
        if path == "/api/password":
            row = store.db.execute(
                "SELECT password FROM users WHERE id=?", (uid,)
            ).fetchone()
            if not password_matches(data.get("current_password", ""), row[0]):
                raise Problem(400, "Current password is incorrect.")
            store.reset_password(uid, data.get("password"), False)
            store.audit(user["username"], "password_changed")
            return {"ok": True, "_cookie": ""}
        if path.startswith("/api/admin/"):
            self.require_user(token, admin=True)
            if path == "/api/admin/mail":
                self.mailer.save(data)
                store.audit(user["username"], "email_settings_saved")
                return {"ok": True}
            if path == "/api/admin/mail/test":
                if not user["email"]:
                    raise Problem(400, "Add your email address in My account first.")
                if not self.mailer.config()["enabled"]:
                    raise Problem(400, "Save and enable email delivery first.")
                if not store.throttle_recovery("mail-test:" + uid, 3):
                    raise Problem(429, "Please wait before sending another test email.")
                if not self.enqueue_mail(
                    user["email"],
                    "Aether Studio email test",
                    "This is a test message from your Aether Studio host. Email delivery is working.",
                    "admin_test",
                ):
                    raise Problem(503, "The email queue is full. Try again shortly.")
                return {"ok": True}
            if path == "/api/admin/backup":
                name = self.backup()
                store.audit(user["username"], "backup_created", name)
                return {"ok": True, "name": name}
            if path == "/api/admin/team":
                team_id = data.get("id") or secrets.token_hex(16)
                if data.get("action") == "delete":
                    store.db.execute("DELETE FROM teams WHERE id=?", (team_id,))
                else:
                    name, members, apps = (
                        data.get("name"),
                        data.get("members"),
                        data.get("apps"),
                    )
                    known_users = {u["id"] for u in store.users()}
                    if (
                        not isinstance(name, str)
                        or not 1 <= len(name.strip()) <= 80
                        or not isinstance(members, list)
                        or not isinstance(apps, list)
                        or any(
                            not isinstance(i, str) or i not in known_users
                            for i in members
                        )
                        or any(i not in ("cad", "animation") for i in apps)
                    ):
                        raise Problem(
                            400, "Choose a team name, valid members and applications."
                        )
                    try:
                        store.db.execute(
                            "INSERT INTO teams VALUES (?,?,?,?) ON CONFLICT(id) DO UPDATE SET name=excluded.name,members=excluded.members,apps=excluded.apps",
                            (
                                team_id,
                                name.strip(),
                                json.dumps(members),
                                json.dumps(apps),
                            ),
                        )
                    except sqlite3.IntegrityError:
                        store.db.rollback()
                        raise Problem(409, "That team name already exists.") from None
                store.audit(
                    user["username"],
                    "team_"
                    + ("deleted" if data.get("action") == "delete" else "saved"),
                    team_id,
                )
                return {"ok": True}
            if path == "/api/admin/access":
                if (
                    data.get("id") not in ("cad", "animation")
                    or type(data.get("restricted")) is not bool
                ):
                    raise Problem(400, "Invalid application access policy.")
                store.db.execute(
                    "UPDATE app_access SET restricted=? WHERE id=?",
                    (int(data["restricted"]), data["id"]),
                )
                store.audit(user["username"], "app_access_changed", data["id"])
                return {"ok": True}
            if path == "/api/admin/theme":
                base = data.get("base")
                apps = data.get("apps", {})
                if not isinstance(base, str) or not base.strip() or len(base) > 64:
                    raise Problem(400, "Choose a base theme id.")
                if not isinstance(apps, dict) or any(
                    key not in ("studio", "cad", "animation", "ui")
                    or not isinstance(value, str)
                    or len(value) > 64
                    for key, value in apps.items()
                ):
                    raise Problem(400, "Invalid per-application theme overrides.")
                store.db.execute(
                    "UPDATE settings SET value=? WHERE key='theme'",
                    (
                        json.dumps(
                            {
                                "base": base.strip(),
                                "apps": {
                                    key: value.strip()
                                    for key, value in apps.items()
                                    if value.strip()
                                },
                            }
                        ),
                    ),
                )
                store.audit(user["username"], "theme_changed", base.strip())
                return {"ok": True}
            if path == "/api/admin/service":
                if data.get("action") == "revoke":
                    store.db.execute(
                        "UPDATE services SET active=0,token='' WHERE id=?",
                        (data.get("id"),),
                    )
                    store.audit(
                        user["username"], "service_revoked", str(data.get("id"))
                    )
                    return {"ok": True}
                name, apps, days = data.get("name"), data.get("apps"), data.get("days")
                if (
                    not isinstance(name, str)
                    or not 1 <= len(name.strip()) <= 80
                    or not isinstance(apps, list)
                    or not apps
                    or any(i not in ("cad", "animation") for i in apps)
                    or type(days) is not int
                    or not 1 <= days <= 365
                ):
                    raise Problem(
                        400,
                        "Choose a name, application scopes and expiration of 1–365 days.",
                    )
                secret = "aether_sa_" + secrets.token_urlsafe(32)
                try:
                    store.db.execute(
                        "INSERT INTO services VALUES (?,?,?,?,?,1)",
                        (
                            secrets.token_hex(16),
                            name.strip(),
                            store.token_hash(secret),
                            json.dumps(apps),
                            time.time() + days * 86400,
                        ),
                    )
                except sqlite3.IntegrityError:
                    store.db.rollback()
                    raise Problem(
                        409, "That service account name already exists."
                    ) from None
                store.audit(user["username"], "service_created", name)
                return {"ok": True, "token": secret}
            if path == "/api/admin/users":
                full_name, email = identity(data.get("full_name"), data.get("email"))
                target = store.create_user(
                    data.get("username"),
                    data.get("password"),
                    data.get("role", "member"),
                    full_name=full_name,
                    email=email,
                )
                store.audit(user["username"], "user_created", target)
                return {"ok": True}
            if path == "/api/admin/user":
                target = store.db.execute(
                    "SELECT * FROM users WHERE id=?", (data.get("id"),)
                ).fetchone()
                if not target:
                    raise Problem(404, "User was not found.")
                action = data.get("action")
                if action == "identity":
                    full_name, email = identity(
                        data.get("full_name"), data.get("email")
                    )
                    store.update_identity(target["id"], full_name, email)
                elif action == "update":
                    role, active = data.get("role"), data.get("active")
                    if role not in ("admin", "member") or type(active) is not bool:
                        raise Problem(400, "Invalid role or account state.")
                    if target["id"] == uid and (role != "admin" or not active):
                        raise Problem(
                            409,
                            "You cannot disable or demote your own administrator account.",
                        )
                    count = store.db.execute(
                        "SELECT count(*) FROM users WHERE active=1 AND role='admin'"
                    ).fetchone()[0]
                    if (
                        target["role"] == "admin"
                        and target["active"]
                        and count <= 1
                        and (not active or role != "admin")
                    ):
                        raise Problem(409, "Keep at least one active administrator.")
                    store.db.execute(
                        "UPDATE users SET role=?,active=? WHERE id=?",
                        (role, int(active), target["id"]),
                    )
                    store.revoke(target["id"])
                elif action == "reset_password":
                    if target["id"] == uid:
                        raise Problem(
                            400, "Use your Account page to change your own password."
                        )
                    store.reset_password(target["id"], data.get("password"))
                elif action == "revoke_sessions":
                    store.revoke(target["id"])
                else:
                    raise Problem(400, "Unknown user action.")
                store.audit(user["username"], action, target["username"])
                return {"ok": True}
            if path == "/api/admin/apps":
                if (
                    data.get("id") not in self.packages
                    or type(data.get("enabled")) is not bool
                ):
                    raise Problem(400, "Invalid application setting.")
                store.db.execute(
                    "UPDATE applications SET enabled=? WHERE id=?",
                    (int(data["enabled"]), data["id"]),
                )
                store.audit(
                    user["username"],
                    "app_enabled" if data["enabled"] else "app_disabled",
                    data["id"],
                )
                return {"ok": True}
            if path == "/api/admin/settings":
                validate_settings(data)
                if (data["bind_address"], data["port"]) != (
                    self.running_settings["bind_address"],
                    self.running_settings["port"],
                ):
                    try:
                        with socket.socket() as probe:
                            probe.bind(
                                (
                                    data["bind_address"],
                                    data["port"]
                                    if data["port"] != self.running_settings["port"]
                                    else 0,
                                )
                            )
                    except OSError:
                        raise Problem(
                            409,
                            "The requested address or port is unavailable on this host.",
                        ) from None
                for key, value in data.items():
                    store.db.execute(
                        "UPDATE settings SET value=? WHERE key=?",
                        (json.dumps(value), key),
                    )
                store.audit(user["username"], "server_settings_saved")
                return {"ok": True, "restart_required": data != self.running_settings}
            if path == "/api/admin/restart":
                validate_settings(store.settings())
                store.audit(user["username"], "server_restart")
                self.restart_requested = True
                if self.server:
                    threading.Timer(0.5, self.server.shutdown).start()
                return {"ok": True, "url": store.settings()["public_url"]}
        app, _, route = path.lstrip("/").partition("/")
        self.require_app(app, user)
        root = self.root_for(uid)
        if route == "rpc":
            if data.get("method") == "shutdown":
                raise Problem(403, "Engine shutdown is managed by the host.")
            # A login owns its engine handles; users and application packages cannot collide.
            key = (store.token_hash(token), app)
            if key not in self.engines:
                live = {
                    r[0]
                    for r in store.db.execute(
                        "SELECT token FROM sessions WHERE expires>? UNION SELECT token FROM services WHERE expires>? AND active=1",
                        (time.time(), time.time()),
                    )
                }
                self.engines = {k: v for k, v in self.engines.items() if k[0] in live}
                self.engines[key] = Session(workspace_root=root)
            return handle_request(self.engines[key], data)
        if route == "files/save":
            if not isinstance(data.get("path"), str) or not isinstance(
                data.get("text"), str
            ):
                raise Problem(400, "A workspace path and text are required.")
            target = safe_path(root, data["path"])
            previous = (
                hashlib.sha256(target.read_bytes()).hexdigest()
                if target.is_file()
                else None
            )
            if data.get("expected_revision") != previous:
                raise Problem(409, "This file changed. Reopen it before saving.")
            target.parent.mkdir(parents=True, exist_ok=True)
            temporary = target.with_name(
                target.name + "." + secrets.token_hex(8) + ".tmp"
            )
            try:
                temporary.write_text(data["text"])
                os.replace(temporary, target)
            finally:
                temporary.unlink(missing_ok=True)
            return {
                "ok": True,
                "revision": hashlib.sha256(target.read_bytes()).hexdigest(),
            }
        raise Problem(404, "Unknown endpoint.")

    def require_app(self, app, user):
        if app not in self.packages:
            raise Problem(404, "Application not found.")
        if not self.app_allowed(app, user):
            raise Problem(403, "Your account does not have access to this application.")
        if not self.store.db.execute(
            "SELECT enabled FROM applications WHERE id=?", (app,)
        ).fetchone()[0]:
            raise Problem(403, "This application is disabled by an administrator.")


def make_handler(host):
    class Handler(BaseHTTPRequestHandler):
        def setup(self):
            super().setup()
            self.connection.settimeout(15)

        def log_message(self, *_args):
            pass  # Never log credentials, setup URLs, or tokens.

        def reply(self, status, data, mime="application/json", headers=None):
            body = json.dumps(data).encode() if isinstance(data, dict) else data
            self.send_response(status)
            self.send_header("Content-Type", mime)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.send_header("Referrer-Policy", "no-referrer")
            self.send_header("X-Frame-Options", "SAMEORIGIN")
            for key, value in (headers or {}).items():
                self.send_header(key, value)
            self.end_headers()
            self.wfile.write(body)

        def context(self):
            public = urlsplit(host.running_settings["public_url"])
            authority = self.headers.get("Host", "")
            parsed = urlsplit("//" + authority)
            if (
                parsed.hostname not in {"localhost", "127.0.0.1", public.hostname}
                or parsed.username
                or parsed.password
            ):
                raise Problem(403, "Unrecognized host name.")
            origin = f"{public.scheme}://{authority}"
            cookie = SimpleCookie()
            try:
                cookie.load(self.headers.get("Cookie", ""))
            except Exception:
                pass
            token = cookie["aether_session"].value if "aether_session" in cookie else ""
            authorization = self.headers.get("Authorization", "")
            if authorization.startswith("Bearer "):
                token = authorization[7:]
                if not token.startswith("aether_sa_"):
                    raise Problem(
                        401,
                        "Only service-account tokens support Bearer authentication.",
                    )
            return origin, token

        def setup_cookie(self):
            cookie = SimpleCookie()
            try:
                cookie.load(self.headers.get("Cookie", ""))
                return cookie["aether_setup"].value if "aether_setup" in cookie else ""
            except Exception:
                return ""

        def do_POST(self):  # noqa: N802
            with host.lock:
                try:
                    origin, token = self.context()
                    if (
                        self.headers.get("Origin") != origin
                        and not self.headers.get("Authorization", "").startswith(
                            "Bearer aether_sa_"
                        )
                    ) or self.headers.get_content_type() != "application/json":
                        raise Problem(403, "A same-origin JSON request is required.")
                    try:
                        length = int(self.headers.get("Content-Length", "0"))
                    except ValueError:
                        raise Problem(400, "Invalid content length.") from None
                    limit_mb = (
                        9 if urlsplit(self.path).path.startswith("/api/library/") else 8
                    )
                    if not 0 < length <= limit_mb * 1024 * 1024:
                        raise Problem(
                            413, f"Request must be between 1 byte and {limit_mb} MB."
                        )
                    try:
                        data = json.loads(self.rfile.read(length))
                    except (ValueError, UnicodeDecodeError):
                        raise Problem(400, "Invalid JSON.") from None
                    if not isinstance(data, dict):
                        raise Problem(400, "Expected a JSON object.")
                    result = host.dispatch(
                        urlsplit(self.path).path,
                        data,
                        token,
                        self.client_address[0],
                        self.setup_cookie(),
                    )
                    headers = {}
                    if "_setup_cookie" in result:
                        value = result.pop("_setup_cookie")
                        secure = "; Secure" if origin.startswith("https:") else ""
                        headers["Set-Cookie"] = (
                            f"aether_setup={value}; Path=/; HttpOnly; SameSite=Strict; Max-Age={3600 if value else 0}{secure}"
                        )
                    if "_cookie" in result:
                        value = result.pop("_cookie")
                        secure = "; Secure" if origin.startswith("https:") else ""
                        headers["Set-Cookie"] = (
                            f"aether_session={value}; Path=/; HttpOnly; SameSite=Strict; Max-Age={43200 if value else 0}{secure}"
                        )
                    self.reply(200, result, headers=headers)
                except Problem as error:
                    self.reply(error.status, {"error": error.message})
                except Exception:
                    host.store.db.rollback()
                    self.reply(
                        500,
                        {
                            "error": "The request failed. No credentials are included in host logs."
                        },
                    )

        def do_GET(self):  # noqa: N802
            fast_path = unquote(urlsplit(self.path).path)
            # Public suite assets stream without the host lock: they are hot,
            # auth-free, and must not queue behind API handlers.
            if fast_path in ("/suite/account.js", "/suite/account.css"):
                asset = REPO / "core/session" / fast_path.rsplit("/", 1)[-1]
                self.reply(
                    200,
                    asset.read_bytes(),
                    "text/javascript" if fast_path.endswith(".js") else "text/css",
                )
                return
            if fast_path.startswith("/icons/"):
                name = fast_path.rsplit("/", 1)[-1]
                if name in {
                    app + extension
                    for app in ("studio", "cad", "animation", "ui")
                    for extension in (".png", ".svg")
                }:
                    self.reply(
                        200,
                        (REPO / "core/assets/branding/apps" / name).read_bytes(),
                        "image/png" if name.endswith(".png") else "image/svg+xml",
                    )
                else:
                    self.reply(404, {"error": "Icon not found."})
                return
            static_response = None
            with host.lock:
                try:
                    _, token = self.context()
                    path = unquote(urlsplit(self.path).path)
                    if path == "/api/status":
                        user = host.store.user_for(token)
                        self.reply(
                            200,
                            {
                                "ready": host.store.ready(),
                                "name": host.store.settings()["name"],
                                "theme": host.store.settings().get(
                                    "theme", {"base": "aether-default", "apps": {}}
                                ),
                                "user": user,
                                "email_recovery_available": host.mailer.config()[
                                    "enabled"
                                ],
                                "installation": {
                                    "host_ready": True,
                                    "setup_authorized": host.store.setup_authorized(
                                        self.setup_cookie()
                                    ),
                                    "storage_ready": os.access(
                                        host.store.directory, os.W_OK
                                    ),
                                    "packages": [
                                        {
                                            "id": key,
                                            "name": package[0],
                                            "description": package[1],
                                            "installed": (
                                                package[2] / "index.html"
                                            ).is_file(),
                                        }
                                        for key, package in host.packages.items()
                                    ],
                                }
                                if not host.store.ready()
                                else None,
                                "apps": host.apps(user)
                                if user and not user["must_change"]
                                else [
                                    app
                                    for app in host.apps({"role": "admin"})
                                    if app["id"] != "ui" and app["enabled"]
                                ]
                                if user is None and host.store.ready()
                                else [],
                            },
                        )
                        return
                    if path.startswith("/api/admin/backups/"):
                        user = host.require_user(token, admin=True)
                        target = safe_path(
                            host.store.directory / "backups", path.rsplit("/", 1)[-1]
                        )
                        if not target.is_file() or target.suffix != ".zip":
                            raise Problem(404, "Backup not found.")
                        self.reply(
                            200,
                            target.read_bytes(),
                            "application/zip",
                            {
                                "Content-Disposition": f'attachment; filename="{target.name}"'
                            },
                        )
                        return
                    if path == "/api/admin/state":
                        host.require_user(token, admin=True)
                        self.reply(
                            200,
                            {
                                "users": host.store.users(),
                                "mail": host.mailer.public_config(),
                                "settings": host.store.settings(),
                                "running_settings": host.running_settings,
                                "restart_required": host.running_settings
                                != host.store.settings(),
                                "uptime_s": int(time.time() - host.started),
                                "teams": [
                                    {
                                        **dict(r),
                                        "members": json.loads(r["members"]),
                                        "apps": json.loads(r["apps"]),
                                    }
                                    for r in host.store.db.execute(
                                        "SELECT * FROM teams ORDER BY name"
                                    )
                                ],
                                "access": dict(
                                    host.store.db.execute(
                                        "SELECT id,restricted FROM app_access"
                                    )
                                ),
                                "services": [
                                    {**dict(r), "apps": json.loads(r["apps"])}
                                    for r in host.store.db.execute(
                                        "SELECT id,name,apps,expires,active FROM services ORDER BY name"
                                    )
                                ],
                                "backups": [
                                    {
                                        "name": p.name,
                                        "size": p.stat().st_size,
                                        "created": p.stat().st_mtime,
                                    }
                                    for p in sorted(
                                        (host.store.directory / "backups").glob(
                                            "*.zip"
                                        ),
                                        reverse=True,
                                    )
                                ],
                                "sessions": [
                                    dict(r)
                                    for r in host.store.db.execute(
                                        "SELECT u.username,count(*) AS count FROM sessions s JOIN users u ON u.id=s.user_id WHERE expires>? GROUP BY user_id",
                                        (time.time(),),
                                    )
                                ],
                                "audit": [
                                    dict(r)
                                    for r in host.store.db.execute(
                                        "SELECT * FROM audit ORDER BY id DESC LIMIT 100"
                                    )
                                ],
                            },
                        )
                        return
                    if path in ("/suite/account.js", "/suite/account.css"):
                        target = REPO / "core/session" / path.rsplit("/", 1)[-1]
                        self.reply(
                            200,
                            target.read_bytes(),
                            "text/javascript" if path.endswith(".js") else "text/css",
                        )
                        return
                    if path.startswith("/icons/"):
                        name = path.rsplit("/", 1)[-1]
                        if name not in {
                            app + extension
                            for app in ("studio", "cad", "animation", "ui")
                            for extension in (".png", ".svg")
                        }:
                            raise Problem(404, "Icon not found.")
                        self.reply(
                            200,
                            (REPO / "core/assets/branding/apps" / name).read_bytes(),
                            "image/png" if name.endswith(".png") else "image/svg+xml",
                        )
                        return
                    if (
                        path.endswith("/manifest.webmanifest")
                        or path == "/manifest.webmanifest"
                    ):
                        app = path.strip("/").split("/")[0]
                        name = (
                            host.packages[app][0]
                            if app in host.packages
                            else "Aether Studio"
                        )
                        start = f"/{app}/" if app in host.packages else "/"
                        self.reply(
                            200,
                            {
                                "id": start,
                                "name": name,
                                "short_name": name,
                                "start_url": start,
                                "scope": "/",
                                "display": "standalone",
                                "background_color": "#0e1013",
                                "theme_color": "#171a20",
                                "icons": [
                                    {
                                        "src": f"/icons/{app if app in host.packages else 'studio'}.png",
                                        "sizes": "1024x1024",
                                        "type": "image/png",
                                    }
                                ],
                            },
                            "application/manifest+json",
                        )
                        return
                    app, _, route = path.lstrip("/").partition("/")
                    if app in host.packages:
                        if path == f"/{app}":
                            query = urlsplit(self.path).query
                            self.reply(
                                302,
                                b"",
                                headers={
                                    "Location": f"/{app}/"
                                    + ("?" + query if query else "")
                                },
                            )
                            return
                        user = host.store.user_for(token)
                        if not user or user["must_change"]:
                            self.reply(
                                302,
                                b"",
                                headers={
                                    "Location": "/?next=" + quote(self.path, safe="")
                                },
                            )
                            return
                        host.require_app(app, user)
                        if not route and app not in ("cad", "animation"):
                            self.reply(
                                302, b"", headers={"Location": f"/{app}/index.html"}
                            )
                            return
                        if route.startswith("workspace/"):
                            target = safe_path(
                                host.root_for(user["id"]), route[len("workspace/") :]
                            )
                            if not target.is_file():
                                raise Problem(404, "Workspace file not found.")
                            body = target.read_bytes()
                            self.reply(
                                200,
                                body,
                                "application/octet-stream",
                                {
                                    "X-Aether-Revision": hashlib.sha256(
                                        body
                                    ).hexdigest(),
                                    "Content-Disposition": "attachment",
                                },
                            )
                            return
                        else:
                            target = (
                                (REPO / "studio/dist/index.html")
                                if app in ("cad", "animation") and not route
                                else safe_path(host.packages[app][2], route)
                            )
                    else:
                        target = safe_path(
                            REPO / "studio/dist", path.lstrip("/") or "index.html"
                        )
                    if not target.is_file():
                        raise Problem(
                            404,
                            "File not found. Build the application before enabling it.",
                        )
                    static_response = (target, app, route)
                except Problem as error:
                    self.reply(error.status, {"error": error.message})
                    return
                except Exception:
                    self.reply(500, {"error": "Unable to load this resource."})
                    return
            # App files stream OUTSIDE the host lock: multi-megabyte bundles
            # must not serialize every other request (200-user readiness).
            # Routing and auth above are unchanged.
            if static_response is None:
                return
            target, app, route = static_response
            try:
                body = target.read_bytes()
                if target.name == "index.html":
                    icon = app if app in host.packages else "studio"
                    metadata = f'<link rel="manifest" href="manifest.webmanifest"><link rel="icon" href="/icons/{icon}.svg"><link rel="apple-touch-icon" href="/icons/{icon}.png"><meta name="theme-color" content="#171a20"></head>'
                    metadata = metadata.replace(
                        "</head>",
                        '<link rel="stylesheet" href="/suite/account.css"><script type="module" src="/suite/account.js"></script></head>',
                    )
                    if app in ("cad", "animation") and not route:
                        body = body.replace(
                            b"<title>Aether Studio</title>",
                            b"<title>Aether CAD</title>",
                        )
                    body = body.replace(b"</head>", metadata.encode())
                self.reply(
                    200,
                    body,
                    mimetypes.guess_type(target)[0] or "application/octet-stream",
                    {"X-Aether-Revision": hashlib.sha256(body).hexdigest()},
                )
            except Exception:
                self.reply(500, {"error": "Unable to load this resource."})

    return Handler


def serve(directory):
    previous = None
    while True:
        host = StudioHost(directory)
        settings = host.running_settings

        def bind(config):
            validate_settings(config)
            server = ThreadingHTTPServer(
                (config["bind_address"], config["port"]), make_handler(host)
            )
            server.daemon_threads = True
            try:
                if config["tls_cert"]:
                    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
                    context.load_cert_chain(config["tls_cert"], config["tls_key"])
                    server.socket = context.wrap_socket(server.socket, server_side=True)
            except Exception:
                server.server_close()
                raise
            return server

        try:
            server = bind(settings)
        except (OSError, Problem):
            if previous is None:
                raise
            # Keep the previous reachable listener when applying settings fails.
            host.running_settings = previous
            settings = previous
            server = bind(previous)
            host.store.audit(
                "host", "network_apply_failed", "Previous connection restored"
            )
        host.server = server
        try:
            server.serve_forever()
        finally:
            server.server_close()
        if not host.restart_requested:
            break
        previous = settings
