"""Mscript engine — parse + step a real .mscript, incl. auto GIF duration."""

from __future__ import annotations

from animacore.raster.mscript import Command, MscriptScript, collect_commands

_SCRIPT = """\
[Header start]
! a greeting sequence
[Header end]
[Resources start]
K[1]: 'flash.gif'
K[2]: 'still.png'
[Resources end]
[Main start]
MEDIA K[2] FG[255,0,0]
WAIT D[0.5]
MEDIA K[1] D[auto]
MEDIA K[2] D[0.2]
[Main end]
"""


def _write_script(tmp_path, body=_SCRIPT):
    path = tmp_path / "greet.mscript"
    path.write_text(body)
    return str(path)


def _make_gif(tmp_path, frames=3, duration=100):
    from PIL import Image

    imgs = [Image.new("RGB", (8, 8), (i * 20, 0, 0)) for i in range(frames)]
    path = tmp_path / "flash.gif"
    imgs[0].save(path, save_all=True, append_images=imgs[1:], duration=duration, loop=0)
    return path


def test_parse_resources_and_colors(tmp_path):
    script = MscriptScript(_write_script(tmp_path))
    # First command fires at t=0: MEDIA K[2], color parsed to an int list, path resolved.
    commands = script.update(0.0)
    assert commands[0].name == "MEDIA"
    assert commands[0].args["FG"] == [255, 0, 0]
    assert commands[0].args["asset_path"].endswith("still.png")


def test_wait_flow_control(tmp_path):
    _make_gif(tmp_path)  # so K[1] D[auto] resolves to a real length (0.3s)
    script = MscriptScript(_write_script(tmp_path))
    timeline = collect_commands(script, until=1.2, step=0.05)
    times = [round(t, 2) for t, _ in timeline]
    names = [c.name for _, c in timeline]

    # First MEDIA at t=0, then WAIT holds until 0.5, then the gif MEDIA fires.
    assert names[0] == "MEDIA" and times[0] == 0.0
    assert times[1] >= 0.5  # WAIT[0.5] gated the second command
    assert names.count("MEDIA") == 3  # all three MEDIA commands eventually run
    assert script.finished


def test_auto_duration_reads_gif_length(tmp_path):
    _make_gif(tmp_path, frames=3, duration=100)  # 0.3s total
    script = MscriptScript(_write_script(tmp_path))
    # Step past the first MEDIA + WAIT to reach the gif command.
    script.update(0.0)
    script.update(0.5)  # gif MEDIA fires here; D[auto] -> ~0.3s hold
    # The 4th command (MEDIA K[2] D[0.2]) must wait ~0.3s for the gif.
    assert script.update(0.6) == []  # still holding on the gif's auto duration
    later = script.update(0.85)  # 0.5 + 0.3 elapsed -> released
    assert later and later[0].args["asset_path"].endswith("still.png")


def test_command_is_named_tuple():
    command = Command("MEDIA", {"asset_path": "x.png"})
    assert command.name == "MEDIA" and command.args["asset_path"] == "x.png"
