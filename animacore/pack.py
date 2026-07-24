"""Character/style packs (schema ``pack/v1``) — ported from Mochi's convention.

A pack = one character/style with a curated set of emotion/action **slots** that
map to asset files sharing its look. Browse by pack, then pick the slot; firing
``pack:slot`` resolves to an asset the renderer plays — the slot syntax is sugar,
the renderer never needs to know about packs. AnimaStudio authors packs (the
create side). Stdlib + pyyaml.
"""

from __future__ import annotations

from collections.abc import Mapping
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml

SCHEMA = "pack/v1"

__all__ = [
    "SCHEMA",
    "Pack",
    "load_pack",
    "pack_to_mapping",
    "pack_from_mapping",
    "slot_file",
    "slot_asset_path",
]


@dataclass(frozen=True)
class Pack:
    """A ``pack/v1`` manifest: slots mapping expression keys to asset files."""

    id: str
    name: str = ""
    author: str = ""
    license: str = ""
    description: str = ""
    default_adapter: str = "image"
    slots: Mapping[str, Any] = field(default_factory=dict)
    default_slot: str = ""
    preview_slot: str | None = None
    tags: tuple[str, ...] = ()

    def __post_init__(self) -> None:
        if not self.id:
            raise ValueError("pack id must be non-empty")
        if self.default_slot and self.default_slot not in self.slots:
            raise ValueError(f"default_slot {self.default_slot!r} is not a slot")
        if self.preview_slot and self.preview_slot not in self.slots:
            raise ValueError(f"preview_slot {self.preview_slot!r} is not a slot")


def pack_from_mapping(data: Mapping, *, fallback_id: str = "") -> Pack:
    return Pack(
        id=str(data.get("id", fallback_id)),
        name=str(data.get("name", "")),
        author=str(data.get("author", "")),
        license=str(data.get("license", "")),
        description=str(data.get("description", "")),
        default_adapter=str(data.get("default_adapter", "image")),
        slots=dict(data.get("slots", {}) or {}),
        default_slot=str(data.get("default_slot", "")),
        preview_slot=data.get("preview_slot"),
        tags=tuple(str(tag) for tag in data.get("tags", []) or []),
    )


def pack_to_mapping(pack: Pack) -> dict:
    mapping: dict[str, Any] = {"schema": SCHEMA, "id": pack.id}
    for key in ("name", "author", "license", "description"):
        value = getattr(pack, key)
        if value:
            mapping[key] = value
    mapping["default_adapter"] = pack.default_adapter
    mapping["slots"] = dict(pack.slots)
    if pack.default_slot:
        mapping["default_slot"] = pack.default_slot
    if pack.preview_slot:
        mapping["preview_slot"] = pack.preview_slot
    if pack.tags:
        mapping["tags"] = list(pack.tags)
    return mapping


def load_pack(pack_dir: str | Path) -> Pack:
    """Read ``<pack_dir>/pack.yaml``; the id defaults to the folder name."""
    pack_dir = Path(pack_dir)
    manifest = pack_dir / "pack.yaml"
    data = yaml.safe_load(manifest.read_text()) or {}
    if not isinstance(data, Mapping):
        raise ValueError(f"{manifest} is not a mapping")
    return pack_from_mapping(data, fallback_id=pack_dir.name)


def slot_file(pack: Pack, slot: str) -> str | None:
    """The filename for ``slot``. A list value picks the first (deterministic); a
    dict value reads its ``file`` key. ``None`` if the pack lacks the slot."""
    value = pack.slots.get(slot)
    if value is None:
        return None
    if isinstance(value, str):
        return value
    if isinstance(value, (list, tuple)):
        return str(value[0]) if value else None
    if isinstance(value, Mapping):
        file = value.get("file")
        return str(file) if file else None
    return None


def slot_asset_path(pack: Pack, slot: str, pack_dir: str | Path) -> Path | None:
    """The resolved asset path for ``slot`` under ``pack_dir`` (or ``None``)."""
    file = slot_file(pack, slot)
    return Path(pack_dir) / file if file else None
