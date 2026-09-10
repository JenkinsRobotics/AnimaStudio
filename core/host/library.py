"""Host-owned file library. Product engines retain ownership of document formats."""

import base64
import binascii
import secrets
import json
import time

from .state import Problem
from .history import History

MAX_FILE_BYTES = 6 * 1024 * 1024


class Library:
    def __init__(self, store):
        self.store = store
        self.db = store.db
        self.db.executescript("""
            CREATE TABLE IF NOT EXISTS library (
                id TEXT PRIMARY KEY, owner TEXT NOT NULL REFERENCES users(id),
                app TEXT NOT NULL, scope TEXT NOT NULL, parent TEXT,
                name TEXT NOT NULL, kind TEXT NOT NULL, content BLOB,
                revision INTEGER NOT NULL DEFAULT 1, created REAL NOT NULL,
                modified REAL NOT NULL, trashed INTEGER NOT NULL DEFAULT 0);
            CREATE TABLE IF NOT EXISTS library_recents (
                user_id TEXT NOT NULL REFERENCES users(id), file_id TEXT NOT NULL REFERENCES library(id),
                opened REAL NOT NULL, PRIMARY KEY(user_id,file_id));
        """)

        self.history = History(store)

    def entry(self, uid, app, file_id, write=False):
        row = self.db.execute(
            "SELECT * FROM library WHERE id=? AND app=? AND trashed=0", (file_id, app)
        ).fetchone()
        if not row or (row["owner"] != uid and (write or row["scope"] != "workspace")):
            raise Problem(404, "File or folder not found, or access is unavailable.")
        return row

    def metadata(self, row, uid):
        owner = self.db.execute(
            "SELECT full_name,username FROM users WHERE id=?", (row["owner"],)
        ).fetchone()
        return {
            **{
                k: row[k]
                for k in (
                    "id",
                    "app",
                    "scope",
                    "parent",
                    "name",
                    "kind",
                    "revision",
                    "created",
                    "modified",
                )
            },
            "size": (row["size"] or 0)
            if "size" in row.keys()
            else len(row["content"] or b""),
            "owner": owner["full_name"] or owner["username"],
            "writable": row["owner"] == uid,
        }

    def dispatch(self, action, user, data):
        uid, app = user["id"], data["app"]
        if action == "list":
            view = data.get("view", "personal")
            if view not in ("personal", "workspace", "recent"):
                raise Problem(400, "Unknown library view.")
            parent = data.get("parent") or None
            query = str(data.get("query", "")).strip().lower()[:200]
            if parent:
                folder = self.entry(uid, app, parent)
                if folder["kind"] != "folder":
                    raise Problem(400, "Choose a folder.")
            rows = self.db.execute(
                "SELECT id,owner,app,scope,parent,name,kind,revision,created,modified,length(content) AS size FROM library WHERE app=? AND trashed=0 AND (owner=? OR scope=?) ORDER BY (kind='folder') DESC,modified DESC",
                (app, uid, "workspace"),
            ).fetchall()
            recent = dict(
                self.db.execute(
                    "SELECT file_id,opened FROM library_recents WHERE user_id=?", (uid,)
                )
            )
            visible = [
                r
                for r in rows
                if (
                    r["scope"] == view and (view != "personal" or r["owner"] == uid)
                    if view != "recent"
                    else r["id"] in recent and r["kind"] != "folder"
                )
                and (query in r["name"].lower())
                and (bool(query) or view == "recent" or r["parent"] == parent)
            ]
            if view == "recent":
                visible.sort(key=lambda r: recent[r["id"]], reverse=True)
            return {"files": [self.metadata(r, uid) for r in visible]}
        if action == "project_create":
            from animacore.aether_project import new_project, edit_project

            workspace = new_project(self.name(data.get("name")))
            packaging = data.get("packaging", "project")
            if packaging not in ("project", "assembly"):
                raise Problem(400, "Choose a project or standalone Assembly.")
            if packaging == "project":
                edit_project(workspace, "add_part", {"name": "Part 1"})
            content, _ = workspace.to_bytes()
            return self.dispatch(
                "create",
                user,
                {
                    **data,
                    "name": workspace.name
                    + (".acasm" if packaging == "assembly" else ".acad"),
                    "data_base64": base64.b64encode(content).decode(),
                },
            )
        if action == "create":
            scope = data.get("scope", "personal")
            kind = data.get("kind", "file")
            if scope not in ("personal", "workspace") or kind not in ("file", "folder"):
                raise Problem(400, "Choose a file location and type.")
            parent = data.get("parent") or None
            if parent:
                folder = self.entry(uid, app, parent, write=True)
                if folder["kind"] != "folder" or folder["scope"] != scope:
                    raise Problem(400, "Choose a folder in the same location.")
            name = self.name(data.get("name"))
            content = self.content(data) if kind == "file" else None
            file_id, now = secrets.token_hex(16), time.time()
            self.db.execute(
                "INSERT INTO library (id,owner,app,scope,parent,name,kind,content,created,modified) VALUES (?,?,?,?,?,?,?,?,?,?)",
                (file_id, uid, app, scope, parent, name, kind, content, now, now),
            )
            if kind != "folder":
                self.history.record(self.entry(uid, app, file_id), uid, "create")
            self.store.audit(user["username"], "library_created", file_id)
            return self.metadata(self.entry(uid, app, file_id), uid)
        row = self.entry(
            uid, app, data.get("id"), write=action in ("save", "rename", "share")
        )
        if action in ("cad_metadata", "cad_operation"):
            from .cad_settings import dispatch
            return dispatch(self, action, user, row, data)
        if action in ("project_read", "project_edit"):
            from animacore.aether_workspace import AetherWorkspace, AetherWorkspaceError
            from animacore.aether_project import project_projection, edit_project

            if action == "project_edit":
                row = self.entry(uid, app, row["id"], write=True)
                if data.get("expected_revision") != row["revision"]:
                    raise Problem(409, "This project changed. Reopen it before saving.")
            try:
                content = row["content"]
                if action == "project_read" and data.get("revision") is not None:
                    content = self.history.revision(row["id"], data["revision"])[
                        "content"
                    ]
                workspace = AetherWorkspace.from_bytes(content)
                if action == "project_edit":
                    if data.get("operation") in ("link_part", "update_link"):
                        source = self.entry(uid, app, data.get("source_id"))
                        snapshot = self.history.revision(
                            source["id"], data.get("source_revision")
                        )
                        try:
                            document = json.loads(snapshot["content"])
                        except (ValueError, UnicodeDecodeError):
                            raise Problem(
                                400, "Select a standalone Part file."
                            ) from None
                        if (
                            not isinstance(document, dict)
                            or document.get("format") != "aether-part"
                        ):
                            raise Problem(400, "Select a native Part file.")
                        data = {
                            **data,
                            "document": document,
                            "source_label": snapshot["name"],
                            "source_ref": f"library:{source['id']}@{snapshot['revision']}",
                        }
                    edit_project(workspace, data.get("operation"), data)
                    content, _ = workspace.to_bytes()
                    self.dispatch(
                        "save",
                        user,
                        {
                            "app": app,
                            "id": row["id"],
                            "expected_revision": row["revision"],
                            "data_base64": base64.b64encode(content).decode(),
                            "note": data.get("operation"),
                        },
                    )
                    row = self.entry(uid, app, row["id"])
            except AetherWorkspaceError as exc:
                raise Problem(400, str(exc)) from None
            return {**self.metadata(row, uid), "project": project_projection(workspace)}
        if action in ("history", "read_revision", "restore", "version"):
            return self.history.dispatch(action, user, row, data)
        if action == "read":
            if row["kind"] != "file":
                raise Problem(400, "Choose a file to open.")
            self.db.execute(
                "INSERT OR REPLACE INTO library_recents VALUES (?,?,?)",
                (uid, row["id"], time.time()),
            )
            self.db.commit()
            return {
                **self.metadata(row, uid),
                "data_base64": base64.b64encode(row["content"]).decode(),
            }
        if action in ("save", "rename", "share"):
            if data.get("expected_revision") != row["revision"]:
                raise Problem(
                    409, "This file changed. Reopen it before saving your changes."
                )
            if action == "save":
                if row["kind"] != "file":
                    raise Problem(400, "Folders cannot contain file data.")
                self.db.execute(
                    "UPDATE library SET content=? WHERE id=?",
                    (self.content(data), row["id"]),
                )
            elif action == "rename":
                self.db.execute(
                    "UPDATE library SET name=? WHERE id=?",
                    (self.name(data.get("name")), row["id"]),
                )
            else:
                scope = data.get("scope")
                if row["kind"] != "file" or scope not in ("personal", "workspace"):
                    raise Problem(
                        400, "Only individual files can change sharing location."
                    )
                self.db.execute(
                    "UPDATE library SET scope=?,parent=NULL WHERE id=?",
                    (scope, row["id"]),
                )
            self.db.execute(
                "UPDATE library SET revision=revision+1,modified=? WHERE id=?",
                (time.time(), row["id"]),
            )
            if row["kind"] != "folder":
                self.history.record(
                    self.entry(uid, app, row["id"]), uid, action, data.get("note", "")
                )
            self.store.audit(user["username"], "library_" + action, row["id"])
            return self.metadata(self.entry(uid, app, row["id"]), uid)
        if action == "copy":
            if row["kind"] != "file":
                raise Problem(400, "Choose a file to copy.")
            return self.dispatch(
                "create",
                user,
                {
                    "app": app,
                    "name": "Copy of " + row["name"],
                    "scope": "personal",
                    "data_base64": base64.b64encode(row["content"]).decode(),
                },
            )
        raise Problem(404, "Unknown library operation.")

    @staticmethod
    def name(value):
        if (
            not isinstance(value, str)
            or not 1 <= len(value.strip()) <= 180
            or any(ord(c) < 32 or c in "/\\" for c in value)
        ):
            raise Problem(400, "Use a name of 1–180 characters without slashes.")
        return value.strip()

    @staticmethod
    def content(data):
        try:
            value = data["data_base64"]
            if not isinstance(value, str) or len(value) > MAX_FILE_BYTES * 4 // 3 + 4:
                raise ValueError()
            content = base64.b64decode(value, validate=True)
            if len(content) > MAX_FILE_BYTES:
                raise ValueError()
            return content
        except (KeyError, ValueError, binascii.Error):
            raise Problem(400, "Choose a file up to 6 MB with valid content.") from None
