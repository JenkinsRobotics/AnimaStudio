"""Mscript media-runner — a .mscript's MEDIA commands play into real frames."""

from __future__ import annotations

from animacore.raster.mscript import MscriptScript
from animacore.raster.mscript_runner import MscriptRunner, render_mscript


def _make_gif(tmp_path):
    from PIL import Image

    frames = [Image.new("RGB", (16, 16), (200, 0, 0)), Image.new("RGB", (16, 16), (0, 0, 200))]
    path = tmp_path / "flash.gif"
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=100, loop=0)
    return path


def _make_script(tmp_path):
    _make_gif(tmp_path)
    script = tmp_path / "s.mscript"
    script.write_text(
        "[Resources start]\n"
        "K[1]: 'flash.gif'\n"
        "[Resources end]\n"
        "[Main start]\n"
        "MEDIA K[1]\n"
        "[Main end]\n"
    )
    return script


def _center(frame):
    i = (8 * frame.width + 8) * 4
    return tuple(frame.data[i : i + 3])


def test_runner_plays_the_active_media(tmp_path):
    script = _make_script(tmp_path)
    with MscriptRunner(MscriptScript(str(script)), width=16, height=16) as runner:
        first = runner.frame_at(0.0)
        assert first is not None and first.width == 16
        assert _center(first) == (200, 0, 0)  # gif frame 0 is red
        later = runner.frame_at(0.15)  # into the 2nd 100ms gif frame
        assert _center(later) == (0, 0, 200)


def test_render_mscript_collects_frames(tmp_path):
    script = _make_script(tmp_path)
    frames = render_mscript(script, until=0.4, fps=10, width=16, height=16)
    assert len(frames) >= 2
    assert all(f.width == 16 for f in frames)
