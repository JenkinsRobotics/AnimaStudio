"""Skins — load meta.yaml, screen_bbox validation, round-trip, compositing."""

from __future__ import annotations

import pytest

from animacore.raster.frame import FrameBuffer
from animacore.raster.skin_compositor import apply_skin
from animacore.skin import Skin, load_skin, skin_from_mapping, skin_to_mapping

_SKIN = """
schema: skin/v1
id: tv1
name: TV 1
screen_bbox: [425, 289, 150, 150]
topmost: true
opacity: 0.9
"""


def test_load_skin(tmp_path):
    directory = tmp_path / "tv1"
    directory.mkdir()
    (directory / "meta.yaml").write_text(_SKIN)
    skin = load_skin(directory)
    assert skin.id == "tv1"
    assert skin.screen_bbox == (425, 289, 150, 150)
    assert skin.opacity == 0.9


def test_id_defaults_to_folder(tmp_path):
    directory = tmp_path / "crt"
    directory.mkdir()
    (directory / "meta.yaml").write_text("schema: skin/v1\nscreen_bbox: [0, 0, 64, 64]\n")
    assert load_skin(directory).id == "crt"


def test_rejects_bad_bbox():
    with pytest.raises(ValueError):
        Skin(id="s", screen_bbox=(0, 0, 0, 10))


def test_mapping_roundtrip():
    skin = Skin(id="s", screen_bbox=(1, 2, 3, 4), name="S")
    restored = skin_from_mapping(skin_to_mapping(skin))
    assert restored.screen_bbox == (1, 2, 3, 4) and restored.name == "S"


def test_apply_skin_paints_frame_into_cutout(tmp_path):
    from PIL import Image

    directory = tmp_path / "skin"
    directory.mkdir()
    body = Image.new("RGBA", (40, 40), (255, 0, 0, 255))  # red bezel
    for y in range(10, 30):
        for x in range(10, 30):
            body.putpixel((x, y), (0, 0, 0, 0))  # transparent 20x20 cutout at (10,10)
    body.save(directory / "body.png")

    skin = Skin(id="s", screen_bbox=(10, 10, 20, 20))
    frame = FrameBuffer.blank(20, 20, (0, 255, 0, 255))  # green screen content
    out = apply_skin(frame, skin, directory)

    assert out.width == 40 and out.height == 40

    def pixel(x, y):
        i = (y * 40 + x) * 4
        return tuple(out.data[i : i + 3])

    assert pixel(20, 20) == (0, 255, 0)  # cutout reveals the green frame
    assert pixel(2, 2) == (255, 0, 0)  # bezel stays red
