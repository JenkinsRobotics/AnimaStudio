"""Anima Wire Protocol v0 — host-side reference implementation.

Encodes host→device command lines and parses device→host replies per
``dev/docs/roadmap/Wire_Protocol.md``. Transport-agnostic: every
function takes and returns ``str`` lines without the trailing newline;
the caller owns the serial/TCP transport.
"""

from __future__ import annotations

from collections.abc import Mapping
from dataclasses import dataclass

PROTOCOL_VERSION = 0

# ERR,<code>,<msg> codes (device → host).
ERR_PARSE = 1
ERR_BAD_CHANNEL = 2
ERR_BAD_VALUE = 3
ERR_NOT_CONFIGURED = 4


class WireError(ValueError):
    """A value that cannot be encoded, or a line that cannot be parsed."""


def format_value(value: float) -> str:
    """Format a normalized channel value (0.0..1.0) with 3 decimal places."""
    if not 0.0 <= value <= 1.0:
        raise WireError(f"channel value out of range 0.0..1.0: {value!r}")
    return f"{value:.3f}"


def _validate_channel(channel: int) -> int:
    if not isinstance(channel, int) or isinstance(channel, bool) or channel < 0:
        raise WireError(f"channel must be a non-negative int: {channel!r}")
    return channel


def _validate_non_negative_int(name: str, value: int) -> int:
    if not isinstance(value, int) or isinstance(value, bool) or value < 0:
        raise WireError(f"{name} must be a non-negative int: {value!r}")
    return value


# Host → device -------------------------------------------------------------


def encode_hello() -> str:
    return f"HELLO,{PROTOCOL_VERSION}"


def encode_cfg(
    channel: int,
    *,
    pin: int,
    min_us: int,
    max_us: int,
    invert: bool = False,
    neutral: float | None = None,
    failsafe_ms: int | None = None,
) -> str:
    """Encode a servo channel configuration line."""
    _validate_channel(channel)
    _validate_non_negative_int("pin", pin)
    _validate_non_negative_int("min_us", min_us)
    _validate_non_negative_int("max_us", max_us)
    if min_us >= max_us:
        raise WireError(f"min_us must be < max_us: {min_us} >= {max_us}")

    fields = [
        f"CFG,{channel},servo",
        f"pin={pin}",
        f"min_us={min_us}",
        f"max_us={max_us}",
    ]
    if invert:
        fields.append("invert=1")
    if neutral is not None:
        fields.append(f"neutral={format_value(neutral)}")
    if failsafe_ms is not None:
        _validate_non_negative_int("failsafe_ms", failsafe_ms)
        fields.append(f"failsafe_ms={failsafe_ms}")
    return ",".join(fields)


def encode_frm(duration_ms: int, targets: Mapping[int, float]) -> str:
    """Encode a frame: move each channel to its target over ``duration_ms``."""
    _validate_non_negative_int("duration_ms", duration_ms)
    if not targets:
        raise WireError("FRM requires at least one channel target")
    pairs = [
        f"{_validate_channel(channel)}:{format_value(value)}"
        for channel, value in sorted(targets.items())
    ]
    return f"FRM,{duration_ms}," + ",".join(pairs)


def encode_en(channel: int, enabled: bool) -> str:
    return f"EN,{_validate_channel(channel)},{1 if enabled else 0}"


def encode_stop() -> str:
    return "STOP"


def encode_ping() -> str:
    return "PING"


# Device → host -------------------------------------------------------------


@dataclass(frozen=True)
class Hello:
    protocol_version: int
    device_name: str
    channel_count: int


@dataclass(frozen=True)
class Ok:
    pass


@dataclass(frozen=True)
class Err:
    code: int
    message: str


@dataclass(frozen=True)
class Pong:
    pass


Reply = Hello | Ok | Err | Pong


def parse_reply(line: str) -> Reply:
    """Parse one device→host line. Raises WireError on anything malformed."""
    stripped = line.rstrip("\r\n")
    parts = stripped.split(",")
    command = parts[0]

    if command == "OK" and len(parts) == 1:
        return Ok()
    if command == "PONG" and len(parts) == 1:
        return Pong()
    if command == "ANIMA" and len(parts) == 4:
        try:
            return Hello(
                protocol_version=int(parts[1]),
                device_name=parts[2],
                channel_count=int(parts[3]),
            )
        except ValueError as error:
            raise WireError(f"bad ANIMA reply: {stripped!r}") from error
    if command == "ERR" and len(parts) >= 3:
        try:
            code = int(parts[1])
        except ValueError as error:
            raise WireError(f"bad ERR code: {stripped!r}") from error
        return Err(code=code, message=",".join(parts[2:]))

    raise WireError(f"unrecognized device reply: {stripped!r}")
