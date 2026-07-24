"""ImageAdapter — L1 static image (PNG/JPG/BMP/WebP — anything Pillow opens).

Ported from Mochi (`mochi/nodes/media/decoders/image_adapter.py`, Apache-2.0).
Loads + fits an image to the target size once at ``open()`` and holds it as one
RGBA8 frame. The ``_fit_contain``/``_fit_cover`` helpers are reused by the GIF
adapter, kept here verbatim.
"""

from __future__ import annotations

from PIL import Image

from animacore.raster.frame import FrameBuffer


class ImageAdapter:
    """Render a single static image as one held frame."""

    def __init__(self) -> None:
        self._buffer: bytes = b""
        self._width: int = 0
        self._height: int = 0
        self._emitted: bool = False

    def open(self, asset_path: str, *, width: int, height: int, params: dict) -> None:
        """Load + resize the image into an RGBA8 byte buffer.

        ``params``: ``fit`` = "contain" (default) | "cover" | "fill" | "letterbox";
        ``letterbox_rgb`` = (r, g, b) bands for contain/letterbox (default black).
        """
        p = dict(params or {})
        self._width = max(1, int(width))
        self._height = max(1, int(height))
        self._emitted = False
        fit = str(p.get("fit", "contain")).lower()
        letterbox_rgb = tuple(p.get("letterbox_rgb", (0, 0, 0)))
        self._buffer = _load_to_rgba8(
            asset_path,
            target=(self._width, self._height),
            fit=fit,
            letterbox_rgb=letterbox_rgb,
        )

    def close(self) -> None:
        self._buffer = b""
        self._emitted = False

    def next_frame(self, t: float) -> FrameBuffer | None:
        if not self._buffer or self._emitted:
            return None
        self._emitted = True
        return FrameBuffer(
            width=self._width,
            height=self._height,
            data=self._buffer,
            duration_ms=0,
            is_final=True,
        )


# ── helpers (shared with gif_adapter) ─────────────────────────────────


def _load_to_rgba8(
    asset_path: str,
    *,
    target: tuple[int, int],
    fit: str,
    letterbox_rgb: tuple[int, int, int],
) -> bytes:
    """Open via Pillow, fit to ``target``, return RGBA8 bytes (w*h*4)."""
    with Image.open(asset_path) as src:
        rgba = src.convert("RGBA")
        target_w, target_h = target
        if fit in ("contain", "letterbox"):
            out = _fit_contain(rgba, target_w, target_h, letterbox_rgb)
        elif fit == "cover":
            out = _fit_cover(rgba, target_w, target_h)
        elif fit == "fill":
            out = rgba.resize((target_w, target_h), Image.LANCZOS)
        else:
            out = _fit_contain(rgba, target_w, target_h, letterbox_rgb)
        return out.tobytes()


def _fit_contain(
    img: Image.Image,
    target_w: int,
    target_h: int,
    bg_rgb: tuple[int, int, int],
) -> Image.Image:
    """Aspect-preserving fit inside target; pad edges with ``bg_rgb``."""
    src_w, src_h = img.size
    scale = min(target_w / src_w, target_h / src_h)
    new_w = max(1, int(round(src_w * scale)))
    new_h = max(1, int(round(src_h * scale)))
    resized = img.resize((new_w, new_h), Image.LANCZOS)
    canvas = Image.new("RGBA", (target_w, target_h), (*bg_rgb[:3], 255))
    canvas.paste(resized, ((target_w - new_w) // 2, (target_h - new_h) // 2), resized)
    return canvas


def _fit_cover(img: Image.Image, target_w: int, target_h: int) -> Image.Image:
    """Aspect-preserving fill; crop overflow."""
    src_w, src_h = img.size
    scale = max(target_w / src_w, target_h / src_h)
    new_w = max(1, int(round(src_w * scale)))
    new_h = max(1, int(round(src_h * scale)))
    resized = img.resize((new_w, new_h), Image.LANCZOS)
    crop_x = (new_w - target_w) // 2
    crop_y = (new_h - target_h) // 2
    return resized.crop((crop_x, crop_y, crop_x + target_w, crop_y + target_h))
