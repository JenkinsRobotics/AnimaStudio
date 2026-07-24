"""SpriteAdapter — L2 sprite-sheet cell, centred on the canvas.

Ported from Mochi (`mochi/nodes/media/decoders/sprite_adapter.py`, Apache-2.0):
crop one source rect from a sheet, centre it, emit RGBA8. Mochi selects the cell
with an explicit ``src`` rect (still supported, for Mscript). AnimaStudio adds a
grid path — ``columns``/``rows`` + a current ``index`` (the ``frame_index`` that
``canvas2d.evaluate_surfaces`` resolves) — and ``set_index`` so a driver can walk
the sheet frame-by-frame without re-opening.
"""

from __future__ import annotations

from PIL import Image

from animacore.raster.frame import FrameBuffer


class SpriteAdapter:
    """Crop one sprite from a sheet and emit it as a held frame."""

    def __init__(self) -> None:
        self._sheet: Image.Image | None = None
        self._width = 0
        self._height = 0
        self._bg_rgb: tuple[int, int, int] = (0, 0, 0)
        self._explicit_src: tuple[int, int, int, int] | None = None
        self._columns = 1
        self._rows = 1
        self._index = 0

    def open(self, asset_path: str, *, width: int, height: int, params: dict) -> None:
        """Load the sheet; select the first cell.

        ``params``: ``src`` = (x, y, w, h) explicit crop (list/tuple/"x,y,w,h"),
        OR ``columns``/``rows`` grid + ``index`` (default 0); ``bg_rgb`` canvas fill.
        """
        p = dict(params or {})
        self._width = max(1, int(width))
        self._height = max(1, int(height))
        self._bg_rgb = tuple(p.get("bg_rgb", (0, 0, 0)))
        self._explicit_src = _coerce_src(p.get("src"))
        self._columns = max(1, int(p.get("columns", 1)))
        self._rows = max(1, int(p.get("rows", 1)))
        self._index = max(0, int(p.get("index", 0)))
        self._sheet = Image.open(asset_path).convert("RGBA")
        self._sheet.load()  # detach from the file handle

    def set_index(self, index: int) -> None:
        """Select which grid cell ``next_frame`` renders (ignored if ``src`` set)."""
        self._index = max(0, int(index))

    def close(self) -> None:
        if self._sheet is not None:
            self._sheet.close()
            self._sheet = None

    def next_frame(self, t: float) -> FrameBuffer | None:
        if self._sheet is None:
            return None
        sx, sy, sw, sh = self._current_src()
        cropped = self._sheet.crop((sx, sy, sx + sw, sy + sh))
        data = _composite_centred(cropped, self._width, self._height, self._bg_rgb)
        return FrameBuffer(
            width=self._width, height=self._height, data=data, duration_ms=0
        )

    def _current_src(self) -> tuple[int, int, int, int]:
        if self._explicit_src is not None:
            return self._explicit_src
        sheet_w, sheet_h = self._sheet.size
        cell_w = sheet_w // self._columns
        cell_h = sheet_h // self._rows
        count = self._columns * self._rows
        index = self._index % count if count else 0
        col = index % self._columns
        row = index // self._columns
        return (col * cell_w, row * cell_h, cell_w, cell_h)


def _coerce_src(value) -> tuple[int, int, int, int] | None:
    """Accept an (x, y, w, h) rect as list/tuple or "x,y,w,h" string."""
    if value is None:
        return None
    if isinstance(value, str):
        try:
            parts = [int(s.strip()) for s in value.split(",")]
        except (ValueError, AttributeError):
            return None
        return tuple(parts) if len(parts) == 4 else None  # type: ignore[return-value]
    if isinstance(value, (list, tuple)) and len(value) == 4:
        return (int(value[0]), int(value[1]), int(value[2]), int(value[3]))
    return None


def _composite_centred(
    sprite: Image.Image,
    canvas_w: int,
    canvas_h: int,
    bg_rgb: tuple[int, int, int],
) -> bytes:
    canvas = Image.new("RGBA", (canvas_w, canvas_h), (*bg_rgb[:3], 255))
    sx = (canvas_w - sprite.width) // 2
    sy = (canvas_h - sprite.height) // 2
    canvas.paste(sprite, (sx, sy), sprite)
    return canvas.tobytes()
