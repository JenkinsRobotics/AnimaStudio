"""Asset catalog (Mochi's ``build_catalog.py``) — index a media folder with props.

Walks a directory for renderable media, loads each asset's ``.props.yaml`` sidecar
(or derives defaults), and produces a flat catalog: one entry per asset with its
kind + metadata. AnimaStudio builds this on the create side; it's the browsable
index (and the selection dataset the playback middleware can consume). Stdlib.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path

from animacore.asset_props import (
    AssetProps,
    kind_for_asset,
    load_props,
    props_from_mapping,
    props_to_mapping,
)

_RENDERABLE_SUFFIXES = {
    ".png", ".jpg", ".jpeg", ".webp", ".bmp",
    ".gif", ".apng",
    ".mp4", ".mov", ".mkv", ".webm",
    ".json",
}
_INDEX_NAMES = {"CATALOG.json", "PACKS.json"}

__all__ = ["CatalogEntry", "build_catalog", "catalog_to_json", "catalog_from_json"]


@dataclass(frozen=True)
class CatalogEntry:
    name: str
    path: str  # relative to the catalog root
    kind: str  # image | sprite | gif | video | bitmap
    props: AssetProps


def build_catalog(
    assets_dir: str | Path, *, root: str | Path | None = None
) -> tuple[CatalogEntry, ...]:
    """Index every renderable asset under ``assets_dir`` (paths relative to ``root``)."""
    assets_dir = Path(assets_dir)
    base = Path(root) if root is not None else assets_dir
    entries: list[CatalogEntry] = []
    for path in sorted(assets_dir.rglob("*")):
        if not path.is_file():
            continue
        if path.name in _INDEX_NAMES or path.name.endswith(".props.yaml"):
            continue
        if path.suffix.lower() not in _RENDERABLE_SUFFIXES:
            continue
        props = load_props(path)
        entries.append(
            CatalogEntry(
                name=props.name or path.stem,
                path=str(path.relative_to(base)),
                kind=kind_for_asset(path).value,
                props=props,
            )
        )
    return tuple(entries)


def catalog_to_json(entries: tuple[CatalogEntry, ...]) -> str:
    return json.dumps(
        [
            {"name": e.name, "path": e.path, "kind": e.kind, "props": props_to_mapping(e.props)}
            for e in entries
        ],
        indent=2,
    )


def catalog_from_json(text: str) -> tuple[CatalogEntry, ...]:
    return tuple(
        CatalogEntry(
            name=item["name"],
            path=item["path"],
            kind=item["kind"],
            props=props_from_mapping(item.get("props", {})),
        )
        for item in json.loads(text)
    )
