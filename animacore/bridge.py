"""Studio ↔ AnimaCore bridge: the stdio helper that makes AnimaCore the
single canonical engine and the Swift app a front end.

Newline-delimited JSON over the helper's stdio (``python -m
animacore.bridge``). The app spawns the helper once and keeps it alive
for the session; every rig/pose/frame *meaning* is answered here, never
reimplemented in Swift. Protocol: ``dev/docs/roadmap/Studio_Bridge.md``.

The protocol logic is a pure ``handle_request(session, request) ->
response`` over parsed dicts, so it is unit-testable without real stdio;
``main`` is the thin newline-JSON loop around it. A protocol or format
error is reported as an ``{ok: false, error: {...}}`` envelope — the
loop never crashes on bad input; only a truly unexpected error
propagates.
"""

from __future__ import annotations

import json
import sys
from dataclasses import dataclass, field
from typing import IO

from animacore import __version__ as ENGINE_VERSION
from animacore.loader import CharacterFormatError, parse_character
from animacore.mates import all_mate_type_schemas, describe_mate
from animacore.rig import (
    LimitViolationError,
    Rig,
    evaluate_pose,
    project_channels,
)

PROTOCOL_VERSION = 1
ENGINE_NAME = "animacore"

# The BR1 vertical-slice verbs — also the ``hello`` capabilities list.
CAPABILITIES = [
    "hello",
    "load_character",
    "validate_character",
    "evaluate",
    "mate_types",
    "release",
    "shutdown",
]


@dataclass
class Session:
    """Long-lived helper state: rigs loaded by deterministic handle.

    Handles are ``"rig1"``, ``"rig2"``, … from a monotonic counter — no
    randomness/uuid, so a client transcript is reproducible. ``exit`` is
    set by ``shutdown`` and read by the stdio loop.
    """

    _rigs: dict[str, Rig] = field(default_factory=dict)
    _counter: int = 0
    exit: bool = False

    def add(self, rig: Rig) -> str:
        self._counter += 1
        handle = f"rig{self._counter}"
        self._rigs[handle] = rig
        return handle

    def get(self, handle: str) -> Rig | None:
        return self._rigs.get(handle)

    def drop(self, handle: str) -> bool:
        return self._rigs.pop(handle, None) is not None


# Envelope helpers ------------------------------------------------------------


def _ok(request_id: object, result: dict) -> dict:
    return {"id": request_id, "ok": True, "result": result}


def _error(
    request_id: object, code: str, message: str, path: str | None = None
) -> dict:
    return {
        "id": request_id,
        "ok": False,
        "error": {"code": code, "message": message, "path": path},
    }


class _BadRequest(Exception):
    """A malformed/mistyped request field; becomes a ``bad_request``."""


def _require_str(params: dict, key: str) -> str:
    value = params.get(key)
    if not isinstance(value, str):
        raise _BadRequest(f"{key!r} must be a string")
    return value


# Rig → summary DTOs (what Swift mirrors, never redefines) --------------------


def _rig_summary(rig: Rig) -> dict:
    """The ``load_character`` result's ``rig`` block (spec shapes).

    Each joint entry is ``describe_mate(joint)`` — the consistent
    per-mate hook carrying the stable id, the full universal controls,
    and the DOF paths + limits (``min``/``max`` null for an unlimited
    DOF).
    """
    identity = rig.identity
    joints = [describe_mate(joint) for joint in rig.joints.values()]
    return {
        "identity": {
            "name": identity.name,
            "display_name": identity.display_name,
            "description": identity.description,
            "version": identity.version,
            "author": identity.author,
        },
        "parts": [
            {
                "name": part.name,
                "parent": part.parent,
                "model_node": part.model_node,
                "description": part.description,
            }
            for part in rig.parts.values()
        ],
        "joints": joints,
        "parameters": [
            {
                "name": parameter.name,
                "neutral": parameter.neutral_value,
                "description": parameter.description,
            }
            for parameter in rig.parameters.values()
        ],
        "clips": [
            {
                "name": rig_clip.clip.name,
                "duration_s": rig_clip.clip.duration_seconds,
                "loop": rig_clip.loop,
            }
            for rig_clip in rig.clips.values()
        ],
        "outputs": [
            {"dof_path": mapping.target, "channel": mapping.channel}
            for mapping in rig.outputs
        ],
    }


def _projectable_channels(rig: Rig, pose) -> dict[int, float]:
    """``project_channels`` but never fails on a limit violation.

    On the common path this is exactly ``project_channels`` (a faithful
    passthrough of the canonical projection). When a mapped DOF is in
    ``pose.limit_violations`` the canonical call raises; per the spec
    ``evaluate`` reports the violation rather than failing, so the
    violated channel is omitted and the rest still project.
    """
    try:
        return project_channels(rig, pose)
    except LimitViolationError:
        violated = {v.dof_path for v in pose.limit_violations}
        channels: dict[int, float] = {}
        for mapping in rig.outputs:
            if mapping.target in violated:
                continue
            if "." in mapping.target:
                value = pose.dof_values[mapping.target]
            else:
                value = pose.parameter_values[mapping.target]
            channels[mapping.channel] = mapping.channel_value(value)
        return channels


# Verbs -----------------------------------------------------------------------


