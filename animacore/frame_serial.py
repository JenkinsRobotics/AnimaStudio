"""Serial LED-matrix frame output — the frame sibling of ``SerialWireOutput``.

Where ``serial_transport.SerialWireOutput`` streams scalar servo targets over the
Anima Wire Protocol, this streams rasterized frames to an RGB LED matrix over the
simple matrix command protocol (``MM``/``BM``/``FM``), ported from Mochi's
``jp01/devices/led_matrix.py`` (Apache-2.0). It implements
``frame_output.FrameOutput`` (``open`` -> ``send_frame`` -> ``stop``/``close``):
each frame is area-averaged down to the matrix via ``downsample_canvas`` (so the
LED simulator and the panel get identical pixels), then written as one
``FM[<rrggbb...>]`` line.

``port`` accepts anything ``serial.serial_for_url`` does — a device path for a
real panel, or ``loop://`` for an in-memory test.
"""

from __future__ import annotations

import serial

from animacore.frame_output import Frame, LedMatrixTarget, downsample_canvas

__all__ = [
    "build_matrix_mode",
    "build_matrix_brightness",
    "build_matrix_frame",
    "frame_to_hex",
    "SerialFrameOutput",
]


# ── matrix command builders (ported from Mochi's led_matrix.py) ───────


def build_matrix_mode(mode: int) -> str:
    return f"MM[{int(mode)}]"


def build_matrix_brightness(value: int) -> str:
    return f"BM[{int(value)}]"


def build_matrix_frame(rgb_hex: str) -> str:
    """``rgb_hex``: concatenated per-pixel RRGGBB hex, row-major."""
    return f"FM[{rgb_hex}]"


def frame_to_hex(rows: Frame) -> str:
    """Row-major RGB rows -> one uppercase ``RRGGBB`` hex string per pixel."""
    return "".join(
        f"{r & 0xFF:02X}{g & 0xFF:02X}{b & 0xFF:02X}"
        for row in rows
        for (r, g, b) in row
    )


class SerialFrameOutput:
    """Stream frames to a real RGB LED matrix over serial.

    Lifecycle per ``FrameOutput``: ``open`` (set mode + device brightness) ->
    ``send_frame`` (downsample + ``FM``) -> ``stop`` (blank) / ``close``.

    ``device_brightness`` (0..255) is the panel's own current-limit knob, kept
    separate from ``target.brightness`` (which shapes the pixel values in
    software) so both remain tunable — a real panel needs the hardware knob.
    """

    # ponytail: fire-and-forget writes, no reply handshake — the matrix protocol
    # has none. Add framing/ack in a v1 if a real panel needs it.

    def __init__(
        self,
        port: str,
        target: LedMatrixTarget | None = None,
        baudrate: int = 115200,
        mode: int = 1,
        device_brightness: int = 255,
    ) -> None:
        self.target = target or LedMatrixTarget()
        self._port_url = port
        self._baudrate = baudrate
        self._mode = mode
        self._device_brightness = max(0, min(255, int(device_brightness)))
        self._port: serial.SerialBase | None = None
        self.last_sequence: int = -1

    def open(self) -> None:
        self._port = serial.serial_for_url(self._port_url, baudrate=self._baudrate)
        self._write(build_matrix_mode(self._mode))
        self._write(build_matrix_brightness(self._device_brightness))

    def send_frame(self, frame: Frame, sequence: int) -> None:
        if self._port is None:
            raise RuntimeError("send_frame before open")
        rows = downsample_canvas(frame, self.target)
        self._write(build_matrix_frame(frame_to_hex(rows)))
        self.last_sequence = sequence

    def stop(self) -> None:
        """Blank the panel now (all-black frame). Best-effort, idempotent."""
        if self._port is None:
            return
        blank = [[(0, 0, 0)] * self.target.width for _ in range(self.target.height)]
        try:
            self._write(build_matrix_frame(frame_to_hex(blank)))
        except (serial.SerialException, OSError):
            pass

    def close(self) -> None:
        if self._port is not None:
            self._port.close()
            self._port = None

    def _write(self, line: str) -> None:
        assert self._port is not None, "open() must be called first"
        self._port.write((line + "\n").encode("ascii"))
