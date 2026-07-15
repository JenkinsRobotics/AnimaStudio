"""Mechanism rig runtime model: parts, typed joints, DOF, projection.

The Python mirror of the `.character.anima` structure semantics for
headless playback. A rig is a mechanism: rigid ``Part``s connected by
typed ``Joint``s (mates, in the Onshape sense), where the joint type
alone defines the set of ``DegreeOfFreedom`` being controlled. Clips
target DOF by path (``"<joint_name>.<dof_name>"``) and generic 0..1
``Parameter``s by name; every unanimated target falls back to its
neutral — empty or missing tracks are legal at rig level. Per-track
hold/linear interpolation is reused from ``anima_studio.tracks``;
``project_channels`` is the B04 seam mapping evaluated DOF/parameter
values to the normalized 0..1 channels ``wire.encode_frm`` takes. Rigs
come from ``.character.anima`` files via ``anima_studio.loader``.

Design rule: this module is mechanism-generic. Domain vocabulary —
character, face, vehicle, or any other application naming — lives only
in author data such as the files under ``examples/``.
"""

from __future__ import annotations

from collections.abc import Mapping
from dataclasses import dataclass, field
from enum import StrEnum
from typing import ClassVar

from anima_studio.tracks import Clip, evaluate_clip


class DofKind(StrEnum):
    ROTATION = "rotation"
    TRANSLATION = "translation"


class JointType(StrEnum):
    """Typed mates, modeled on Onshape mate connectors."""

    FASTENED = "fastened"
    REVOLUTE = "revolute"
    PRISMATIC = "prismatic"
    CYLINDRICAL = "cylindrical"
    PIN_SLOT = "pin_slot"
    PLANAR = "planar"
    BALL = "ball"


# Each joint type DEFINES its DOF set: the ordered (default name, kind)
# pairs a joint of that type must carry. Authors may rename a DOF but
# cannot add, drop, or re-kind one.
JOINT_TYPE_DOF_TEMPLATES: dict[JointType, tuple[tuple[str, DofKind], ...]] = {
    JointType.FASTENED: (),
    JointType.REVOLUTE: (("rotation", DofKind.ROTATION),),
    JointType.PRISMATIC: (("translation", DofKind.TRANSLATION),),
    JointType.CYLINDRICAL: (
        ("rotation", DofKind.ROTATION),
        ("translation", DofKind.TRANSLATION),
    ),
    JointType.PIN_SLOT: (
        ("rotation", DofKind.ROTATION),
        ("translation", DofKind.TRANSLATION),
    ),
    JointType.PLANAR: (
        ("translation_x", DofKind.TRANSLATION),
        ("translation_y", DofKind.TRANSLATION),
        ("rotation", DofKind.ROTATION),
    ),
    JointType.BALL: (
        ("rotation_x", DofKind.ROTATION),
        ("rotation_y", DofKind.ROTATION),
        ("rotation_z", DofKind.ROTATION),
    ),
}


def _validate_dof(
    name: str,
    minimum: float,
    maximum: float,
    neutral: float,
    axis: tuple[float, float, float] | None,
    unit: str,
) -> None:
    if not name:
        raise ValueError("dof name must not be empty")
    if "." in name:
        raise ValueError(f"dof name must not contain '.': {name!r}")
    if minimum >= maximum:
        raise ValueError(
            f"dof {name!r} has bad range: {minimum} >= {maximum} ({unit})"
        )
    if not minimum <= neutral <= maximum:
        raise ValueError(
            f"dof {name!r} neutral {neutral} outside range "
            f"[{minimum}, {maximum}] ({unit})"
        )
    if axis is not None:
        if len(axis) != 3:
            raise ValueError(f"dof {name!r} axis must have 3 components")
        if all(component == 0.0 for component in axis):
            raise ValueError(f"dof {name!r} axis must not be all zero")


@dataclass(frozen=True)
class RotationDof:
    """One rotational degree of freedom; limits and neutral in radians."""

    name: str
    min_radians: float
    max_radians: float
    neutral_radians: float = 0.0
    axis: tuple[float, float, float] | None = None
    description: str = ""

    kind: ClassVar[DofKind] = DofKind.ROTATION

    def __post_init__(self) -> None:
        if self.axis is not None:
            object.__setattr__(self, "axis", tuple(self.axis))
        _validate_dof(
            self.name,
            self.min_radians,
            self.max_radians,
            self.neutral_radians,
            self.axis,
            "radians",
        )

    @property
    def minimum(self) -> float:
        return self.min_radians

    @property
    def maximum(self) -> float:
        return self.max_radians

    @property
    def neutral(self) -> float:
        return self.neutral_radians


