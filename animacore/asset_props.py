"""`.props.yaml` asset sidecars (schema ``asset-props/v1``) — ported from Mochi.

Per-asset metadata that travels *with* a media file: display name, mood/tags,
ideal size, framing, playback speed, loop, and per-type props (sprite grid, gif
fps, video trim). AnimaStudio authors these (the create side) and reads them to
build a ``VisualSource``; the playback middleware consumes the same shape.

A sidecar is optional — when absent, sensible defaults are derived from the file
(name from the stem, kind from the extension). When present, the sidecar wins.
Stdlib + pyyaml.
"""

from __future__ import annotations

from collections.abc import Mapping
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml

from animacore.canvas2d import SourceKind, VisualSource

SCHEMA = "asset-props/v1"

_KIND_BY_SUFFIX: dict[str, SourceKind] = {
    ".png": SourceKind.IMAGE,
    ".jpg": SourceKind.IMAGE,
    ".jpeg": SourceKind.IMAGE,
    ".webp": SourceKind.IMAGE,
    ".bmp": SourceKind.IMAGE,
    ".gif": SourceKind.GIF,
    ".apng": SourceKind.GIF,
    ".mp4": SourceKind.VIDEO,
    ".mov": SourceKind.VIDEO,
    ".mkv": SourceKind.VIDEO,
    ".webm": SourceKind.VIDEO,
    ".json": SourceKind.BITMAP,
}

__all__ = [
    "SCHEMA",
    "AssetProps",
    "kind_for_asset",
    "sidecar_path",
    "load_props",
    "write_props",
    "props_to_mapping",
    "props_from_mapping",
    "visual_source_from_asset",
]


def kind_for_asset(asset_path: str | Path) -> SourceKind:
    """The base source kind from a file extension (sprite is an image + a grid)."""
    return _KIND_BY_SUFFIX.get(Path(asset_path).suffix.lower(), SourceKind.IMAGE)


@dataclass(frozen=True)
class AssetProps:
    """The ``asset-props/v1`` fields (all optional; sidecar overrides defaults)."""

    name: str = ""
    author: str = ""
    license: str = ""
    source_url: str = ""
    mood: str = ""
    tags: tuple[str, ...] = ()
    hint: str = ""
    ideal_size: tuple[int, int] | None = None
    framing: str = "fit"  # fit | fill | center | stretch
    playback_speed: float = 1.0
    loop: bool = True
    duration_ms: int | None = None
    notes: str = ""
    nsfw: bool = False
    type_props: Mapping[str, Any] = field(default_factory=dict)


def sidecar_path(asset_path: str | Path) -> Path:
    """The sibling ``<asset>.props.yaml`` path."""
    return Path(asset_path).with_suffix(".props.yaml")


def props_from_mapping(data: Mapping) -> AssetProps:
    ideal = data.get("ideal_size")
    return AssetProps(
        name=str(data.get("name", "")),
        author=str(data.get("author", "")),
        license=str(data.get("license", "")),
        source_url=str(data.get("source_url", "")),
        mood=str(data.get("mood", "")),
        tags=tuple(str(tag) for tag in data.get("tags", []) or []),
        hint=str(data.get("hint", "")),
        ideal_size=(int(ideal[0]), int(ideal[1])) if ideal else None,
        framing=str(data.get("framing", "fit")),
        playback_speed=float(data.get("playback_speed", 1.0)),
        loop=bool(data.get("loop", True)),
        duration_ms=(None if data.get("duration_ms") is None else int(data["duration_ms"])),
        notes=str(data.get("notes", "")),
        nsfw=bool(data.get("nsfw", False)),
        type_props=dict(data.get("type_props", {}) or {}),
    )


def props_to_mapping(props: AssetProps) -> dict:
    mapping: dict[str, Any] = {"schema": SCHEMA}
    if props.name:
        mapping["name"] = props.name
    for key in ("author", "license", "source_url", "mood", "hint", "notes"):
        value = getattr(props, key)
        if value:
            mapping[key] = value
    if props.tags:
        mapping["tags"] = list(props.tags)
    if props.ideal_size is not None:
        mapping["ideal_size"] = list(props.ideal_size)
    mapping["framing"] = props.framing
    mapping["playback_speed"] = props.playback_speed
    mapping["loop"] = props.loop
    if props.duration_ms is not None:
        mapping["duration_ms"] = props.duration_ms
    if props.nsfw:
        mapping["nsfw"] = True
    if props.type_props:
        mapping["type_props"] = dict(props.type_props)
    return mapping


def load_props(asset_path: str | Path) -> AssetProps:
    """Read the sidecar next to ``asset_path``, or derive defaults from the file."""
    sidecar = sidecar_path(asset_path)
    if sidecar.exists():
        data = yaml.safe_load(sidecar.read_text()) or {}
        if not isinstance(data, Mapping):
            raise ValueError(f"{sidecar} is not a mapping")
        return props_from_mapping(data)
    return AssetProps(name=Path(asset_path).stem)


def write_props(asset_path: str | Path, props: AssetProps) -> Path:
    """Author (write) the sidecar next to ``asset_path``. The create side."""
    sidecar = sidecar_path(asset_path)
    sidecar.write_text(yaml.safe_dump(props_to_mapping(props), sort_keys=False))
    return sidecar


def visual_source_from_asset(
    source_id: str, asset_path: str | Path, props: AssetProps | None = None
) -> VisualSource:
    """Build a ``VisualSource`` from an asset + its props (sprite grid, fps, loop)."""
    props = props if props is not None else load_props(asset_path)
    kind = kind_for_asset(asset_path)
    type_props = dict(props.type_props or {})

    frame_count = 1
    columns = 1
    rows = 1
    fps = 0.0

    grid = type_props.get("grid")
    has_grid = grid is not None or int(type_props.get("frame_count", 1)) > 1
    if kind is SourceKind.IMAGE and has_grid:
        kind = SourceKind.SPRITE
    if kind is SourceKind.SPRITE:
        if grid:
            columns, rows = int(grid[0]), int(grid[1])
        else:
            columns = int(type_props.get("columns", 1))
            rows = int(type_props.get("rows", 1))
        frame_count = int(type_props.get("frame_count", max(1, columns * rows)))
    elif kind in (SourceKind.GIF, SourceKind.VIDEO):
        fps = float(type_props.get("fps", 0.0))
        frame_count = int(type_props.get("frame_count", 1))

    return VisualSource(
        id=source_id,
        kind=kind,
        asset=str(asset_path),
        frame_count=max(1, frame_count),
        fps=fps,
        columns=max(1, columns),
        rows=max(1, rows),
        loop=props.loop,
    )
