"""2D visual characters (VTuber-style) — the renderer-neutral model.

A 2D character is a ``Canvas2D``: a set of ``Surface`` display windows, each
showing a ``VisualSource`` (image / sprite sheet / gif / video / procedural
face). Surfaces are driven by the *same* evaluated DOF/parameter values the 3D
rig uses, so 2D animates on one timeline with 3D.

Non-negotiable, mirroring the motion side: this module evaluates **surface
state** — which source, which frame index, the 2D transform, opacity,
visibility — and **never touches pixels**. Compositing and any media decoding
are a downstream rasterizer's job (the Swift/RealityKit renderer for preview, a
headless rasterizer for the hardware frame-output path). Stdlib only.

See ``dev/docs/roadmap/2D_Character_Pipeline.md``.
"""

from __future__ import annotations

from collections.abc import Mapping
from dataclasses import dataclass, field
from enum import StrEnum


class SourceKind(StrEnum):
    """The 2D asset evolution: each a superset of the previous one's needs."""

    IMAGE = "image"  # one static frame
    BITMAP = "bitmap"  # 1-bit packed monochrome (native LED-matrix asset)
    SPRITE = "sprite"  # atlas of frames, chosen by index
    GIF = "gif"  # timed frames, plays on a clock or scrubs by index
    VIDEO = "video"  # decoded stream, plays on a clock / seekable
    PROCEDURAL = "procedural"  # drawn from parameters each frame (a face); no fixed frames


@dataclass(frozen=True)
class VisualSource:
    """A media reference that yields one frame given a frame selector.

    ``asset`` is an opaque, project-relative asset path (like ``Part.model``);
    the engine never opens it. ``frame_count`` is the number of selectable
    frames (1 for a plain image). ``columns``/``rows`` describe a sprite atlas.
    ``fps`` drives clock-based playback for gif/video (0 = index-driven only).
    """

    id: str
    kind: SourceKind
    asset: str = ""
    frame_count: int = 1
    fps: float = 0.0
    columns: int = 1
    rows: int = 1
    loop: bool = True

    def __post_init__(self) -> None:
        if not self.id:
            raise ValueError("visual source id must be non-empty")
        if self.frame_count < 1:
            raise ValueError(
                f"source {self.id!r} frame_count must be >= 1, got {self.frame_count}"
            )
        if self.columns < 1 or self.rows < 1:
            raise ValueError(
                f"source {self.id!r} atlas grid must be >= 1x1, "
                f"got {self.columns}x{self.rows}"
            )
        if self.fps < 0:
            raise ValueError(f"source {self.id!r} fps must be >= 0, got {self.fps}")
        if self.kind is SourceKind.IMAGE and self.frame_count != 1:
            raise ValueError(
                f"image source {self.id!r} must have frame_count 1, "
                f"got {self.frame_count}"
            )

    def frame_from_unit(self, unit: float) -> int:
        """Select a frame from a 0..1 driver value (N equal buckets).

        ``unit`` clamps to ``[0, 1]``; the range is split into ``frame_count``
        equal buckets so a parameter sweep walks every frame once, with
        ``1.0`` landing on the last frame.
        """
        clamped = min(max(unit, 0.0), 1.0)
        index = int(clamped * self.frame_count)
        return min(index, self.frame_count - 1)

    def frame_at_time(self, time_seconds: float) -> int:
        """Clock-based frame for gif/video. ``fps <= 0`` pins frame 0."""
        if self.fps <= 0 or self.frame_count == 1 or time_seconds <= 0:
            return 0
        raw = int(time_seconds * self.fps)
        if self.loop:
            return raw % self.frame_count
        return min(raw, self.frame_count - 1)

    def atlas_cell(self, frame_index: int) -> tuple[int, int]:
        """The ``(column, row)`` of a frame in the sprite atlas."""
        index = min(max(frame_index, 0), self.frame_count - 1)
        return index % self.columns, index // self.columns


class SurfaceProperty(StrEnum):
    """A surface field a driver can animate."""

    FRAME = "frame"  # driver value (0..1) selects the source frame
    OPACITY = "opacity"
    X = "x"
    Y = "y"
    WIDTH = "width"
    HEIGHT = "height"
    ROTATION = "rotation_deg"
    VISIBLE = "visible"  # resolved >= 0.5 is visible


@dataclass(frozen=True)
class SurfaceDriver:
    """Binds an evaluated DOF/parameter value to a surface property.

    A linear remap (like ``OutputMapping``, but with an explicit output range so
    it can drive canvas units / degrees, not only 0..1): input
    ``[input_at_zero, input_at_one]`` maps to output ``[output_at_zero,
    output_at_one]``, clamped at the ends. ``source`` is a DOF path
    (``"<joint>.<dof>"``) or a parameter name — resolved exactly like a rig DOF.
    """

    property: SurfaceProperty
    source: str
    input_at_zero: float = 0.0
    input_at_one: float = 1.0
    output_at_zero: float = 0.0
    output_at_one: float = 1.0

    def __post_init__(self) -> None:
        if not self.source:
            raise ValueError(
                f"driver for {self.property} must name a source dof/parameter"
            )
        if self.input_at_zero == self.input_at_one:
            raise ValueError(
                f"driver for {self.property} has zero input span "
                f"(both ends {self.input_at_zero})"
            )

    def resolve(self, input_value: float) -> float:
        span = self.input_at_one - self.input_at_zero
        t = (input_value - self.input_at_zero) / span
        t = min(max(t, 0.0), 1.0)
        return self.output_at_zero + t * (self.output_at_one - self.output_at_zero)


