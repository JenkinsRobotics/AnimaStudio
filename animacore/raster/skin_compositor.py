"""Paint an evaluated frame into a device skin (bezel + screen cutout).

The pixel half of ``animacore.skin``: given a rendered ``FrameBuffer`` and a
``Skin``, resize the frame to the skin's ``screen_bbox`` and composite the bezel
(``body.png``, opaque artwork with a transparent screen cutout) on top — so the
frame shows through the cutout and the bezel frames it. Needs the ``media`` extra
(Pillow).
"""

from __future__ import annotations

from pathlib import Path

from animacore.raster.frame import FrameBuffer
from animacore.skin import Skin

__all__ = ["apply_skin"]


def apply_skin(frame: FrameBuffer, skin: Skin, skin_dir: str | Path) -> FrameBuffer:
    """Composite ``frame`` into ``skin``'s screen cutout; returns a body-sized frame."""
    from PIL import Image

    left, top, width, height = skin.screen_bbox
    body = Image.open(Path(skin_dir) / skin.body).convert("RGBA")
    screen = frame.to_pil()
    if (screen.width, screen.height) != (width, height):
        screen = screen.resize((width, height), Image.BILINEAR)
    canvas = Image.new("RGBA", body.size, (0, 0, 0, 0))
    canvas.paste(screen, (left, top))  # frame fills the screen region
    canvas.alpha_composite(body)  # bezel on top; its transparent cutout reveals the frame
    return FrameBuffer.from_pil(canvas)
