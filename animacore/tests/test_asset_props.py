"""`.props.yaml` sidecars — round-trip + VisualSource derivation."""

from __future__ import annotations

from animacore.asset_props import (
    AssetProps,
    kind_for_asset,
    load_props,
    sidecar_path,
    visual_source_from_asset,
    write_props,
)
from animacore.canvas2d import SourceKind


def test_kind_inference():
    assert kind_for_asset("a.png") is SourceKind.IMAGE
    assert kind_for_asset("a.GIF") is SourceKind.GIF
    assert kind_for_asset("a.mp4") is SourceKind.VIDEO
    assert kind_for_asset("a.json") is SourceKind.BITMAP


def test_auto_props_when_no_sidecar(tmp_path):
    asset = tmp_path / "happy.gif"
    asset.write_bytes(b"x")
    props = load_props(asset)
    assert props.name == "happy" and props.loop is True and props.framing == "fit"


def test_sidecar_roundtrip(tmp_path):
    asset = tmp_path / "happy.gif"
    asset.write_bytes(b"x")
    write_props(
        asset,
        AssetProps(
            name="Happy Blink",
            mood="happy",
            tags=("eyes", "blink"),
            ideal_size=(64, 64),
            playback_speed=1.5,
            type_props={"fps": 24},
        ),
    )
    assert sidecar_path(asset).exists()
    loaded = load_props(asset)
    assert loaded.name == "Happy Blink"
    assert loaded.mood == "happy" and loaded.tags == ("eyes", "blink")
    assert loaded.ideal_size == (64, 64) and loaded.playback_speed == 1.5
    assert loaded.type_props["fps"] == 24


def test_visual_source_becomes_sprite_from_grid(tmp_path):
    asset = tmp_path / "walk.png"
    asset.write_bytes(b"x")
    source = visual_source_from_asset(
        "walk", asset, AssetProps(type_props={"grid": [4, 3], "frame_count": 12})
    )
    assert source.kind is SourceKind.SPRITE
    assert source.columns == 4 and source.rows == 3 and source.frame_count == 12


def test_visual_source_plain_image(tmp_path):
    asset = tmp_path / "bg.png"
    asset.write_bytes(b"x")
    source = visual_source_from_asset("bg", asset)
    assert source.kind is SourceKind.IMAGE and source.frame_count == 1
