"""Asset catalog — index a media folder + JSON round-trip."""

from __future__ import annotations

from animacore.asset_catalog import build_catalog, catalog_from_json, catalog_to_json
from animacore.asset_props import AssetProps, write_props


def test_build_catalog_indexes_and_relativizes(tmp_path):
    (tmp_path / "a.png").write_bytes(b"x")
    (tmp_path / "sub").mkdir()
    (tmp_path / "sub" / "b.gif").write_bytes(b"x")
    write_props(tmp_path / "a.png", AssetProps(name="Alpha", mood="calm"))

    entries = build_catalog(tmp_path)
    by_path = {e.path: e for e in entries}
    assert by_path["a.png"].name == "Alpha" and by_path["a.png"].kind == "image"
    assert "sub/b.gif" in by_path and by_path["sub/b.gif"].kind == "gif"


def test_catalog_skips_indexes_and_sidecars(tmp_path):
    (tmp_path / "a.png").write_bytes(b"x")
    write_props(tmp_path / "a.png", AssetProps(name="A"))
    (tmp_path / "CATALOG.json").write_text("[]")
    entries = build_catalog(tmp_path)
    assert [e.path for e in entries] == ["a.png"]


def test_catalog_json_roundtrip(tmp_path):
    (tmp_path / "a.png").write_bytes(b"x")
    write_props(tmp_path / "a.png", AssetProps(name="A", mood="calm", tags=("x",)))
    entries = build_catalog(tmp_path)
    restored = catalog_from_json(catalog_to_json(entries))
    assert restored[0].name == "A" and restored[0].kind == "image"
    assert restored[0].props.mood == "calm" and restored[0].props.tags == ("x",)
