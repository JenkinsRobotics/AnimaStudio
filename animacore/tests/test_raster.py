"""Real media pipeline: decode actual PNG/GIF/sprite/bitmap/video -> pixels.

These tests generate real assets (via Pillow / imageio) and push them through the
ported decoders, so they exercise the working decode path, not a stub.
"""

from __future__ import annotations

import json

import numpy as np
import pytest

from animacore.canvas2d import Canvas2D, SourceKind, Surface, VisualSource
from animacore.frame_output import LedMatrixTarget, SimulatorFrameOutput, downsample_canvas
from animacore.raster import CanvasPlayer, FrameBuffer, default_registry, render_canvas
from animacore.raster.bitmap_adapter import BitmapAdapter
from animacore.raster.gif_adapter import GifAdapter
from animacore.raster.image_adapter import ImageAdapter
from animacore.raster.procedural import ProceduralAdapter, default_faces
from animacore.raster.sprite_adapter import SpriteAdapter
from animacore.raster.video_adapter import VideoAdapter


def _pixel(frame: FrameBuffer, x: int, y: int) -> tuple[int, int, int, int]:
    i = (y * frame.width + x) * 4
    return tuple(frame.data[i : i + 4])  # type: ignore[return-value]


def _count_rgb(frame: FrameBuffer, rgb: tuple[int, int, int]) -> int:
    d = frame.data
    return sum(
        1
        for p in range(0, len(d), 4)
        if (d[p], d[p + 1], d[p + 2]) == rgb
    )


# ── fixture builders (real files) ─────────────────────────────────────


def _make_png(path, color, size=(16, 16)):
    from PIL import Image

    Image.new("RGB", size, color).save(path)
    return str(path)


def _make_gif(path, colors, size=(16, 16), duration=100):
    from PIL import Image

    frames = [Image.new("RGB", size, c) for c in colors]
    frames[0].save(
        path, save_all=True, append_images=frames[1:], duration=duration, loop=0
    )
    return str(path)


def _make_sheet(path, cells, cell=(16, 16)):
    from PIL import Image

    sheet = Image.new("RGBA", (cell[0] * len(cells), cell[1]))
    for i, color in enumerate(cells):
        sheet.paste(Image.new("RGBA", cell, (*color, 255)), (i * cell[0], 0))
    sheet.save(path)
    return str(path)


def _make_bitmap_json(path, width=8, height=8, on=True):
    row = 0xFF if on else 0x00
    path.write_text(json.dumps({"width": width, "height": height, "data": [row] * height}))
    return str(path)


# ── FrameBuffer ───────────────────────────────────────────────────────


def test_framebuffer_validates_byte_length():
    with pytest.raises(ValueError):
        FrameBuffer(width=2, height=2, data=b"\x00")


def test_framebuffer_blank_and_rgb_rows():
    frame = FrameBuffer.blank(3, 2, (10, 20, 30, 255))
    rows = frame.to_rgb_rows()
    assert len(rows) == 2 and len(rows[0]) == 3
    assert rows[0][0] == (10, 20, 30)


def test_framebuffer_pil_roundtrip():
    frame = FrameBuffer.blank(4, 4, (200, 100, 50, 255))
    back = FrameBuffer.from_pil(frame.to_pil())
    assert back.data == frame.data


# ── real decoders ─────────────────────────────────────────────────────


def test_image_adapter_decodes_real_png(tmp_path):
    asset = _make_png(tmp_path / "green.png", (0, 200, 0))
    adapter = ImageAdapter()
    adapter.open(asset, width=16, height=16, params={"fit": "fill"})
    frame = adapter.next_frame(0.0)
    assert frame is not None and frame.width == 16
    assert _pixel(frame, 8, 8) == (0, 200, 0, 255)
    assert adapter.next_frame(0.1) is None  # held frame, one-shot


def test_gif_adapter_walks_real_frames(tmp_path):
    asset = _make_gif(tmp_path / "flash.gif", [(200, 0, 0), (0, 0, 200)], duration=100)
    adapter = GifAdapter()
    adapter.open(asset, width=16, height=16, params={"fit": "fill", "loop": True})
    first = adapter.next_frame(0.0)
    second = adapter.next_frame(0.15)  # into the 2nd 100ms frame
    assert _pixel(first, 8, 8) == (200, 0, 0, 255)
    assert _pixel(second, 8, 8) == (0, 0, 200, 255)
    # 250ms % 200ms total = 50ms -> back to frame 0 (proves it loops)
    assert _pixel(adapter.next_frame(0.25), 8, 8) == (200, 0, 0, 255)


def test_sprite_adapter_indexes_real_sheet(tmp_path):
    asset = _make_sheet(tmp_path / "sheet.png", [(200, 0, 0), (0, 0, 200)])
    adapter = SpriteAdapter()
    adapter.open(asset, width=16, height=16, params={"columns": 2, "rows": 1, "index": 0})
    assert _pixel(adapter.next_frame(0.0), 8, 8) == (200, 0, 0, 255)
    adapter.set_index(1)
    assert _pixel(adapter.next_frame(0.0), 8, 8) == (0, 0, 200, 255)