@dataclass(frozen=True)
class TranslationDof:
    """One translational degree of freedom; limits and neutral in meters."""

    name: str
    min_meters: float
    max_meters: float
    neutral_meters: float = 0.0
    axis: tuple[float, float, float] | None = None
    description: str = ""

    kind: ClassVar[DofKind] = DofKind.TRANSLATION

    def __post_init__(self) -> None:
        if self.axis is not None:
            object.__setattr__(self, "axis", tuple(self.axis))
        _validate_dof(
            self.name,
            self.min_meters,
            self.max_meters,
            self.neutral_meters,
            self.axis,
            "meters",
        )

    @property
    def minimum(self) -> float:
        return self.min_meters

    @property
    def maximum(self) -> float:
        return self.max_meters

    @property
    def neutral(self) -> float:
        return self.neutral_meters


DegreeOfFreedom = RotationDof | TranslationDof


@dataclass(frozen=True)
class Part:
    """A rigid body in the mechanism.

    ``model_node`` optionally references a node path inside an imported
    model; it is opaque data the runtime stores but never interprets.
    ``parent`` is optional assembly-tree metadata; kinematic
    connectivity is carried by ``Joint``, not here.
    """

    name: str
    parent: str | None = None
    model_node: str | None = None
    description: str = ""

    def __post_init__(self) -> None:
        if not self.name:
            raise ValueError("part name must not be empty")
        if self.parent == self.name:
            raise ValueError(f"part {self.name!r} cannot be its own parent")


@dataclass(frozen=True)
class Joint:
    """A typed mate connecting a child part to a parent part.

    The joint type defines the DOF set (count, kinds, order — see
    ``JOINT_TYPE_DOF_TEMPLATES``); ``dofs`` supplies the named, limited
    instances. A DOF list whose kinds do not match the type is
    rejected. Each DOF is addressable as ``"<joint_name>.<dof_name>"``.
    """

    name: str
    joint_type: JointType
    parent_part: str
    child_part: str
    dofs: tuple[DegreeOfFreedom, ...] = ()
    description: str = ""

    def __post_init__(self) -> None:
        object.__setattr__(self, "dofs", tuple(self.dofs))
        if not self.name:
            raise ValueError("joint name must not be empty")
        if "." in self.name:
            raise ValueError(f"joint name must not contain '.': {self.name!r}")
        if self.parent_part == self.child_part:
            raise ValueError(
                f"joint {self.name!r} connects part "
                f"{self.parent_part!r} to itself"
            )
        template_kinds = tuple(
            kind for _, kind in JOINT_TYPE_DOF_TEMPLATES[self.joint_type]
        )
        dof_kinds = tuple(dof.kind for dof in self.dofs)
        if dof_kinds != template_kinds:
            raise ValueError(
                f"joint {self.name!r} of type {self.joint_type.value!r} "
                f"must have dof kinds "
                f"({', '.join(template_kinds) or 'none'}), got "
                f"({', '.join(dof_kinds) or 'none'})"
            )
        names = [dof.name for dof in self.dofs]
        if len(names) != len(set(names)):
            raise ValueError(f"joint {self.name!r} has duplicate dof names")

    def dof_paths(self) -> dict[str, DegreeOfFreedom]:
        """This joint's DOF keyed by ``"<joint_name>.<dof_name>"`` path."""
        return {f"{self.name}.{dof.name}": dof for dof in self.dofs}


@dataclass(frozen=True)
class Parameter:
    """A named generic scalar channel, always normalized 0.0..1.0.

    The rig model gives parameters no further meaning; what one drives
    (a display weight, a lamp intensity, ...) is the author's business.
    """

    name: str
    neutral_value: float = 0.0
    description: str = ""

    def __post_init__(self) -> None:
        if not self.name:
            raise ValueError("parameter name must not be empty")
        if "." in self.name:
            raise ValueError(
                f"parameter name must not contain '.': {self.name!r}"
            )
        if not 0.0 <= self.neutral_value <= 1.0:
            raise ValueError(
                f"parameter {self.name!r} neutral outside 0..1: "
                f"{self.neutral_value}"
            )


@dataclass(frozen=True)
class OutputMapping:
    """Evaluated target value → normalized wire channel value (B04 seam).

    ``target`` is a DOF path (``"<joint_name>.<dof_name>"``) or a
    parameter name. ``value_at_zero`` / ``value_at_one`` are the target
    values — in the target's native units: radians for a rotation DOF,
    meters for a translation DOF, unitless 0..1 for a parameter — that
    map to channel values 0.0 and 1.0; a descending pair inverts the
    channel. Values outside the pair clamp to 0..1. Pulse widths, pins,
    and other hardware detail stay in the wire ``CFG`` layer, never
    here.
    """

    target: str
    channel: int
    value_at_zero: float
    value_at_one: float

    def __post_init__(self) -> None:
        if self.channel < 0:
            raise ValueError(f"channel must be >= 0: {self.channel}")
        if self.value_at_zero == self.value_at_one:
            raise ValueError(
                f"mapping for target {self.target!r} has zero span: "
                f"both ends are {self.value_at_zero}"
            )

    def channel_value(self, value: float) -> float:
        """Project a target value to the normalized 0..1 channel value."""
        span = self.value_at_one - self.value_at_zero
        normalized = (value - self.value_at_zero) / span
        return min(max(normalized, 0.0), 1.0)


