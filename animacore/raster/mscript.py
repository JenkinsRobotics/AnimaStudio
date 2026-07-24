"""Mscript — the sectioned timeline scripting language.

Ported from Mochi (`animation/plugin_core/mscript_engine.py` + `mochi_animations.py`,
Apache-2.0). An ``.mscript`` file is three sections::

    [Header start]
    ! a comment
    [Header end]
    [Resources start]
    K[1]: 'assets/mochi.gif'
    [Resources end]
    [Main start]
    MEDIA K[1] D[auto]
    WAIT D[0.5]
    MEDIA K[1] FG[255,0,0]
    [Main end]

``update(t)`` is the engine: it walks the Main instructions with a program
counter, honouring ``WAIT`` and per-command ``D`` durations (numeric seconds, or
``auto``/``asset`` which read a GIF/video's real length), and returns the
``Command``\\s due at time ``t``. Resource keys ``K[n]`` resolve to asset paths.

A runner then turns each ``Command`` into playback (e.g. open a media adapter on
``args['asset_path']``); ``collect_commands`` below drives the engine over a time
range for testing and headless previews.
"""

from __future__ import annotations

import re
from abc import ABC, abstractmethod
from pathlib import Path
from typing import Any, NamedTuple

_SECTION_RE = re.compile(r"^\[(Header|Resources|Main) (start|end)\]$")
_RESOURCE_RE = re.compile(r"K\[(\d+)\]:\s*'([^']+)'")
_ARG_RE = re.compile(r"([A-Z_]+)\[([^\]]*)\]")
_COLOR_KEYS = frozenset({"FG", "BG", "CLR", "CLR2"})
_VIDEO_SUFFIXES = frozenset({".mp4", ".mov", ".mkv", ".avi", ".webm"})
_GIF_SUFFIXES = frozenset({".gif", ".apng"})

__all__ = ["Command", "Script", "MscriptScript", "collect_commands"]


class Command(NamedTuple):
    """One resolved instruction for a runner to execute."""

    name: str
    args: dict[str, Any]


class Script(ABC):
    """A runnable timeline: given time ``t``, return the commands now due."""

    @abstractmethod
    def update(self, t: float) -> list[Command]:
        raise NotImplementedError


class MscriptParser:
    """Parse a ``.mscript`` file into resources + a Main instruction list."""

    def __init__(self, script_path: str) -> None:
        path = Path(script_path)
        if not path.exists():
            raise FileNotFoundError(f"mscript file not found: {script_path}")
        self.instructions: list[dict[str, Any]] = []
        self.resources: dict[int, str] = {}
        self._parse(path)

    def _parse(self, path: Path) -> None:
        section: str | None = None
        for raw in path.read_text().splitlines():
            line = raw.strip()
            if not line or line.startswith("!"):
                continue
            match = _SECTION_RE.match(line)
            if match:
                name, state = match.groups()
                section = name if state == "start" else None
                continue
            if section == "Resources":
                self._parse_resource(line)
            elif section == "Main":
                self._parse_main(line)

    def _parse_resource(self, line: str) -> None:
        match = _RESOURCE_RE.match(line)
        if match:
            self.resources[int(match.group(1))] = match.group(2)

    def _parse_main(self, line: str) -> None:
        parts = line.split(maxsplit=1)
        command = parts[0].upper()
        args_str = parts[1] if len(parts) > 1 else ""
        args: dict[str, Any] = dict(_ARG_RE.findall(args_str))
        for key in _COLOR_KEYS:
            value = args.get(key)
            if isinstance(value, str):
                try:
                    args[key] = [int(c.strip()) for c in value.split(",")]
                except ValueError:
                    pass  # leave the raw string; the runner can reject it
        self.instructions.append({"command": command, "args": args})


class MscriptScript(Script):
    """Execute a parsed ``.mscript``, honouring WAIT + per-command durations."""

    def __init__(self, path: str, asset_root: str | None = None) -> None:
        parser = MscriptParser(path)
        self._instructions = parser.instructions
        self._resources = parser.resources
        self._asset_root = Path(asset_root) if asset_root else Path(path).resolve().parent
        self._program_counter = 0
        self._wait_until = 0.0

    def update(self, t: float) -> list[Command]:
        if self._program_counter >= len(self._instructions) or t < self._wait_until:
            return []

        due: list[Command] = []
        while self._program_counter < len(self._instructions):
            instruction = self._instructions[self._program_counter]
            self._program_counter += 1
            name = instruction["command"]
            args = dict(instruction["args"])

            duration_token = args.pop("D", None)
            wait_after = self._duration_seconds(duration_token, args)
            if wait_after is None and name == "MEDIA":
                wait_after = self._auto_duration(args)

            if name == "WAIT":
                seconds = _coerce_float(duration_token)
                if seconds and seconds > 0:
                    self._wait_until = t + seconds
                return due

            if "K" in args:
                resolved = self._resolve_key(args["K"])
                if resolved is None:
                    continue  # unknown/invalid resource key -> skip
                args["asset_path"] = str(resolved)

            due.append(Command(name=name, args=args))

            if wait_after and wait_after > 0:
                self._wait_until = t + wait_after
                return due
        return due

    @property
    def finished(self) -> bool:
        return self._program_counter >= len(self._instructions)

    # ── duration resolution ───────────────────────────────────────────

    def _duration_seconds(self, token: Any, raw_args: dict) -> float | None:
        if token is None:
            return None
        seconds = _coerce_float(token)
        if seconds is not None:
            return seconds
        if str(token).strip().lower() in {"auto", "asset"}:
            return self._auto_duration(raw_args)
        return None

    def _auto_duration(self, raw_args: dict) -> float | None:
        path = self._resolve_key(raw_args.get("K"))
        if path is None:
            return None
        suffix = path.suffix.lower()
        if suffix in _VIDEO_SUFFIXES:
            return _video_duration(path)
        if suffix in _GIF_SUFFIXES:
            return _gif_duration(path)
        return None

    def _resolve_key(self, key_raw: Any) -> Path | None:
        if key_raw is None:
            return None
        try:
            key = int(key_raw)
        except (TypeError, ValueError):
            return None
        resource = self._resources.get(key)
        if not resource:
            return None
        path = Path(resource)
        if not path.is_absolute():
            path = self._asset_root / path
        return path


def collect_commands(
    script: Script, *, until: float, step: float = 0.05
) -> list[tuple[float, Command]]:
    """Drive ``script`` from 0 to ``until`` seconds, returning (t, command).

    A tiny runner for tests / headless preview: it steps the clock and gathers
    every command the engine emits, so WAIT/duration flow control is observable
    without wiring the commands to real playback.
    """
    out: list[tuple[float, Command]] = []
    t = 0.0
    while t <= until + 1e-9:
        for command in script.update(t):
            out.append((round(t, 6), command))
        t += step
    return out


def _coerce_float(value: Any) -> float | None:
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _video_duration(path: Path) -> float | None:
    try:
        import imageio_ffmpeg

        _nframes, secs = imageio_ffmpeg.count_frames_and_secs(str(path))
        return float(secs) if secs else None
    except Exception:  # noqa: BLE001 — optional dep / unreadable container
        return None


def _gif_duration(path: Path) -> float | None:
    try:
        from PIL import Image, ImageSequence

        with Image.open(str(path)) as img:
            total_ms = sum(
                int(frame.info.get("duration", 100)) for frame in ImageSequence.Iterator(img)
            )
        return total_ms / 1000.0 if total_ms > 0 else None
    except Exception:  # noqa: BLE001
        return None
