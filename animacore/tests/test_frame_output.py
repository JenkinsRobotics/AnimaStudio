"""Tests for the frame hardware output + 64x64 LED-matrix downsample math."""

from __future__ import annotations

import pytest

from animacore.frame_output import (
    LedMatrixTarget,
    SimulatorFrameOutput,
    downsample_canvas,
)


def _solid(width: int, height: int, color: tuple[int, int, int]):
    return [[color for _ in range(width)] for _ in range(height)]


def test_matrix_validation():
    with pytest.raises(ValueError):
        LedMatrixTarget(width=0)
    with pytest.raises(ValueError):
        LedMatrixTarget(gamma=0.0)
    with pytest.raises(ValueError):
        LedMatrixTarget(brightness=1.5)


def test_downsample_solid_color_preserved():
    frame = _solid(64, 64, (120, 40, 200))
    out = downsample_canvas(frame, LedMatrixTarget(width=8, height=8))
    assert len(out) == 8 and len(out[0]) == 8
    assert all(pixel == (120, 40, 200) for row in out for pixel in row)


def test_downsample_area_averages_a_2x2_block():
    # A 2x2 frame of four different colors averaged into a single cell.
    frame = [
        [(0, 0, 0), (100, 0, 0)],
        [(0, 100, 0), (0, 0, 100)],
    ]
    out = downsample_canvas(frame, LedMatrixTarget(width=1, height=1))
    assert out == [[(25, 25, 25)]]


def test_brightness_caps_output():
    frame = _solid(4, 4, (200, 200, 200))
    out = downsample_canvas(frame, LedMatrixTarget(width=2, height=2, brightness=0.5))
    assert all(pixel == (100, 100, 100) for row in out for pixel in row)


def test_gamma_darkens_midtones():
    frame = _solid(4, 4, (128, 128, 128))
    out = downsample_canvas(frame, LedMatrixTarget(width=1, height=1, gamma=2.0))
    # (128/255)^2 * 255 ~= 64
    assert out[0][0][0] == pytest.approx(64, abs=1)


def test_upsample_uses_nearest_pixels():
    frame = [[(255, 0, 0), (0, 0, 255)]]
    out = downsample_canvas(frame, LedMatrixTarget(width=4, height=2))
    assert len(out) == 2 and len(out[0]) == 4
    # left half samples the red pixel, right half the blue pixel
    assert out[0][0] == (255, 0, 0)
    assert out[0][3] == (0, 0, 255)


def test_downsample_rejects_empty_frame():
    with pytest.raises(ValueError):
        downsample_canvas([], LedMatrixTarget())


def test_simulator_frame_output_lifecycle_downsamples():
    target = LedMatrixTarget(width=2, height=2)
    node = SimulatorFrameOutput(target=target)
    node.open()
    node.send_frame(_solid(64, 64, (10, 20, 30)), sequence=1)
    assert node.last_sequence == 1
    assert node.last_frame == [[(10, 20, 30), (10, 20, 30)], [(10, 20, 30), (10, 20, 30)]]
    node.stop()
    assert node.last_frame is None


def test_simulator_frame_output_requires_open():
    node = SimulatorFrameOutput()
    with pytest.raises(RuntimeError):
        node.send_frame(_solid(2, 2, (0, 0, 0)), sequence=0)