@dataclass(frozen=True)
class Surface:
    """A placed display window in the canvas showing one visual source.

    Transform is in **normalized canvas space** (origin top-left, 0..1), so one
    character drives both a high-res preview and a 64x64 LED matrix. ``z`` is
    draw order (ascending = back to front).
    """

    id: str
    source: str
    x: float = 0.0
    y: float = 0.0
    width: float = 1.0
    height: float = 1.0
    rotation_deg: float = 0.0
    opacity: float = 1.0
    z: int = 0
    visible: bool = True
    drivers: tuple[SurfaceDriver, ...] = ()

    def __post_init__(self) -> None:
        if not self.id:
            raise ValueError("surface id must be non-empty")
        if not self.source:
            raise ValueError(f"surface {self.id!r} must reference a visual source")


@dataclass(frozen=True)
class Canvas2D:
    """A 2D character: its native pixel resolution + ordered surfaces.

    ``width``/``height`` are the canvas's native pixels (e.g. 1024x1024, or
    64x64 for a matrix-native character). ``sources`` are keyed by id.
    """

    width: int = 1024
    height: int = 1024
    sources: Mapping[str, VisualSource] = field(default_factory=dict)
    surfaces: tuple[Surface, ...] = ()

    def __post_init__(self) -> None:
        if self.width < 1 or self.height < 1:
            raise ValueError(
                f"canvas size must be >= 1x1, got {self.width}x{self.height}"
            )
        for source_id, source in self.sources.items():
            if source.id != source_id:
                raise ValueError(
                    f"source keyed {source_id!r} has mismatched id {source.id!r}"
                )
        seen: set[str] = set()
        for surface in self.surfaces:
            if surface.id in seen:
                raise ValueError(f"duplicate surface id {surface.id!r}")
            seen.add(surface.id)
            if surface.source not in self.sources:
                raise ValueError(
                    f"surface {surface.id!r} references unknown source "
                    f"{surface.source!r}"
                )


@dataclass(frozen=True)
class SurfaceState:
    """One surface fully resolved for a moment — renderer-neutral, no pixels."""

    id: str
    source: str
    frame_index: int
    x: float
    y: float
    width: float
    height: float
    rotation_deg: float
    opacity: float
    visible: bool
    z: int


def evaluate_surfaces(
    canvas: Canvas2D,
    values: Mapping[str, float] | None = None,
    time_seconds: float = 0.0,
) -> tuple[SurfaceState, ...]:
    """Resolve every surface to a ``SurfaceState`` for the given inputs.

    ``values`` maps DOF paths / parameter names to their evaluated value (the
    output of ``evaluate_pose`` + parameters), exactly the stream the motion
    side already produces. A driver whose ``source`` is absent from ``values``
    leaves its property at the surface's base value (a missing input never
    forces a change). The frame index comes from a ``FRAME`` driver (index
    selection) when present, otherwise from the source's clock at
    ``time_seconds`` (gif/video). Results are ordered back-to-front by ``z``.
    """
    resolved: dict[str, float] = dict(values or {})
    states: list[SurfaceState] = []

    for surface in canvas.surfaces:
        props: dict[SurfaceProperty, float] = {
            SurfaceProperty.OPACITY: surface.opacity,
            SurfaceProperty.X: surface.x,
            SurfaceProperty.Y: surface.y,
            SurfaceProperty.WIDTH: surface.width,
            SurfaceProperty.HEIGHT: surface.height,
            SurfaceProperty.ROTATION: surface.rotation_deg,
            SurfaceProperty.VISIBLE: 1.0 if surface.visible else 0.0,
        }
        frame_unit: float | None = None

        for driver in surface.drivers:
            if driver.source not in resolved:
                continue
            output = driver.resolve(resolved[driver.source])
            if driver.property is SurfaceProperty.FRAME:
                frame_unit = output
            else:
                props[driver.property] = output

        source = canvas.sources[surface.source]
        if frame_unit is not None:
            frame_index = source.frame_from_unit(frame_unit)
        else:
            frame_index = source.frame_at_time(time_seconds)

        states.append(
            SurfaceState(
                id=surface.id,
                source=surface.source,
                frame_index=frame_index,
                x=props[SurfaceProperty.X],
                y=props[SurfaceProperty.Y],
                width=props[SurfaceProperty.WIDTH],
                height=props[SurfaceProperty.HEIGHT],
                rotation_deg=props[SurfaceProperty.ROTATION],
                opacity=min(max(props[SurfaceProperty.OPACITY], 0.0), 1.0),
                visible=props[SurfaceProperty.VISIBLE] >= 0.5,
                z=surface.z,
            )
        )

    states.sort(key=lambda state: state.z)
    return tuple(states)