def _hello(session: Session, params: dict, request_id: object) -> dict:
    client_version = params.get("protocol_version")
    if not isinstance(client_version, int) or isinstance(client_version, bool):
        raise _BadRequest("'protocol_version' must be an integer")
    if client_version != PROTOCOL_VERSION:
        return _error(
            request_id,
            "protocol_mismatch",
            f"client speaks protocol {client_version}, engine speaks "
            f"{PROTOCOL_VERSION}",
        )
    return _ok(
        request_id,
        {
            "engine": ENGINE_NAME,
            "engine_version": ENGINE_VERSION,
            "protocol_version": PROTOCOL_VERSION,
            "capabilities": list(CAPABILITIES),
        },
    )


def _load_character(session: Session, params: dict, request_id: object) -> dict:
    text = _require_str(params, "text")
    try:
        rig = parse_character(text)
    except CharacterFormatError as error:
        return _error(request_id, "format_error", error.message, error.path)
    handle = session.add(rig)
    return _ok(request_id, {"handle": handle, "rig": _rig_summary(rig)})


def _validate_character(
    session: Session, params: dict, request_id: object
) -> dict:
    text = _require_str(params, "text")
    try:
        parse_character(text)
    except CharacterFormatError as error:
        return _ok(
            request_id,
            {
                "diagnostics": [
                    {
                        "code": "format_error",
                        "message": error.message,
                        "path": error.path,
                    }
                ]
            },
        )
    return _ok(request_id, {"diagnostics": []})


def _evaluate(session: Session, params: dict, request_id: object) -> dict:
    handle = _require_str(params, "handle")
    rig = session.get(handle)
    if rig is None:
        return _error(
            request_id, "unknown_handle", f"no rig loaded as {handle!r}"
        )
    clip = params.get("clip")
    if clip is not None and not isinstance(clip, str):
        raise _BadRequest("'clip' must be a string or null")
    time_s = params.get("time_s", 0.0)
    if isinstance(time_s, bool) or not isinstance(time_s, (int, float)):
        raise _BadRequest("'time_s' must be a number")
    try:
        pose = evaluate_pose(rig, clip, float(time_s))
    except KeyError:
        raise _BadRequest(f"rig {handle!r} has no clip named {clip!r}")
    channels = _projectable_channels(rig, pose)
    return _ok(
        request_id,
        {
            "dof_values": dict(pose.dof_values),
            "parameters": dict(pose.parameter_values),
            # JSON object keys are strings; the channel index is an int.
            "channels": {str(ch): value for ch, value in channels.items()},
            "limit_violations": [
                {
                    "dof_path": v.dof_path,
                    "value": v.value,
                    "min": v.min_value,
                    "max": v.max_value,
                }
                for v in pose.limit_violations
            ],
        },
    )


def _mate_types(session: Session, params: dict, request_id: object) -> dict:
    # The palette/panel-builder hook: the static per-kind schema for all
    # eight mate kinds (label, DOF slots, and the shared universal
    # controls). No rig handle needed — it is the type catalog.
    return _ok(request_id, {"mate_types": all_mate_type_schemas()})


def _release(session: Session, params: dict, request_id: object) -> dict:
    # Idempotent: dropping an unknown handle is not an error, so a client
    # can release freely without tracking exactly what the engine holds.
    session.drop(_require_str(params, "handle"))
    return _ok(request_id, {})


def _shutdown(session: Session, params: dict, request_id: object) -> dict:
    session.exit = True
    return _ok(request_id, {})


_VERBS = {
    "hello": _hello,
    "load_character": _load_character,
    "validate_character": _validate_character,
    "evaluate": _evaluate,
    "mate_types": _mate_types,
    "release": _release,
    "shutdown": _shutdown,
}


def handle_request(session: Session, request: dict) -> dict:
    """Dispatch one parsed request to a response envelope.

    Never raises for a protocol/format/shape error — those become an
    ``{ok: false, error: {...}}`` envelope. Only a truly unexpected
    engine bug propagates. ``request['id']`` is echoed verbatim.
    """
    request_id = request.get("id")
    method = request.get("method")
    if not isinstance(method, str):
        return _error(request_id, "bad_request", "missing/invalid 'method'")
    params = request.get("params", {})
    if params is None:
        params = {}
    if not isinstance(params, dict):
        return _error(request_id, "bad_request", "'params' must be an object")
    verb = _VERBS.get(method)
    if verb is None:
        return _error(request_id, "bad_request", f"unknown method {method!r}")
    try:
        return verb(session, params, request_id)
    except _BadRequest as error:
        return _error(request_id, "bad_request", str(error))


# stdio loop ------------------------------------------------------------------


def main(stdin: IO[str] | None = None, stdout: IO[str] | None = None) -> None:
    """Run the newline-JSON stdio loop until ``shutdown`` or EOF."""
    stdin = stdin if stdin is not None else sys.stdin
    stdout = stdout if stdout is not None else sys.stdout
    session = Session()
    for line in stdin:
        line = line.strip()
        if not line:
            continue
        try:
            request = json.loads(line)
        except json.JSONDecodeError as error:
            response = _error(None, "bad_request", f"invalid JSON: {error}")
        else:
            if isinstance(request, dict):
                response = handle_request(session, request)
            else:
                response = _error(
                    None, "bad_request", "request must be a JSON object"
                )
        stdout.write(json.dumps(response) + "\n")
        stdout.flush()
        if session.exit:
            break


if __name__ == "__main__":  # pragma: no cover - exercised via subprocess
    main()
