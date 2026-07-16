"""In-process simulated device speaking Anima Wire Protocol v0 (device side).

No wall clock: the caller advances simulated time with ``tick(now_ms)``,
and a line passed to ``receive_line`` arrives at the current simulated
time. Servo motion is device-side linear interpolation toward the latest
FRM target; silence past a channel's ``failsafe_ms`` disables its output,
per the failsafe rule in ``dev/docs/roadmap/Wire_Protocol.md``.
"""

from __future__ import annotations

from dataclasses import dataclass

from animacore.wire import (
    ERR_BAD_CHANNEL,
    ERR_BAD_VALUE,
    ERR_NOT_CONFIGURED,
    ERR_PARSE,
    PROTOCOL_VERSION,
)

DEFAULT_FAILSAFE_MS = 2000
DEFAULT_NEUTRAL = 0.5

_OK = "OK"


class _CommandError(Exception):
    def __init__(self, code: int, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


def _err(code: int, message: str) -> _CommandError:
    return _CommandError(code, message)


@dataclass
class _Channel:
    pin: int
    min_us: int
    max_us: int
    invert: bool
    neutral: float
    failsafe_ms: int
    value: float
    enabled: bool = False
    # Active motion; duration 0 means idle.
    motion_start_ms: int = 0
    motion_duration_ms: int = 0
    motion_start_value: float = 0.0
    motion_target_value: float = 0.0

    def advance_to(self, now_ms: int) -> None:
        if self.motion_duration_ms == 0:
            return
        elapsed_ms = now_ms - self.motion_start_ms
        if elapsed_ms >= self.motion_duration_ms:
            self.value = self.motion_target_value
            self.motion_duration_ms = 0
        elif elapsed_ms > 0:
            progress = elapsed_ms / self.motion_duration_ms
            self.value = self.motion_start_value + (
                (self.motion_target_value - self.motion_start_value) * progress
            )

    def halt(self) -> None:
        """Disable output and cancel any active motion (value freezes)."""
        self.enabled = False
        self.motion_duration_ms = 0


class SimulatedDevice:
    """Device side of the wire protocol, for tests and host development."""

    def __init__(
        self,
        device_name: str = "anima-sim",
        channel_count: int = 8,
        now_ms: int = 0,
    ):
        self._device_name = device_name
        self._channel_count = channel_count
        self._now_ms = now_ms
        self._last_rx_ms = now_ms
        self._channels: dict[int, _Channel] = {}

    # Time ------------------------------------------------------------------

    @property
    def now_ms(self) -> int:
        return self._now_ms

    def tick(self, now_ms: int) -> None:
        """Advance simulated time: interpolate motion, then check failsafe."""
        if now_ms < self._now_ms:
            raise ValueError(f"time went backwards: {now_ms} < {self._now_ms}")
        self._now_ms = now_ms
        silence_ms = now_ms - self._last_rx_ms
        for channel in self._channels.values():
            # ponytail: motion advances to now before the failsafe check, so a
            # single tick jumping far past the deadline freezes the value where
            # the motion is at `now`, not at the deadline. Tick at frame rate.
            channel.advance_to(now_ms)
            if channel.enabled and silence_ms >= channel.failsafe_ms:
                channel.halt()

    # Observability (not part of the wire protocol) --------------------------

    def channel_value(self, channel: int) -> float:
        return self._configured(channel).value

    def channel_enabled(self, channel: int) -> bool:
        return self._configured(channel).enabled

    def channel_pulse_us(self, channel: int) -> float:
        """Pulse width the servo signal would carry, applying invert."""
        state = self._configured(channel)
        value = 1.0 - state.value if state.invert else state.value
        return state.min_us + ((state.max_us - state.min_us) * value)

    def _configured(self, channel: int) -> _Channel:
        if channel not in self._channels:
            raise KeyError(f"channel {channel} not configured")
        return self._channels[channel]

    # Protocol ----------------------------------------------------------------

    def receive_line(self, line: str) -> str:
        """Handle one host→device line, return the device→host reply line."""
        try:
            reply = self._handle(line.rstrip("\r\n"))
        except _CommandError as error:
            return f"ERR,{error.code},{error.message}"
        # Only a successfully parsed command refreshes the failsafe heartbeat —
        # line noise must never keep a servo armed (Wire_Protocol.md).
        self._last_rx_ms = self._now_ms
        return reply

    def _handle(self, line: str) -> str:
        parts = line.split(",")
        command = parts[0]
        if command == "HELLO":
            return self._handle_hello(parts)
        if command == "CFG":
            return self._handle_cfg(parts)
        if command == "FRM":
            return self._handle_frm(parts)
        if command == "EN":
            return self._handle_en(parts)
        if command == "STOP" and len(parts) == 1:
            for channel in self._channels.values():
                channel.halt()
            return _OK
        if command == "PING" and len(parts) == 1:
            return "PONG"
        raise _err(ERR_PARSE, "parse")

    def _handle_hello(self, parts: list[str]) -> str:
        if len(parts) != 2:
            raise _err(ERR_PARSE, "parse")
        if self._parse_int(parts[1]) != PROTOCOL_VERSION:
            raise _err(ERR_BAD_VALUE, "bad-protocol-version")
        return f"ANIMA,{PROTOCOL_VERSION},{self._device_name},{self._channel_count}"

    def _handle_cfg(self, parts: list[str]) -> str:
        if len(parts) < 3:
            raise _err(ERR_PARSE, "parse")
        channel = self._parse_channel(parts[1])
        if parts[2] != "servo":
            raise _err(ERR_BAD_VALUE, "bad-channel-type")

        keys: dict[str, str] = {}
        for field in parts[3:]:
            key, separator, raw = field.partition("=")
            if not separator or not raw:
                raise _err(ERR_PARSE, "parse")
            if key in keys:
                raise _err(ERR_PARSE, "duplicate-key")
            keys[key] = raw

        known = {"pin", "min_us", "max_us", "invert", "neutral", "failsafe_ms"}
        if not set(keys) <= known:
            raise _err(ERR_PARSE, "unknown-key")
        for required in ("pin", "min_us", "max_us"):
            if required not in keys:
                raise _err(ERR_PARSE, f"missing-{required}")

        min_us = self._parse_int(keys["min_us"])
        max_us = self._parse_int(keys["max_us"])
        if min_us >= max_us:
            raise _err(ERR_BAD_VALUE, "bad-pulse-range")
        invert = keys.get("invert", "0")
        if invert not in ("0", "1"):
            raise _err(ERR_BAD_VALUE, "bad-invert")
        neutral = self._parse_value(keys.get("neutral", str(DEFAULT_NEUTRAL)))
        failsafe_ms = self._parse_int(keys.get("failsafe_ms", str(DEFAULT_FAILSAFE_MS)))

        self._channels[channel] = _Channel(
            pin=self._parse_int(keys["pin"]),
            min_us=min_us,
            max_us=max_us,
            invert=invert == "1",
            neutral=neutral,
            failsafe_ms=failsafe_ms,
            value=neutral,
        )
        return _OK

    def _handle_frm(self, parts: list[str]) -> str:
        if len(parts) < 3:
            raise _err(ERR_PARSE, "parse")
        duration_ms = self._parse_int(parts[1])
        if duration_ms < 0:
            raise _err(ERR_BAD_VALUE, "bad-duration")

        # Validate every target before applying any: a frame is atomic.
        targets: list[tuple[_Channel, float]] = []
        seen_channels: set[int] = set()
        for pair in parts[2:]:
            raw_channel, separator, raw_value = pair.partition(":")
            if not separator:
                raise _err(ERR_PARSE, "parse")
            channel = self._parse_channel(raw_channel)
            if channel in seen_channels:
                raise _err(ERR_PARSE, "duplicate-channel")
            seen_channels.add(channel)
            if channel not in self._channels:
                raise _err(ERR_NOT_CONFIGURED, "not-configured")
            targets.append((self._channels[channel], self._parse_value(raw_value)))

        for state, target_value in targets:
            if duration_ms == 0:
                state.value = target_value
                state.motion_duration_ms = 0
            else:
                state.motion_start_ms = self._now_ms
                state.motion_duration_ms = duration_ms
                state.motion_start_value = state.value
                state.motion_target_value = target_value
        return _OK

    def _handle_en(self, parts: list[str]) -> str:
        if len(parts) != 3:
            raise _err(ERR_PARSE, "parse")
        channel = self._parse_channel(parts[1])
        if channel not in self._channels:
            raise _err(ERR_NOT_CONFIGURED, "not-configured")
        if parts[2] not in ("0", "1"):
            raise _err(ERR_BAD_VALUE, "bad-value")
        state = self._channels[channel]
        if parts[2] == "1":
            state.enabled = True
        else:
            state.halt()
        return _OK

    def _parse_channel(self, raw: str) -> int:
        channel = self._parse_int(raw)
        if not 0 <= channel < self._channel_count:
            raise _err(ERR_BAD_CHANNEL, "bad-channel")
        return channel

    @staticmethod
    def _parse_int(raw: str) -> int:
        try:
            return int(raw)
        except ValueError:
            raise _err(ERR_PARSE, "parse") from None

    @staticmethod
    def _parse_value(raw: str) -> float:
        try:
            value = float(raw)
        except ValueError:
            raise _err(ERR_PARSE, "parse") from None
        if not 0.0 <= value <= 1.0:
            raise _err(ERR_BAD_VALUE, "bad-value")
        return value
