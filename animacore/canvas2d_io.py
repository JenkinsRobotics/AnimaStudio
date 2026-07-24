"""Read/write a ``Canvas2D`` as the ``canvas2d:`` block of a ``.character.anima``.

The 2D sibling of ``loader.py`` / ``serialize.py``'s rig I/O — one mapping shape
shared by the file format, the Swift bridge DTO, and any editor. A 2D character
is a ``.character.anima`` whose top level carries a ``canvas2d:`` block, optionally
alongside a rig (a hybrid 3D + 2D character). Stdlib + pyyaml.
"""

from __future__ import annotations

from collections.abc import Mapping

import yaml

from animacore.canvas2d import (
    Canvas2D,
    SourceKind,
    Surface,
    SurfaceDriver,
    SurfaceProperty,
    VisualSource,
)

__all__ = [
    "canvas2d_to_mapping",
    "canvas2d_from_mapping",
    "canvas2d_to_yaml",
    "parse_canvas2d",
]


def canvas2d_to_mapping(canvas: Canvas2D) -> dict:
    """The ``canvas2d:`` block shape — the DTO Swift mirrors and files store."""
    return {
        "width": canvas.width,
        "height": canvas.height,
        "sources": [
            {
                "id": source.id,
                "kind": source.kind.value,
                "asset": source.asset,
                "frame_count": source.frame_count,
                "fps": source.fps,
                "columns": source.columns,
                "rows": source.rows,
                "loop": source.loop,
            }
            for source in canvas.sources.values()
        ],
        "surfaces": [
            {
                "id": surface.id,
                "source": surface.source,
                "x": surface.x,
                "y": surface.y,
                "width": surface.width,
                "height": surface.height,
                "rotation_deg": surface.rotation_deg,
                "opacity": surface.opacity,
                "z": surface.z,
                "visible": surface.visible,
                "drivers": [
                    {
                        "property": driver.property.value,
                        "source": driver.source,
                        "input_at_zero": driver.input_at_zero,
                        "input_at_one": driver.input_at_one,
                        "output_at_zero": driver.output_at_zero,
                        "output_at_one": driver.output_at_one,
                    }
                    for driver in surface.drivers
                ],
            }
            for surface in canvas.surfaces
        ],
    }


def canvas2d_from_mapping(data: Mapping) -> Canvas2D:
    """Build a validated ``Canvas2D`` from the block shape. Raises ``ValueError``."""
    if not isinstance(data, Mapping):
        raise ValueError("canvas2d must be a mapping")
    sources: dict[str, VisualSource] = {}
    for entry in data.get("sources", []) or []:
        source = VisualSource(
            id=entry["id"],
            kind=SourceKind(entry.get("kind", "image")),
            asset=entry.get("asset", ""),
            frame_count=int(entry.get("frame_count", 1)),
            fps=float(entry.get("fps", 0.0)),
            columns=int(entry.get("columns", 1)),
            rows=int(entry.get("rows", 1)),
            loop=bool(entry.get("loop", True)),
        )
        sources[source.id] = source
    surfaces = tuple(
        Surface(
            id=entry["id"],
            source=entry["source"],
            x=float(entry.get("x", 0.0)),
            y=float(entry.get("y", 0.0)),
            width=float(entry.get("width", 1.0)),
            height=float(entry.get("height", 1.0)),
            rotation_deg=float(entry.get("rotation_deg", 0.0)),
            opacity=float(entry.get("opacity", 1.0)),
            z=int(entry.get("z", 0)),
            visible=bool(entry.get("visible", True)),
            drivers=tuple(
                SurfaceDriver(
                    property=SurfaceProperty(driver["property"]),
                    source=driver["source"],
                    input_at_zero=float(driver.get("input_at_zero", 0.0)),
                    input_at_one=float(driver.get("input_at_one", 1.0)),
                    output_at_zero=float(driver.get("output_at_zero", 0.0)),
                    output_at_one=float(driver.get("output_at_one", 1.0)),
                )
                for driver in entry.get("drivers", []) or []
            ),
        )
        for entry in data.get("surfaces", []) or []
    )
    return Canvas2D(
        width=int(data.get("width", 1024)),
        height=int(data.get("height", 1024)),
        sources=sources,
        surfaces=surfaces,
    )


def canvas2d_to_yaml(canvas: Canvas2D) -> str:
    """Serialize just the ``canvas2d:`` block (for saving / inspecting)."""
    return yaml.safe_dump({"canvas2d": canvas2d_to_mapping(canvas)}, sort_keys=False)


def parse_canvas2d(text: str) -> Canvas2D | None:
    """Extract the ``Canvas2D`` from a character document (or a bare block).

    Accepts a full ``.character.anima`` (reads its ``canvas2d:`` block) or a bare
    ``canvas2d`` mapping. Returns ``None`` if the document carries no 2D block.
    Raises ``ValueError`` on a malformed block.
    """
    try:
        document = yaml.safe_load(text)
    except yaml.YAMLError as error:
        raise ValueError(f"not valid YAML: {error}") from error
    if not isinstance(document, Mapping):
        raise ValueError("document is not a mapping")
    if "canvas2d" in document:
        block = document["canvas2d"]
    elif any(key in document for key in ("surfaces", "sources", "width")):
        block = document
    else:
        return None
    return canvas2d_from_mapping(block)
