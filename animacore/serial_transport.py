"""Serial wire transport: ``OutputAdapter`` over a real serial port.

Third consumer of the ``animacore.outputs.OutputAdapter`` contract
(after ``SimulatorOutput`` and the UDP example extension): bridges
evaluated 0..1 channel frames over pyserial to physical hardware
speaking Anima Wire Protocol v0 (``dev/docs/roadmap/Wire_Protocol.md``)
— the Arduino/ESP32 firmware in ``firmware/anima_firmware/``.

``port`` accepts anything ``serial.serial_for_url`` does: a device path
such as ``/dev/tty.usbmodem1101`` for a real board, or a pyserial URL —
``loop://`` gives an in-memory loopback for tests.

Reply handling is strict and time-bounded: every command expects one
newline-terminated reply within ``reply_timeout_s``
(``handshake_timeout_s`` for HELLO, because many boards reset when the
port opens). A missing, garbled, or rejecting reply raises a typed
error — the operator's signal that the link is bad. The host error is
NOT the safety net: if the host dies mid-stream, the device-side
failsafe in ``Wire_Protocol.md`` is what disarms the servos.
"""

from __future__ import annotations

from collections.abc import Mapping, Sequence

import serial

from animacore.outputs import ChannelConfig
from animacore.wire import (
    PROTOCOL_VERSION,
    Err,
    Hello,
    Ok,
    Reply,
    WireError,
    encode_cfg,
    encode_en,
    encode_frm,
    encode_hello,
    encode_stop,
    parse_reply,
)

# Longest legal v0 reply is a short ANIMA line; anything this big is noise.
MAX_REPLY_BYTES = 256


class SerialTransportError(RuntimeError):
    """Base for everything that can go wrong on the serial bridge."""


class HandshakeError(SerialTransportError):
    """HELLO was answered, but not by a compatible ANIMA device."""


class ReplyTimeoutError(SerialTransportError):
    """No complete reply line arrived within the read timeout."""


class ProtocolError(SerialTransportError):
    """A reply line arrived but could not be understood (garbage,
    undecodable bytes, an oversized line, or an unexpected reply type)."""


class DeviceRejectedError(SerialTransportError):
    """The device answered ``ERR,<code>,<msg>`` to a command."""

    def __init__(self, command: str, code: int, device_message: str):
        super().__init__(
            f"device rejected {command!r}: ERR,{code},{device_message}"
        )
        self.command = command
        self.code = code
        self.device_message = device_message


