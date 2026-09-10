"""Administrator-configured SMTP delivery; credentials never returned to browsers."""

import json
import os
import re
import smtplib
import ssl
from email.message import EmailMessage
from pathlib import Path

from core.host.state import Problem

DEFAULT_MAIL = {
    "enabled": False,
    "host": "",
    "port": 587,
    "security": "starttls",
    "username": "",
    "password": "",
    "sender": "",
}


def identity(full_name, email):
    if (
        not isinstance(full_name, str)
        or not 1 <= len(full_name.strip()) <= 120
        or any(ord(c) < 32 for c in full_name)
    ):
        raise Problem(400, "Enter your full name (up to 120 characters).")
    if (
        not isinstance(email, str)
        or len(email) > 254
        or not re.fullmatch(
            r"[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?\.[A-Za-z]{2,63}",
            email.strip(),
        )
    ):
        raise Problem(400, "Enter a valid email address.")
    return full_name.strip(), email.strip().lower()


class Mailer:
    def __init__(self, directory: Path):
        self.path = directory / "mail.json"

    def config(self):
        return {
            **DEFAULT_MAIL,
            **(json.loads(self.path.read_text()) if self.path.exists() else {}),
        }

    def public_config(self):
        data = self.config()
        data["password_set"] = bool(data.pop("password"))
        return data

    def save(self, data):
        config = self.config()
        if set(data) - set(DEFAULT_MAIL):
            raise Problem(400, "Unknown email setting.")
        config.update({k: v for k, v in data.items() if k != "password"})
        if data.get("password"):
            config["password"] = data["password"]
        if (
            type(config["enabled"]) is not bool
            or config["security"] not in ("starttls", "tls")
            or type(config["port"]) is not int
            or not 1 <= config["port"] <= 65535
        ):
            raise Problem(400, "Choose a valid SMTP port and TLS mode.")
        if any(
            not isinstance(config[key], str)
            or len(config[key]) > 1024
            or "\n" in config[key]
            or "\r" in config[key]
            for key in ("host", "username", "password", "sender")
        ):
            raise Problem(400, "Invalid email configuration.")
        if config["enabled"]:
            if not config["host"].strip():
                raise Problem(400, "Enter the SMTP server hostname.")
            identity("Sender", config["sender"])
        temporary = self.path.with_suffix(".tmp")
        fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "w") as file:
            json.dump(config, file)
        os.replace(temporary, self.path)
        self.path.chmod(0o600)

    def send(self, recipient, subject, body):
        config = self.config()
        if not config["enabled"]:
            raise Problem(503, "Email delivery has not been configured.")
        message = EmailMessage()
        message["From"] = config["sender"]
        message["To"] = recipient
        message["Subject"] = subject
        message.set_content(body)
        context = ssl.create_default_context()
        if config["security"] == "tls":
            connection = smtplib.SMTP_SSL(
                config["host"], config["port"], timeout=12, context=context
            )
        else:
            connection = smtplib.SMTP(config["host"], config["port"], timeout=12)
        with connection:
            if config["security"] == "starttls":
                connection.starttls(context=context)
            if config["username"]:
                connection.login(config["username"], config["password"])
            connection.send_message(message)
