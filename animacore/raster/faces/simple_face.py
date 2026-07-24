"""SimpleFace — a parametric LED-matrix face (the reference procedural source).

Eyes + mouth drawn from parameters, so expression is *data*:

* ``mouth_open`` — the viseme / audio-amplitude channel (0 shut .. 1 wide)
* ``mouth_curve`` — smile (+1) .. frown (-1)
* ``eye_open`` — lid openness (0 shut .. 1 wide); an automatic blink multiplies it
* ``look_x`` / ``look_y`` — gaze aim (-1 .. 1)

A subtle breathing tint keeps idle non-static. Positions are fractions of the
given size, so the same face renders native at 64x64 for a matrix and larger for
a screen. Output is an RGBA8 ``FrameBuffer`` (the whole media-layer frame type).

ponytail: pure-Python per-pixel fill into a bytearray — instant at matrix sizes,
O(w*h); move to numpy only if a large preview canvas ever needs it live.
"""

from __future__ import annotations

import math
from collections.abc import Mapping

from animacore.raster.frame import RGB, FrameBuffer

_BLINK_PERIOD_S = 4.0
_BLINK_DURATION_S = 0.16


def _clamp(value: float, low: float = 0.0, high: float = 1.0) -> float:
    return min(max(value, low), high)


class SimpleFace:
    """A recolorable eyes-and-mouth face driven by evaluated parameters."""

    def __init__(
        self,
        *,
        feature: RGB = (120, 230, 255),
        background: RGB = (6, 8, 16),
    ) -> None:
        self.feature = feature
        self.background = background

    def render(
        self,
        width: int,
        height: int,
        time_seconds: float,
        params: Mapping[str, float],
    ) -> FrameBuffer:
        width = max(1, int(width))
        height = max(1, int(height))
        # A faint, translucent breathing tint — features are drawn opaque on top.
        # Keeping the background translucent lets the face composite over lower
        # layers (a media background), not hide them.
        buffer = bytearray(bytes(self._breathing_fill(time_seconds)) * (width * height))

        blink = self._blink_amount(time_seconds)
        eye_open = _clamp(params.get("eye_open", 1.0)) * (1.0 - blink)
        look_x = _clamp(params.get("look_x", 0.0), -1.0, 1.0)
        look_y = _clamp(params.get("look_y", 0.0), -1.0, 1.0)
        self._draw_eye(buffer, width, height, 0.34, 0.42, eye_open, look_x, look_y)
        self._draw_eye(buffer, width, height, 0.66, 0.42, eye_open, look_x, look_y)
        self._draw_mouth(
            buffer,
            width,
            height,
            _clamp(params.get("mouth_open", 0.0)),
            _clamp(params.get("mouth_curve", 0.0), -1.0, 1.0),
        )
        return FrameBuffer(width=width, height=height, data=bytes(buffer))

    # ── drawing ───────────────────────────────────────────────────────

    def _put(self, buffer: bytearray, width: int, x: int, y: int) -> None:
        i = (y * width + x) * 4
        buffer[i] = self.feature[0]
        buffer[i + 1] = self.feature[1]
        buffer[i + 2] = self.feature[2]
        buffer[i + 3] = 255

    def _breathing_fill(self, time_seconds: float) -> tuple[int, int, int, int]:
        """A faint translucent tint that pulses with an idle breathing rhythm."""
        pulse = 0.5 + 0.5 * math.sin(time_seconds * 0.8)  # 0..1
        red, green, blue = self.background
        alpha = int(14 + 26 * pulse)  # 14..40 — subtle; lower layers show through
        return (red, green, blue, alpha)

    def _blink_amount(self, time_seconds: float) -> float:
        """0 most of the time, a quick triangle to 1 once per blink period."""
        if time_seconds <= 0.0:
            return 0.0
        phase = time_seconds % _BLINK_PERIOD_S
        if phase >= _BLINK_DURATION_S:
            return 0.0
        half = _BLINK_DURATION_S / 2.0
        return _clamp(1.0 - abs(phase - half) / half)

    def _draw_eye(
        self,
        buffer: bytearray,
        width: int,
        height: int,
        cx_frac: float,
        cy_frac: float,
        eye_open: float,
        look_x: float,
        look_y: float,
    ) -> None:
        radius_x = 0.11 * width
        radius_y = max(1.0, 0.15 * height * eye_open)  # closed -> a thin line
        center_x = (cx_frac + look_x * 0.05) * width
        center_y = (cy_frac + look_y * 0.05) * height
        if radius_x < 0.5 or radius_y < 0.5:
            return
        x0 = max(0, int(center_x - radius_x))
        x1 = min(width - 1, int(center_x + radius_x))
        y0 = max(0, int(center_y - radius_y))
        y1 = min(height - 1, int(center_y + radius_y))
        for y in range(y0, y1 + 1):
            norm_y = (y + 0.5 - center_y) / radius_y
            for x in range(x0, x1 + 1):
                norm_x = (x + 0.5 - center_x) / radius_x
                if norm_x * norm_x + norm_y * norm_y <= 1.0:
                    self._put(buffer, width, x, y)

    def _draw_mouth(
        self,
        buffer: bytearray,
        width: int,
        height: int,
        mouth_open: float,
        mouth_curve: float,
    ) -> None:
        center_x = 0.5 * width
        half = 0.22 * width
        base_y = 0.68 * height
        amplitude = 0.12 * height
        thickness = max(1.0, (0.02 + 0.10 * mouth_open) * height)
        x0 = max(0, int(center_x - half))
        x1 = min(width - 1, int(center_x + half))
        for x in range(x0, x1 + 1):
            unit = (x - center_x) / half  # -1..1 across the mouth
            line_y = base_y + mouth_curve * (1.0 - unit * unit) * amplitude
            top = max(0, int(line_y - thickness / 2.0))
            bottom = min(height - 1, int(line_y + thickness / 2.0))
            for y in range(top, bottom + 1):
                self._put(buffer, width, x, y)
