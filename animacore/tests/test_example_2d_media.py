"""The imported Mochi test media renders through the example 2D characters."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from animacore.canvas2d_io import parse_canvas2d
from animacore.raster import render_canvas

_ROOT = Path(__file__).resolve().parents[2]
_ASSETS = _ROOT / "examples" / "assets" / "2d"


def _distinct_rgb(frame) -> set[tuple[int, int, int]]:
    data = frame.data
    return {(data[i], data[i + 1], data[i + 2]) for i in range(0, len(data), 4)}


def test_catalog_lists_every_media_kind():
    entries = json.loads((_ASSETS / "CATALOG.json").read_text())
    assert len(entries) > 50  # the full imported Mochi media library
    assert {"bitmap", "gif", "image", "video"} <= {entry["kind"] for entry in entries}


@pytest.mark.parametrize("name", ["pixel_pet_2d", "dino_screen_2d"])
def test_example_character_renders_imported_media(name, monkeypatch):
    monkeypatch.chdir(_ROOT)  # asset paths in the files are repo-root-relative
    canvas = parse_canvas2d((_ROOT / "examples" / f"{name}.character.anima").read_text())
    assert canvas is not None
    frame = render_canvas(canvas, {}, time_seconds=0.0)
    assert frame.width == 64 and frame.height == 64
    assert len(_distinct_rgb(frame)) > 3  # real decoded media, not a flat fill


def test_pixel_pet_composites_face_over_the_image(monkeypatch):
    monkeypatch.chdir(_ROOT)
    canvas = parse_canvas2d((_ROOT / "examples" / "pixel_pet_2d.character.anima").read_text())
    frame = render_canvas(canvas, {}, time_seconds=1.0)
    colors = _distinct_rgb(frame)
    assert (120, 230, 255) in colors  # the procedural face features show on top
    assert len(colors) > 8  # ...and the colorwheel image shows through the faint face bg
