"""FrameBuffer — the canonical RGBA8 frame every media adapter produces.

Ported from Mochi (`mochi/nodes/media/frames.py`, Apache-2.0): one rendered frame
is raw RGBA8 bytes, row-major, 4 bytes/pixel (``width * height * 4 == len(data)``).
Keeping Mochi's exact shape means its decoders drop in unchanged. AnimaStudio
adds the ``blank`` constructor, a Pillow bridge (``to_pil``/``from_pil``), and the
RGB-rows export that feeds ``frame_output.downsample_canvas`` for the LED matrix.
"""

from __future__ import annotations

from dataclasses import dataclass

from animacore.frame_output import RGB

RGBA = tuple[int, int, int, int]

__all__ = ["RGB", "RGBA", "FrameBuffer"]


@dataclass
class FrameBuffer:
    """One rendered frame. ``data`` is raw RGBA8 bytes (4 bytes/pixel)."""

    width: int
    height: int
    data: bytes  # RGBA8, width * height * 4 bytes
    duration_ms: int = 0  # how long this frame stays visible (pacing hint)
    is_final: bool = False  # last frame of a one-shot clip

    def __post_init__(self) -> None:
        expected = self.width * self.height * 4
        if len(self.data) != expected:
            raise ValueError(
                f"RGBA8 frame of {self.width}x{self.height} needs {expected} "
                f"bytes, got {len(self.data)}"
            )

    @classmethod
    def blank(cls, width: int, height: int, rgba: RGBA = (0, 0, 0, 255)) -> FrameBuffer:
        if width < 1 or height < 1:
            raise ValueError(f"frame size must be >= 1x1, got {width}x{height}")
        return cls(width, height, bytes(rgba) * (width * height))

    # ── Pillow bridge (the media layer depends on Pillow) ─────────────

    def to_pil(self):  # -> PIL.Image.Image
        from PIL import Image

        return Image.frombytes("RGBA", (self.width, self.height), self.data)

    @classmethod
    def from_pil(cls, image, *, duration_ms: int = 0, is_final: bool = False) -> FrameBuffer:
        rgba = image.convert("RGBA")
        return cls(rgba.width, rgba.height, rgba.tobytes(), duration_ms, is_final)

    # ── matrix boundary (stdlib only — no Pillow) ─────────────────────

    def to_rgb_rows(self, background: RGB = (0, 0, 0)) -> list[list[RGB]]:
        """Flatten to RGB rows, alpha-composited over ``background``.

        This is the seam into ``frame_output.downsample_canvas`` (and the real
        LED matrix): the composited canvas is opaque, so this is usually a plain
        alpha=255 copy. Pure stdlib so the matrix path never needs Pillow.
        """
        data = self.data
        width = self.width
        bg_r, bg_g, bg_b = background
        rows: list[list[RGB]] = []
        for y in range(self.height):
            base = y * width * 4
            row: list[RGB] = []
            for x in range(width):
                i = base + x * 4
                r, g, b, a = data[i], data[i + 1], data[i + 2], data[i + 3]
                if a == 255:
                    row.append((r, g, b))
                elif a == 0:
                    row.append(background)
                else:
                    t = a / 255.0
                    inv = 1.0 - t
                    row.append(
                        (
                            int(r * t + bg_r * inv),
                            int(g * t + bg_g * inv),
                            int(b * t + bg_b * inv),
                        )
                    )
            rows.append(row)
        return rows
