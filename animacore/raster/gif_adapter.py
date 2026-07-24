"""GifAdapter — L3 animated GIF / APNG (Pillow's ImageSequence).

Ported from Mochi (`mochi/nodes/media/decoders/gif_adapter.py`, Apache-2.0).
Every source frame is fit to the target size + converted to RGBA8 once at
``open()``; ``next_frame(t)`` walks the cached frames by their real per-frame
durations, looping over total duration by default.
"""

from __future__ import annotations

from dataclasses import dataclass

from PIL import Image, ImageSequence

from animacore.raster.frame import FrameBuffer
from animacore.raster.image_adapter import _fit_contain, _fit_cover


@dataclass
class _CachedFrame:
    pixels: bytes  # target-sized RGBA8
    duration_ms: int


class GifAdapter:
    """Play an animated GIF/APNG asset, looping by default."""

    def __init__(self) -> None:
        self._frames: list[_CachedFrame] = []
        self._total_duration_ms: int = 0
        self._width: int = 0
        self._height: int = 0
        self._loop: bool = True
        self._start_time: float | None = None

    def open(self, asset_path: str, *, width: int, height: int, params: dict) -> None:
        """Decode + cache every source frame at the target size.

        ``params``: ``fit`` = "contain"|"cover"|"fill"; ``letterbox_rgb``;
        ``loop`` (default True) — False plays one pass then returns None.
        """
        p = dict(params or {})
        self._width = max(1, int(width))
        self._height = max(1, int(height))
        self._loop = bool(p.get("loop", True))
        fit = str(p.get("fit", "contain")).lower()
        letterbox_rgb = tuple(p.get("letterbox_rgb", (0, 0, 0)))
        self._frames = _decode_animated(
            asset_path,
            target=(self._width, self._height),
            fit=fit,
            letterbox_rgb=letterbox_rgb,
        )
        self._total_duration_ms = sum(f.duration_ms for f in self._frames)
        self._start_time = None

    def close(self) -> None:
        self._frames = []
        self._total_duration_ms = 0
        self._start_time = None

    def next_frame(self, t: float) -> FrameBuffer | None:
        if not self._frames:
            return None
        if self._start_time is None:
            self._start_time = t
        elapsed_ms = max(0, int((t - self._start_time) * 1000.0))
        if not self._loop and elapsed_ms >= self._total_duration_ms:
            return None
        if self._total_duration_ms > 0:
            elapsed_ms %= self._total_duration_ms
        acc = 0
        idx = len(self._frames) - 1
        for i, frame in enumerate(self._frames):
            dur = frame.duration_ms if frame.duration_ms > 0 else 100
            if elapsed_ms < acc + dur:
                idx = i
                break
            acc += dur
        chosen = self._frames[idx]
        return FrameBuffer(
            width=self._width,
            height=self._height,
            data=chosen.pixels,
            duration_ms=chosen.duration_ms,
            is_final=False,
        )


def _decode_animated(
    asset_path: str,
    *,
    target: tuple[int, int],
    fit: str,
    letterbox_rgb: tuple[int, int, int],
) -> list[_CachedFrame]:
    """Walk every source frame via Pillow's ImageSequence; convert to RGBA8."""
    target_w, target_h = target
    cached: list[_CachedFrame] = []
    with Image.open(asset_path) as src:
        for frame in ImageSequence.Iterator(src):
            rgba = frame.convert("RGBA")
            if fit == "cover":
                fitted = _fit_cover(rgba, target_w, target_h)
            elif fit == "fill":
                fitted = rgba.resize((target_w, target_h), Image.LANCZOS)
            else:
                fitted = _fit_contain(rgba, target_w, target_h, letterbox_rgb)
            duration_ms = int(frame.info.get("duration", 100) or 100)
            cached.append(_CachedFrame(pixels=fitted.tobytes(), duration_ms=duration_ms))
    return cached
