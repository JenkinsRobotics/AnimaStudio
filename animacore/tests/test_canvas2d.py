"""Tests for the 2D visual-character model (renderer-neutral evaluation)."""

from __future__ import annotations

import pytest

from animacore.canvas2d import (
    Canvas2D,
    Surface,
    SurfaceDriver,
    SurfaceProperty,
    SourceKind,
    VisualSource,
    evaluate_surfaces,
)


def _sprite(frame_count: int = 4, columns: int = 2, rows: int = 2) -> VisualSource:
    return VisualSource(
        id="mouth",
        kind=SourceKind.SPRITE,
        asset="assets/mouth.png",
        frame_count=frame_count,
        columns=columns,
        rows=rows,
    )


# VisualSource -----------------------------------------------------------------


def test_image_pins_frame_zero():
    image = VisualSource(id="bg", kind=SourceKind.IMAGE)
    assert image.frame_from_unit(0.0) == 0
    assert image.frame_from_unit(1.0) == 0
    assert image.frame_at_time(5.0) == 0


def test_image_rejects_multiple_frames():
    with pytest.raises(ValueError):
        VisualSource(id="bg", kind=SourceKind.IMAGE, frame_count=3)


def test_sprite_frame_from_unit_walks_every_frame():
    sprite = _sprite(frame_count=4)
    assert sprite.frame_from_unit(0.0) == 0
    assert sprite.frame_from_unit(0.25) == 1
    assert sprite.frame_from_unit(0.5) == 2
    assert sprite.frame_from_unit(0.99) == 3
    assert sprite.frame_from_unit(1.0) == 3  # 1.0 lands on the last frame
    assert sprite.frame_from_unit(-1.0) == 0  # clamped


def test_sprite_atlas_cell():
    sprite = _sprite(frame_count=4, columns=2, rows=2)
    assert sprite.atlas_cell(0) == (0, 0)
    assert sprite.atlas_cell(1) == (1, 0)
    assert sprite.atlas_cell(2) == (0, 1)
    assert sprite.atlas_cell(3) == (1, 1)


def test_gif_clock_loops():
    gif = VisualSource(id="loop", kind=SourceKind.GIF, frame_count=3, fps=10.0)
    assert gif.frame_at_time(0.0) == 0
    assert gif.frame_at_time(0.15) == 1  # 1.5 frames -> index 1
    assert gif.frame_at_time(0.35) == 0  # 3.5 -> 3 % 3 == 0 (looped)


def test_gif_clock_no_loop_holds_last():
    gif = VisualSource(
        id="once", kind=SourceKind.GIF, frame_count=3, fps=10.0, loop=False
    )
    assert gif.frame_at_time(10.0) == 2


def test_zero_fps_pins_frame_zero():
    video = VisualSource(id="v", kind=SourceKind.VIDEO, frame_count=30, fps=0.0)
    assert video.frame_at_time(5.0) == 0


# SurfaceDriver ----------------------------------------------------------------


def test_driver_linear_remap_and_clamp():
    driver = SurfaceDriver(
        property=SurfaceProperty.ROTATION,
        source="head.pan",
        input_at_zero=-1.0,
        input_at_one=1.0,
        output_at_zero=-30.0,
        output_at_one=30.0,
    )
    assert driver.resolve(-1.0) == -30.0
    assert driver.resolve(0.0) == 0.0
    assert driver.resolve(1.0) == 30.0
    assert driver.resolve(5.0) == 30.0  # clamped at the input top


def test_driver_zero_input_span_rejected():
    with pytest.raises(ValueError):
        SurfaceDriver(
            property=SurfaceProperty.OPACITY,
            source="x",
            input_at_zero=1.0,
            input_at_one=1.0,
        )


# Canvas2D validation ----------------------------------------------------------


def test_canvas_rejects_unknown_source():
    with pytest.raises(ValueError):
        Canvas2D(surfaces=(Surface(id="s", source="missing"),))


def test_canvas_rejects_duplicate_surface_id():
    sprite = _sprite()
    with pytest.raises(ValueError):
        Canvas2D(
            sources={"mouth": sprite},
            surfaces=(
                Surface(id="dup", source="mouth"),
                Surface(id="dup", source="mouth"),
            ),
        )


# evaluate_surfaces ------------------------------------------------------------


def _face_canvas() -> Canvas2D:
    mouth = _sprite(frame_count=4)
    return Canvas2D(
        width=512,
        height=512,
        sources={"mouth": mouth},
        surfaces=(
            Surface(
                id="mouth",
                source="mouth",
                drivers=(
                    SurfaceDriver(property=SurfaceProperty.FRAME, source="viseme"),
                    SurfaceDriver(property=SurfaceProperty.OPACITY, source="fade"),
                ),
            ),
        ),
    )


def test_frame_driver_selects_sprite_frame():
    canvas = _face_canvas()
    state = evaluate_surfaces(canvas, {"viseme": 0.5})[0]
    assert state.frame_index == 2  # 0.5 over 4 frames -> index 2


def test_opacity_driver_applies_and_clamps():
    canvas = _face_canvas()
    state = evaluate_surfaces(canvas, {"fade": 0.25})[0]
    assert state.opacity == 0.25


def test_missing_driver_input_keeps_base_value():
    canvas = _face_canvas()
    # No "fade" supplied -> base opacity 1.0 is kept, not forced to 0.
    state = evaluate_surfaces(canvas, {"viseme": 0.0})[0]
    assert state.opacity == 1.0
    assert state.frame_index == 0


def test_clock_frame_when_no_frame_driver():
    gif = VisualSource(id="blink", kind=SourceKind.GIF, frame_count=3, fps=10.0)
    canvas = Canvas2D(
        sources={"blink": gif}, surfaces=(Surface(id="eye", source="blink"),)
    )
    state = evaluate_surfaces(canvas, {}, time_seconds=0.15)[0]
    assert state.frame_index == 1


def test_visible_driver_thresholds():
    sprite = _sprite()
    canvas = Canvas2D(
        sources={"mouth": sprite},
        surfaces=(
            Surface(
                id="mouth",
                source="mouth",
                drivers=(
                    SurfaceDriver(property=SurfaceProperty.VISIBLE, source="show"),
                ),
            ),
        ),
    )
    assert evaluate_surfaces(canvas, {"show": 0.9})[0].visible is True
    assert evaluate_surfaces(canvas, {"show": 0.1})[0].visible is False


def test_surfaces_ordered_back_to_front_by_z():
    sprite = _sprite()
    canvas = Canvas2D(
        sources={"mouth": sprite},
        surfaces=(
            Surface(id="front", source="mouth", z=10),
            Surface(id="back", source="mouth", z=0),
        ),
    )
    states = evaluate_surfaces(canvas, {})
    assert [state.id for state in states] == ["back", "front"]