def test_bitmap_adapter_renders_real_json(tmp_path):
    asset = _make_bitmap_json(tmp_path / "bmp.json", 8, 8, on=True)
    adapter = BitmapAdapter()
    adapter.open(asset, width=8, height=8, params={"fg_rgb": (255, 0, 0), "bg_rgb": (0, 0, 0)})
    frame = adapter.next_frame(0.0)
    assert _pixel(frame, 4, 4) == (255, 0, 0, 255)  # ON pixel takes fg


def test_video_adapter_decodes_real_mp4(tmp_path):
    imageio = pytest.importorskip("imageio")
    pytest.importorskip("imageio_ffmpeg")
    frames = [np.full((16, 16, 3), (200, 0, 0), np.uint8) for _ in range(3)]
    frames += [np.full((16, 16, 3), (0, 0, 200), np.uint8) for _ in range(3)]
    asset = str(tmp_path / "clip.mp4")
    try:
        imageio.mimwrite(asset, frames, fps=10, macro_block_size=1)
    except Exception:  # noqa: BLE001 — no encoder available in this env
        pytest.skip("no ffmpeg encoder available")
    adapter = VideoAdapter()
    adapter.open(asset, width=16, height=16, params={"loop": True})
    frame = adapter.next_frame(0.0)
    assert frame is not None and frame.width == 16
    adapter.close()


def test_procedural_adapter_drives_face(tmp_path):
    adapter = ProceduralAdapter(default_faces())
    adapter.open("simple", width=32, height=32, params={})
    adapter.set_params({"mouth_open": 0.0})
    shut = adapter.next_frame(1.0)
    adapter.set_params({"mouth_open": 1.0})
    wide = adapter.next_frame(1.0)
    feature = (120, 230, 255)
    assert _count_rgb(wide, feature) > _count_rgb(shut, feature)


def test_procedural_adapter_unknown_face_raises():
    adapter = ProceduralAdapter(default_faces())
    with pytest.raises(KeyError):
        adapter.open("nope", width=8, height=8, params={})


# ── registry ──────────────────────────────────────────────────────────


def test_registry_creates_every_kind():
    registry = default_registry()
    for kind in (SourceKind.IMAGE, SourceKind.BITMAP, SourceKind.SPRITE, SourceKind.GIF,
                 SourceKind.VIDEO, SourceKind.PROCEDURAL):
        assert kind in registry
        assert registry.create(kind) is not None


# ── CanvasPlayer / render_canvas ──────────────────────────────────────


def _procedural_canvas(width=48, height=48) -> Canvas2D:
    return Canvas2D(
        width=width,
        height=height,
        sources={"face": VisualSource(id="face", kind=SourceKind.PROCEDURAL, asset="simple")},
        surfaces=(Surface(id="face", source="face"),),
    )


def test_render_canvas_composites_face():
    frame = render_canvas(_procedural_canvas(), {}, time_seconds=1.0)
    assert frame.width == 48 and frame.height == 48
    assert _count_rgb(frame, (120, 230, 255)) > 0


def test_player_composites_image_under_face(tmp_path):
    asset = _make_png(tmp_path / "bg.png", (30, 30, 30), size=(48, 48))
    canvas = Canvas2D(
        width=48,
        height=48,
        sources={
            "bg": VisualSource(id="bg", kind=SourceKind.IMAGE, asset=asset),
            "face": VisualSource(id="face", kind=SourceKind.PROCEDURAL, asset="simple"),
        },
        surfaces=(
            Surface(id="bg", source="bg", z=0),
            Surface(id="face", source="face", z=10),
        ),
    )
    with CanvasPlayer(canvas) as player:
        frame = player.frame({"mouth_open": 1.0}, time_seconds=1.0)
    assert frame.width == 48
    assert _count_rgb(frame, (120, 230, 255)) > 0  # face features present over the bg


def test_render_canvas_raises_for_unregistered_kind():
    from animacore.raster.base import AdapterRegistry

    canvas = _procedural_canvas()
    with pytest.raises(KeyError):
        render_canvas(canvas, registry=AdapterRegistry())  # empty registry


# ── end to end -> LED matrix ──────────────────────────────────────────


def test_end_to_end_face_to_matrix():
    node = SimulatorFrameOutput(target=LedMatrixTarget(width=16, height=16))
    node.open()
    frame = render_canvas(_procedural_canvas(width=128, height=128), {}, time_seconds=1.0)
    node.send_frame(frame.to_rgb_rows(), sequence=1)
    assert len(node.last_frame) == 16 and len(node.last_frame[0]) == 16


def test_rgb_rows_feed_downsample():
    frame = render_canvas(_procedural_canvas(width=64, height=64), {}, time_seconds=1.0)
    matrix = downsample_canvas(frame.to_rgb_rows(), LedMatrixTarget(width=8, height=8))
    assert len(matrix) == 8 and len(matrix[0]) == 8