class SerialWireOutput:
    """Output adapter driving real hardware over a serial port.

    Lifecycle per ``OutputAdapter``: ``open`` (handshake + CFG + EN per
    channel) → ``send_frame``* → ``stop``/``close``. ``close`` is not
    ``stop`` — a device losing its host is the firmware failsafe's job.

    ``device_hello`` holds the parsed ANIMA handshake reply after a
    successful ``open`` (device name and channel count); ``last_error``
    holds the most recent error swallowed by best-effort ``stop``.
    """

    # ponytail: no reconnect logic and no threads in v1 — one port, one
    # blocking command/reply exchange at a time. Reconnect/async lands
    # with Studio live-control needs.

    def __init__(
        self,
        port: str,
        baudrate: int = 115200,
        handshake_timeout_s: float = 2.0,
        reply_timeout_s: float = 0.5,
    ):
        self._port_url = port
        self._baudrate = baudrate
        self._handshake_timeout_s = handshake_timeout_s
        self._reply_timeout_s = reply_timeout_s
        self._port: serial.SerialBase | None = None
        self.device_hello: Hello | None = None
        self.last_error: Exception | None = None

    # OutputAdapter -----------------------------------------------------------

    def open(self, channel_configs: Sequence[ChannelConfig]) -> None:
        """Open the port, HELLO-handshake, then CFG and EN every channel."""
        self._port = serial.serial_for_url(
            self._port_url,
            baudrate=self._baudrate,
            timeout=self._reply_timeout_s,
        )
        self._handshake()
        for config in channel_configs:
            self._command(
                encode_cfg(
                    config.channel,
                    pin=config.pin,
                    min_us=config.min_us,
                    max_us=config.max_us,
                    invert=config.invert,
                    neutral=config.neutral,
                    failsafe_ms=config.failsafe_ms,
                )
            )
            self._command(encode_en(config.channel, True))

    def send_frame(
        self, targets: Mapping[int, float], duration_ms: int
    ) -> None:
        """Encode and send one FRM, then block until the device replies.

        A missing reply raises ``ReplyTimeoutError`` after
        ``reply_timeout_s`` — the operator signal that the link died.
        The device-side failsafe is the safety net that disarms servos.
        """
        self._command(encode_frm(duration_ms, targets))

    def stop(self) -> None:
        """E-stop: send STOP, best-effort. Idempotent, never raises.

        A dead port during an e-stop must not raise past the caller:
        failures are swallowed and recorded on ``last_error`` (cleared
        on each attempt). The device's own failsafe covers a link that
        is truly gone.
        """
        self.last_error = None
        if self._port is None:
            return
        try:
            self._command(encode_stop())
        except (SerialTransportError, OSError) as error:
            self.last_error = error

    def close(self) -> None:
        """Close the port. Explicitly NOT ``stop`` (outputs.py semantics):
        a lost host is the firmware failsafe's job."""
        if self._port is not None:
            self._port.close()

    # Wire plumbing -----------------------------------------------------------

    def _handshake(self) -> None:
        self._write_line(encode_hello())
        reply = self._read_reply(self._handshake_timeout_s, encode_hello())
        if isinstance(reply, Err):
            raise DeviceRejectedError(encode_hello(), reply.code, reply.message)
        if not isinstance(reply, Hello):
            raise HandshakeError(
                f"expected ANIMA reply to HELLO, got {reply!r}"
            )
        if reply.protocol_version != PROTOCOL_VERSION:
            raise HandshakeError(
                f"device speaks protocol v{reply.protocol_version}, "
                f"host speaks v{PROTOCOL_VERSION}"
            )
        self.device_hello = reply

    def _command(self, line: str) -> None:
        """Send one command line and require an OK reply."""
        self._write_line(line)
        reply = self._read_reply(self._reply_timeout_s, line)
        if isinstance(reply, Err):
            raise DeviceRejectedError(line, reply.code, reply.message)
        if not isinstance(reply, Ok):
            raise ProtocolError(f"expected OK to {line!r}, got {reply!r}")

    def _write_line(self, line: str) -> None:
        assert self._port is not None, "open() must be called first"
        self._port.write((line + "\n").encode("utf-8"))

    def _read_reply(self, timeout_s: float, command: str) -> Reply:
        """Read one newline-framed reply within ``timeout_s``.

        pyserial's own read timeout does the waiting — no polling, no
        sleeps. Undecodable bytes and oversized garbage are protocol
        errors; silence is a ``ReplyTimeoutError``.
        """
        assert self._port is not None, "open() must be called first"
        self._port.timeout = timeout_s
        raw = self._port.read_until(b"\n", MAX_REPLY_BYTES)
        if not raw.endswith(b"\n"):
            if len(raw) >= MAX_REPLY_BYTES:
                raise ProtocolError(
                    f"oversized reply to {command!r}: "
                    f"{len(raw)} bytes without a newline"
                )
            raise ReplyTimeoutError(
                f"no reply to {command!r} within {timeout_s}s "
                f"(got {len(raw)} bytes)"
            )
        try:
            text = raw.decode("utf-8")
        except UnicodeDecodeError as error:
            raise ProtocolError(
                f"undecodable reply to {command!r}: {raw!r}"
            ) from error
        try:
            return parse_reply(text)
        except WireError as error:
            raise ProtocolError(
                f"unparseable reply to {command!r}: {text.strip()!r}"
            ) from error