@dataclass(frozen=True)
class RigClip:
    """A named clip plus its rig-level playback flags."""

    clip: Clip
    loop: bool = False


@dataclass(frozen=True)
class Identity:
    """Character identity metadata from the ``identity:`` section."""

    name: str
    display_name: str = ""
    description: str = ""
    version: str = ""
    author: str = ""


@dataclass(frozen=True)
class Rig:
    """A mechanism's movable structure: what a clip is evaluated against.

    Clip track keys are DOF paths (``"<joint_name>.<dof_name>"``) or
    parameter names, and every key must resolve to a declared DOF or
    parameter. Parameter names never contain ``.`` and DOF paths always
    do, so the two namespaces cannot collide.
    """

    identity: Identity
    parts: Mapping[str, Part] = field(default_factory=dict)
    joints: Mapping[str, Joint] = field(default_factory=dict)
    parameters: Mapping[str, Parameter] = field(default_factory=dict)
    clips: Mapping[str, RigClip] = field(default_factory=dict)
    outputs: tuple[OutputMapping, ...] = ()

    def __post_init__(self) -> None:
        for kind, items in (
            ("part", self.parts),
            ("joint", self.joints),
            ("parameter", self.parameters),
        ):
            for key, item in items.items():
                if key != item.name:
                    raise ValueError(
                        f"{kind} key {key!r} != name {item.name!r}"
                    )
        for part in self.parts.values():
            if part.parent is not None and part.parent not in self.parts:
                raise ValueError(
                    f"part {part.name!r} parent references undeclared part "
                    f"{part.parent!r}"
                )
        for joint in self.joints.values():
            for part_name in (joint.parent_part, joint.child_part):
                if part_name not in self.parts:
                    raise ValueError(
                        f"joint {joint.name!r} references undeclared part "
                        f"{part_name!r}"
                    )
        paths = self.dof_paths()
        for clip_name, rig_clip in self.clips.items():
            for key in rig_clip.clip.tracks:
                if key not in paths and key not in self.parameters:
                    raise ValueError(
                        f"clip {clip_name!r} animates unknown target {key!r}"
                    )
        seen_channels: set[int] = set()
        for mapping in self.outputs:
            if (
                mapping.target not in paths
                and mapping.target not in self.parameters
            ):
                raise ValueError(
                    f"output mapping references unknown target "
                    f"{mapping.target!r}"
                )
            if mapping.channel in seen_channels:
                raise ValueError(f"duplicate output channel: {mapping.channel}")
            seen_channels.add(mapping.channel)

    def dof_paths(self) -> dict[str, DegreeOfFreedom]:
        """Every addressable DOF, keyed by ``"<joint_name>.<dof_name>"``."""
        paths: dict[str, DegreeOfFreedom] = {}
        for joint in self.joints.values():
            paths.update(joint.dof_paths())
        return paths


@dataclass(frozen=True)
class Pose:
    """One evaluated rig state.

    ``dof_values`` is keyed by DOF path in each DOF's native units
    (radians for rotation, meters for translation); ``parameter_values``
    is keyed by parameter name, 0..1.
    """

    dof_values: Mapping[str, float]
    parameter_values: Mapping[str, float]


def evaluate_pose(
    rig: Rig, clip_name: str | None = None, time_seconds: float = 0.0
) -> Pose:
    """Evaluate the rig at ``time_seconds``, deterministically.

    ``clip_name`` selects one of ``rig.clips``; ``None`` gives the
    neutral pose. Every DOF or parameter the clip does not animate
    falls back to its neutral. Looping clips wrap time modulo the
    duration; non-looping clips clamp.
    """
    animated: Mapping[int | str, float] = {}
    if clip_name is not None:
        rig_clip = rig.clips.get(clip_name)
        if rig_clip is None:
            raise KeyError(f"rig has no clip named {clip_name!r}")
        duration_seconds = rig_clip.clip.duration_seconds
        if rig_clip.loop and duration_seconds > 0:
            time_seconds = time_seconds % duration_seconds
        animated = evaluate_clip(rig_clip.clip, time_seconds)

    return Pose(
        dof_values={
            path: animated.get(path, dof.neutral)
            for path, dof in rig.dof_paths().items()
        },
        parameter_values={
            name: animated.get(name, parameter.neutral_value)
            for name, parameter in rig.parameters.items()
        },
    )


def project_channels(rig: Rig, pose: Pose) -> dict[int, float]:
    """Project a pose's mapped targets to normalized 0..1 channel values.

    The result is exactly what ``wire.encode_frm`` takes. Unmapped DOF
    and parameters are omitted.
    """
    channels: dict[int, float] = {}
    for mapping in rig.outputs:
        if "." in mapping.target:
            value = pose.dof_values[mapping.target]
        else:
            value = pose.parameter_values[mapping.target]
        channels[mapping.channel] = mapping.channel_value(value)
    return channels
