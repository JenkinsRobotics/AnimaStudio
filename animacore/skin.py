"""Device skins (schema ``skin/v1``) — ported from Mochi's convention.

A skin = a body/bezel image (``body.png``, transparent where the screen is) plus
a ``screen_bbox`` the renderer paints into. It is how a 2D character's pixels get
framed inside a physical-device look — a CRT bezel, a robot faceplate. AnimaStudio
authors skins (the create side); ``animacore.raster.skin_compositor.apply_skin``
paints an evaluated frame into one. This module is the pure model + loader
(stdlib + pyyaml); the pixel compositing lives in the raster layer.
"""

from __future__ import annotations

from collections.abc import Mapping
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import yaml

SCHEMA = "skin/v1"

__all__ = ["SCHEMA", "Skin", "load_skin", "skin_to_mapping", "skin_from_mapping"]


@dataclass(frozen=True)
class Skin:
    """A ``skin/v1`` manifest: a body image + the screen rectangle to paint into."""

    id: str
    screen_bbox: tuple[int, int, int, int]  # [left, top, width, height]
    body: str = "body.png"
    name: str = ""
    author: str = ""
    license: str = ""
    description: str = ""
    topmost: bool = True
    drag: bool = True
    opacity: float = 1.0
    scale: float = 1.0

    def __post_init__(self) -> None:
        if not self.id:
            raise ValueError("skin id must be non-empty")
        if len(self.screen_bbox) != 4:
            raise ValueError("screen_bbox must be [left, top, width, height]")
        if self.screen_bbox[2] < 1 or self.screen_bbox[3] < 1:
            raise ValueError("screen_bbox width/height must be >= 1")


def skin_from_mapping(data: Mapping, *, fallback_id: str = "") -> Skin:
    bbox = data.get("screen_bbox")
    if not bbox or len(bbox) != 4:
        raise ValueError("skin requires a 4-element screen_bbox")
    return Skin(
        id=str(data.get("id", fallback_id)),
        screen_bbox=(int(bbox[0]), int(bbox[1]), int(bbox[2]), int(bbox[3])),
        body=str(data.get("body", "body.png")),
        name=str(data.get("name", "")),
        author=str(data.get("author", "")),
        license=str(data.get("license", "")),
        description=str(data.get("description", "")),
        topmost=bool(data.get("topmost", True)),
        drag=bool(data.get("drag", True)),
        opacity=float(data.get("opacity", 1.0)),
        scale=float(data.get("scale", 1.0)),
    )


def skin_to_mapping(skin: Skin) -> dict:
    mapping: dict[str, Any] = {"schema": SCHEMA, "id": skin.id}
    for key in ("name", "author", "license", "description"):
        value = getattr(skin, key)
        if value:
            mapping[key] = value
    mapping["screen_bbox"] = list(skin.screen_bbox)
    if skin.body != "body.png":
        mapping["body"] = skin.body
    mapping["topmost"] = skin.topmost
    mapping["drag"] = skin.drag
    mapping["opacity"] = skin.opacity
    mapping["scale"] = skin.scale
    return mapping


def load_skin(skin_dir: str | Path) -> Skin:
    """Read ``<skin_dir>/meta.yaml``; the id defaults to the folder name."""
    skin_dir = Path(skin_dir)
    manifest = skin_dir / "meta.yaml"
    data = yaml.safe_load(manifest.read_text()) or {}
    if not isinstance(data, Mapping):
        raise ValueError(f"{manifest} is not a mapping")
    return skin_from_mapping(data, fallback_id=skin_dir.name)
