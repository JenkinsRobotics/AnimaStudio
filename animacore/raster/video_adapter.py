"""VideoAdapter — L4 video via imageio (ffmpeg), decode-by-index -> RGBA.

Ported from Mochi (`mochi/nodes/media/decoders/video_adapter.py`, Apache-2.0).
Wraps imageio's ffmpeg reader into the same ``open``/``next_frame``/``close``
contract. Decode-by-index is simple, not the fastest; a streaming reader is a
later optimization.
"""

from __future__ import annotations

from typing import Any

from animacore.raster.frame import FrameBuffer


class VideoAdapter:
    def __init__(self) -> None:
        self._reader: Any = None
        self._w = 0
        self._h = 0
        self._fps = 25.0
        self._n = 0
        self._loop = True

    def open(self, asset_path: str, *, width: int, height: int, params: dict) -> None:
        import imageio

        self._w, self._h = max(1, int(width)), max(1, int(height))
        self._loop = bool((params or {}).get("loop", True))
        self._reader = imageio.get_reader(asset_path)  # ffmpeg backend
        meta = self._reader.get_meta_data() or {}
        self._fps = float(meta.get("fps", 25.0)) or 25.0
        try:
            self._n = int(self._reader.count_frames())
        except Exception:  # noqa: BLE001 — some containers can't count; fall back
            self._n = int(meta.get("nframes", 0) or 0)

    def next_frame(self, t: float) -> FrameBuffer | None:
        if self._reader is None:
            return None
        i = int(t * self._fps)
        if self._n and i >= self._n:
            if not self._loop:
                return None
            i %= self._n
        try:
            arr = self._reader.get_data(i)  # (H, W, 3) RGB uint8
        except (IndexError, StopIteration):
            return None
        return FrameBuffer(
            width=self._w,
            height=self._h,
            data=self._to_rgba(arr),
            duration_ms=int(1000.0 / self._fps),
        )

    def _to_rgba(self, arr: Any) -> bytes:
        from PIL import Image

        img = Image.fromarray(arr).convert("RGBA")
        if (img.width, img.height) != (self._w, self._h):
            img = img.resize((self._w, self._h), Image.BILINEAR)
        return img.tobytes()

    def close(self) -> None:
        if self._reader is not None:
            try:
                self._reader.close()
            except Exception:  # noqa: BLE001
                pass
            self._reader = None
