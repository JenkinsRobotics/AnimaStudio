"""Run, open, or recover the local Aether Studio installation."""

import argparse
import getpass
import sys
import webbrowser
import time
import urllib.request
from pathlib import Path

from core.host.server import serve
from core.host.state import Store


def default_directory():
    if sys.platform == "darwin":
        return Path.home() / "Library/Application Support/Aether Studio"
    return Path.home() / ".local/share/aether-studio"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "command",
        choices=["serve", "open", "reset-password", "restore"],
        nargs="?",
        default="serve",
    )
    parser.add_argument("--data", type=Path, default=default_directory())
    parser.add_argument("--username")
    parser.add_argument(
        "--app", choices=["studio", "cad", "animation", "ui"], default="studio"
    )
    parser.add_argument("--archive", type=Path)
    args = parser.parse_args()
    if args.command == "restore":
        from core.host.backup import restore

        if not args.archive:
            parser.error("--archive is required")
        restore(args.archive, args.data)
        print(
            "Restored. Network settings reset to local-only; sign-in sessions and service tokens revoked."
        )
        return
    if args.command == "serve":
        serve(args.data)
        return
    store = Store(args.data)
    if args.command == "open":
        url = store.settings()["public_url"] + "/"
        if not store.ready():
            url += "#setup=" + store.setup_path.read_text().strip()
        elif args.app != "studio":
            url += args.app + "/"
        for _ in range(30):
            try:
                urllib.request.urlopen(
                    store.settings()["public_url"] + "/api/status", timeout=1
                ).close()
                break
            except Exception:
                time.sleep(0.2)
        webbrowser.open(url)
    else:
        username = args.username or input("Username: ")
        user = store.db.execute(
            "SELECT id FROM users WHERE username=?", (username.lower(),)
        ).fetchone()
        if not user:
            parser.error("User not found")
        password = getpass.getpass("New password (12+ characters): ")
        if password != getpass.getpass("Repeat password: "):
            parser.error("Passwords do not match")
        store.reset_password(user[0], password, False)
        store.audit("local-console", "password_recovery", username)
        print("Password changed and all existing sessions revoked.")


if __name__ == "__main__":
    main()
