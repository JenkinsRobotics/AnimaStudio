"""Serial LED-matrix frame output — verified over a pyserial loopback."""

from __future__ import annotations

import pytest

from animacore.frame_serial import (
    SerialFrameOutput,
    build_matrix_frame,
    frame_to_hex,
)
from animacore.frame_output import LedMatrixTarget


def _solid(width: int, height: int, rgb):
    return [[rgb for _ in range(width)] for _ in range(height)]


def test_frame_to_hex_row_major():
    rows = [[(255, 0, 0), (0, 255, 0)], [(0, 0, 255), (16, 32, 48)]]
    assert frame_to_hex(rows) == "FF000000FF000000FF102030"


def test_build_matrix_frame_wraps():
    assert build_matrix_frame("FF0000") == "FM[FF0000]"


def test_open_emits_mode_and_brightness():
    out = SerialFrameOutput("loop://", target=LedMatrixTarget(2, 2), mode=1, device_brightness=200)
    out.open()
    sent = out._port.read(out._port.in_waiting)
    assert b"MM[1]\n" in sent
    assert b"BM[200]\n" in sent
    out.close()


def test_send_frame_downsamples_and_encodes():
    out = SerialFrameOutput("loop://", target=LedMatrixTarget(2, 2))
    out.open()
    _ = out._port.read(out._port.in_waiting)  # drain the open() lines
    out.send_frame(_solid(4, 4, (255, 0, 0)), sequence=7)
    sent = out._port.read(out._port.in_waiting).decode("ascii")
    assert out.last_sequence == 7
    # 4x4 solid red -> 2x2 solid red -> four RRGGBB pixels
    assert sent.strip() == "FM[FF0000FF0000FF0000FF0000]"
    out.close()


def test_send_frame_before_open_raises():
    out = SerialFrameOutput("loop://")
    with pytest.raises(RuntimeError):
        out.send_frame(_solid(2, 2, (0, 0, 0)), sequence=0)


def test_stop_blanks_panel():
    out = SerialFrameOutput("loop://", target=LedMatrixTarget(2, 2))
    out.open()
    _ = out._port.read(out._port.in_waiting)
    out.stop()
    sent = out._port.read(out._port.in_waiting).decode("ascii")
    assert sent.strip() == "FM[000000000000000000000000]"
    out.close()
