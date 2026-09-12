"""Immutable, content-addressed saved revisions and named versions."""

import base64
import hashlib
import time

from .state import Problem


class History:
    def __init__(self, store):
        self.store, self.db = store, store.db
        self.db.executescript("""
            CREATE TABLE IF NOT EXISTS library_blobs (hash TEXT PRIMARY KEY, content BLOB NOT NULL);
            CREATE TABLE IF NOT EXISTS library_history (
                file_id TEXT NOT NULL REFERENCES library(id), revision INTEGER NOT NULL,
                blob_hash TEXT NOT NULL REFERENCES library_blobs(hash), name TEXT NOT NULL,
                author TEXT NOT NULL REFERENCES users(id), saved REAL NOT NULL,
                event TEXT NOT NULL, note TEXT NOT NULL DEFAULT '', PRIMARY KEY(file_id,revision));
            CREATE TABLE IF NOT EXISTS library_versions (
                file_id TEXT NOT NULL REFERENCES library(id), name TEXT NOT NULL,
                revision INTEGER NOT NULL, author TEXT NOT NULL REFERENCES users(id), created REAL NOT NULL,
                PRIMARY KEY(file_id,name), FOREIGN KEY(file_id,revision) REFERENCES library_history(file_id,revision));
            CREATE TABLE IF NOT EXISTS library_branches (
                file_id TEXT NOT NULL REFERENCES library(id), name TEXT NOT NULL,
                head_revision INTEGER NOT NULL, created_from INTEGER NOT NULL,
                author TEXT NOT NULL REFERENCES users(id), created REAL NOT NULL,
                PRIMARY KEY(file_id,name));
        """)
        history_columns = {row[1] for row in self.db.execute("PRAGMA table_info(library_history)")}
        if "branch" not in history_columns:
            self.db.execute("ALTER TABLE library_history ADD COLUMN branch TEXT NOT NULL DEFAULT 'Main'")
        if "parent_revision" not in history_columns:
            self.db.execute("ALTER TABLE library_history ADD COLUMN parent_revision INTEGER")
        version_columns = {row[1] for row in self.db.execute("PRAGMA table_info(library_versions)")}
        if "message" not in version_columns:
            self.db.execute("ALTER TABLE library_versions ADD COLUMN message TEXT NOT NULL DEFAULT ''")
        for row in self.db.execute(
            "SELECT * FROM library WHERE kind IN ('file','project') AND NOT EXISTS (SELECT 1 FROM library_history h WHERE h.file_id=library.id)"
        ).fetchall():
            self.record(
                row,
                row["owner"],
                "baseline",
                "History begins with the file retained when history support was installed.",
            )
        self.db.commit()

    def record(self, row, author, event, note="", branch="Main", parent=None, revision=None, content=None):
        content = (row["content"] if content is None else content) or b""
        digest = hashlib.sha256(content).hexdigest()
        self.db.execute(
            "INSERT OR IGNORE INTO library_blobs VALUES (?,?)", (digest, content)
        )
        self.db.execute(
            "INSERT INTO library_history(file_id,revision,blob_hash,name,author,saved,event,note,branch,parent_revision) VALUES (?,?,?,?,?,?,?,?,?,?)",
            (
                row["id"],
                row["revision"] if revision is None else revision,
                digest,
                row["name"],
                author,
                time.time(),
                event,
                str(note)[:500],
                branch,
                parent,
            ),
        )

    def branch_heads(self, file_id, main_head):
        branches = [
            dict(r)
            for r in self.db.execute(
                "SELECT name,head_revision,created_from,created FROM library_branches WHERE file_id=? ORDER BY created",
                (file_id,),
            )
        ]
        return [{"name": "Main", "head_revision": main_head, "created_from": None, "created": None}, *branches]

    def revision(self, file_id, revision):
        row = self.db.execute(
            "SELECT h.*,b.content FROM library_history h JOIN library_blobs b ON b.hash=h.blob_hash WHERE file_id=? AND revision=?",
            (file_id, revision),
        ).fetchone()
        if not row:
            raise Problem(404, "Saved revision not found.")
        return row

    def dispatch(self, action, user, row, data):
        file_id = row["id"]
        if row["kind"] == "folder":
            raise Problem(400, "Select a document to view its history.")
        if action == "history":
            return {
                "revisions": [
                    dict(r)
                    for r in self.db.execute(
                        "SELECT h.revision,h.name,h.saved,h.event,h.note,h.blob_hash,h.branch,h.parent_revision,COALESCE(NULLIF(u.full_name,''),u.username) AS author FROM library_history h JOIN users u ON u.id=h.author WHERE file_id=? ORDER BY revision DESC",
                        (file_id,),
                    )
                ],
                "versions": [
                    dict(r)
                    for r in self.db.execute(
                        "SELECT name,revision,created,message FROM library_versions WHERE file_id=? ORDER BY created DESC",
                        (file_id,),
                    )
                ],
                "branches": self.branch_heads(file_id, row["revision"]),
            }
        if action == "read_revision":
            old = self.revision(file_id, data.get("revision"))
            return {
                "id": file_id,
                "name": old["name"],
                "revision": old["revision"],
                "data_base64": base64.b64encode(old["content"]).decode(),
                "writable": False,
            }
        if row["owner"] != user["id"]:
            raise Problem(403, "Only the document owner can restore or name versions.")
        if data.get("expected_revision") != row["revision"]:
            raise Problem(
                409, "The document changed. Refresh its history before continuing."
            )
        if action == "version":
            from animacore.cad_document import CADDocument
            try:
                managed = CADDocument(row["content"]).settings["revisionManaged"]
            except (ValueError, TypeError):
                managed = True  # Non-CAD library files retain their existing policy.
            if not managed:
                raise Problem(400, "Named revision management is disabled for this document. Saved history is still retained.")
            name = data.get("name", "")
            if not isinstance(name, str) or not 1 <= len(name.strip()) <= 80:
                raise Problem(400, "Use a version name of 1–80 characters.")
            if self.db.execute(
                "SELECT 1 FROM library_versions WHERE file_id=? AND name=?",
                (file_id, name.strip()),
            ).fetchone():
                raise Problem(409, "That version name is already in use.")
            message = data.get("message", "")
            if not isinstance(message, str) or len(message) > 500:
                raise Problem(400, "Use a commit message up to 500 characters.")
            self.db.execute(
                "INSERT INTO library_versions(file_id,name,revision,author,created,message) VALUES (?,?,?,?,?,?)",
                (file_id, name.strip(), row["revision"], user["id"], time.time(), message.strip()),
            )
            self.store.audit(user["username"], "version_created", file_id)
            return {"ok": True, "revision": row["revision"]}
        if action == "branch_create":
            name = data.get("name", "")
            if not isinstance(name, str) or not 1 <= len(name.strip()) <= 80 or name.strip() == "Main":
                raise Problem(400, "Use a branch name of 1-80 characters (not Main).")
            if self.db.execute(
                "SELECT 1 FROM library_branches WHERE file_id=? AND name=?",
                (file_id, name.strip()),
            ).fetchone():
                raise Problem(409, "That branch name is already in use.")
            source = data.get("from_revision", row["revision"])
            self.revision(file_id, source)
            self.db.execute(
                "INSERT INTO library_branches VALUES (?,?,?,?,?,?)",
                (file_id, name.strip(), source, source, user["id"], time.time()),
            )
            self.store.audit(user["username"], "branch_created", file_id)
            return {"ok": True, "name": name.strip(), "head_revision": source}
        if action == "restore":
            old = self.revision(file_id, data.get("revision"))
            self.db.execute(
                "UPDATE library SET content=?,name=?,revision=revision+1,modified=? WHERE id=?",
                (old["content"], old["name"], time.time(), file_id),
            )
            current = self.db.execute(
                "SELECT * FROM library WHERE id=?", (file_id,)
            ).fetchone()
            self.record(
                current, user["id"], "restore", f"Restored revision {old['revision']}"
            )
            self.store.audit(user["username"], "revision_restored", file_id)
            return {"ok": True, "revision": current["revision"]}
        raise Problem(404, "Unknown history operation.")
