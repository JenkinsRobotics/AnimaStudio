"""Headless preview/export — renders real files (PNG / animated GIF / matrix)."""

from __future__ import annotations

from PIL import Image

from animacore.canvas2d import SourceKind
from animacore.raster.preview import (
    ascii_preview,
    face_canvas,
    media_canvas,
    render_gif,
    render_matrix_png,
    render_png,
)


def test_render_png_writes_image(tmp_path):
    out = render_png(face_canvas(64, 64), tmp_path / "face.png", {"mouth_open": 1.0}, 1.0)
    with Image.open(out) as img:
        assert img.size == (64, 64)


def test_render_gif_is_animated(tmp_path):
    out = render_gif(face_canvas(48, 48), tmp_path / "face.gif", duration_seconds=0.5, fps=10)
    with Image.open(out) as img:
        assert getattr(img, "n_frames", 1) >= 2  # multi-frame (exact count is encoder-deduped)


def test_render_matrix_png_upscales(tmp_path):
    from animacore.frame_output import LedMatrixTarget

    out = render_matrix_png(
        face_canvas(128, 128), tmp_path / "m.png", target=LedMatrixTarget(16, 16), scale=8
    )
    with Image.open(out) as img:
        assert img.size == (128, 128)  # 16 * 8


def test_ascii_preview_shape():
    art = ascii_preview(face_canvas(64, 64), cols=40, rows=10)
    lines = art.splitlines()
    assert len(lines) == 10 and all(len(line) == 40 for line in lines)


def test_media_canvas_infers_kind(tmp_path):
    Image.new("RGB", (16, 16), (0, 200, 0)).save(tmp_path / "x.png")
    canvas = media_canvas(str(tmp_path / "x.png"))
    assert canvas.sources["media"].kind is SourceKind.IMAGE
    gif_canvas = media_canvas("clip.gif")
    assert gif_canvas.sources["media"].kind is SourceKind.GIF
