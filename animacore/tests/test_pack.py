"""Packs — load, slot resolution (str/list/dict), validation, round-trip."""

from __future__ import annotations

import pytest

from animacore.pack import (
    Pack,
    load_pack,
    pack_from_mapping,
    pack_to_mapping,
    slot_asset_path,
    slot_file,
)

_PACK = """
schema: pack/v1
id: eye_default
name: Default Eyes
default_adapter: image
slots:
  idle: neutral.json
  happy: [happy_a.json, happy_b.json]
  look: {file: look.json, loop: true}
default_slot: idle
preview_slot: happy
tags: [eyes, minimalist]
"""


def _pack_dir(tmp_path):
    directory = tmp_path / "eye_default"
    directory.mkdir()
    (directory / "pack.yaml").write_text(_PACK)
    return directory


def test_load_and_resolve_slots(tmp_path):
    directory = _pack_dir(tmp_path)
    pack = load_pack(directory)
    assert pack.id == "eye_default" and pack.default_slot == "idle"
    assert slot_file(pack, "idle") == "neutral.json"
    assert slot_file(pack, "happy") == "happy_a.json"  # first of a list
    assert slot_file(pack, "look") == "look.json"  # dict form
    assert slot_file(pack, "missing") is None
    assert slot_asset_path(pack, "idle", directory) == directory / "neutral.json"


def test_id_defaults_to_folder(tmp_path):
    directory = tmp_path / "combat"
    directory.mkdir()
    (directory / "pack.yaml").write_text("schema: pack/v1\nslots:\n  idle: i.gif\ndefault_slot: idle\n")
    assert load_pack(directory).id == "combat"


def test_rejects_default_slot_not_in_slots():
    with pytest.raises(ValueError):
        Pack(id="p", slots={"idle": "i"}, default_slot="nope")


def test_mapping_roundtrip():
    pack = Pack(id="p", slots={"idle": "i.gif"}, default_slot="idle", tags=("a",))
    restored = pack_from_mapping(pack_to_mapping(pack))
    assert restored.id == "p" and restored.default_slot == "idle" and restored.tags == ("a",)
