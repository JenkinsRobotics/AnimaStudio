"""UDP wire output adapter (the packaged E1 example extension).

Implements the ``animacore.outputs.OutputAdapter`` protocol by
encoding Anima Wire Protocol v0 lines with the public
``animacore.wire`` encoders (one copy of the wire truth — an
extension composes the core primitives, it never re-encodes them) and
sending each line as one UDP datagram, without a trailing newline, to
a configurable ``host:port``. Fire-and-forget: UDP has no reply path,
so device replies (and the handshake) don't apply — the receiving
device's failsafe covers lost datagrams and lost hosts. Stdlib only.
"""

from __future__ import annotations

import socket

from animacore.wire import encode_cfg, encode_en, encode_frm, encode_stop


class UdpWireOutput:
    """Sends wire-protocol lines as UDP datagrams to ``host:port``.

    Constructor keyword arguments come from the manifest's ``config:``
    mapping (callers may override, e.g. the port).
    """

    def __init__(self, host: str = "127.0.0.1", port: int = 9600):
        self._address = (host, int(port))
        self._socket: socket.socket | None = None

    def open(self, channel_configs) -> None:
        """Open the socket, then configure and arm every channel."""
        if self._socket is None:
            self._socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        for config in channel_configs:
            self._send(
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
            self._send(encode_en(config.channel, True))

    def send_frame(self, targets, duration_ms: int) -> None:
        self._send(encode_frm(duration_ms, targets))

    def stop(self) -> None:
        self._send(encode_stop())

    def close(self) -> None:
        if self._socket is not None:
            self._socket.close()
            self._socket = None

    def _send(self, line: str) -> None:
        if self._socket is None:
            raise RuntimeError("UdpWireOutput is not open")
        self._socket.sendto(line.encode("utf-8"), self._address)
