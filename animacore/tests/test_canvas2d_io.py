"""canvas2d I/O — the `canvas2d:` block round-trips through a .character.anima."""

from __future__ import annotations

from pathlib import Path

import pytest

from animacore.canvas2d import Canvas2D, SourceKind, Surface, SurfaceDriver, SurfaceProperty, VisualSource
from animacore.canvas2d_io import (
    canvas2d_from_mapping,
    canvas2d_to_mapping,
    canvas2d_to_yaml,
    parse_canvas2d,
)
from animacore.loader import load_character_file, parse_character

_EXAMPLE = Path(__file__).resolve().parents[2] / "examples" / "pixel_face_2d.character.anima"
_RIG_EXAMPLE = Path(__file__).resolve().parents[2] / "examples" / "pan_tilt_head.character.anima"


def _canvas() -> Canvas2D:
    return Canvas2D(
        width=64,
        height=64,
        sources={
            "face": VisualSource(id="face", kind=SourceKind.PROCEDURAL, asset="simple"),
            "bg": VisualSource(id="bg", kind=SourceKind.GIF, asset="bg.gif", frame_count=3, fps=10.0),
        },
        surfaces=(
            Surface(id="bg", source="bg", z=0),
            Surface(
                id="face",
                source="face",
                z=10,
                drivers=(SurfaceDriver(property=SurfaceProperty.OPACITY, source="fade"),),
            ),
        ),
    )


def test_mapping_roundtrip_preserves_everything():
    original = _canvas()
    rebuilt = canvas2d_from_mapping(canvas2d_to_mapping(original))
    assert canvas2d_to_mapping(rebuilt) == canvas2d_to_mapping(original)


def test_yaml_roundtrip():
    original = _canvas()
    rebuilt = parse_canvas2d(canvas2d_to_yaml(original))
    assert rebuilt is not None
    assert canvas2d_to_mapping(rebuilt) == canvas2d_to_mapping(original)


def test_parse_example_2d_character():
    canvas = parse_canvas2d(_EXAMPLE.read_text())
    assert canvas is not None
    assert canvas.width == 64 and canvas.height == 64
    assert canvas.sources["face"].kind is SourceKind.PROCEDURAL
    assert canvas.surfaces[0].drivers[0].source == "fade"


def test_rig_only_character_has_no_canvas():
    assert parse_canvas2d(_RIG_EXAMPLE.read_text()) is None


def test_loader_accepts_canvas2d_block():
    # The rig loader tolerates the canvas2d block (a pure-2D character has empty
    # mechanics but still loads as a Rig).
    rig = load_character_file(_EXAMPLE)
    assert rig.identity.name == "pixel_face"
    assert rig.parts == {}


def test_loader_still_reads_rig_only_character():
    rig = parse_character(_RIG_EXAMPLE.read_text())
    assert len(rig.parts) >= 1


def test_malformed_block_raises():
    with pytest.raises(ValueError):
        parse_canvas2d("canvas2d:\n  surfaces:\n    - id: s\n      source: missing\n")
