"""Mechanism rig runtime model: parts, typed joints, DOF, projection.

The Python mirror of the `.character.anima` structure semantics for
headless playback. A rig is a mechanism: rigid ``Part``s connected by
typed ``Joint``s (mates, in the Onshape sense), where the joint type
alone defines the set of ``DegreeOfFreedom`` being controlled. Clips
target DOF by path (``"<joint_name>.<dof_name>"``) and generic 0..1
``Parameter``s by name; every unanimated target falls back to its
neutral — empty or missing tracks are legal at rig level. Per-track
hold/linear interpolation is reused from ``animacore.tracks``;
``project_channels`` is the B04 seam mapping evaluated DOF/parameter
values to the normalized 0..1 channels ``wire.encode_frm`` takes. Rigs
come from ``.character.anima`` files via ``animacore.loader``.

Kinematics (per ``dev/docs/roadmap/Kinematics.md``): per-DOF limits are
optional — an unlimited DOF (a wheel) is legal and never clamped, but
it cannot be mapped to a bounded output channel. ``Relation`` couples
exactly two DOF linearly (gear / rack_pinion / screw / linear);
``evaluate_pose`` resolves drivers from the clip, applies relations in
dependency order, and reports (never clamps) driven values outside
their limits as ``Pose.limit_violations``; ``project_channels`` raises
``LimitViolationError`` for a mapped violated DOF so hardware refuses
to arm.

Design rule: this module is mechanism-generic. Domain vocabulary —
character, face, vehicle, or any other application naming — lives only
in author data such as the files under ``examples/``.
"""

from __future__ import annotations

import math
from collections.abc import Mapping
from dataclasses import dataclass, field
from enum import StrEnum

from animacore.dh import DHChain, DHLink, JointKind
from animacore.mates import (
    JOINT_TYPE_DOF_TEMPLATES,
    DegreeOfFreedom,
    DofKind,
    JointType,
    MateCategory,
    MateConnector,
    MateControls,
    MateOffset,
    RotationAxis,
    RotationDof,
    SecondaryAxisRotation,
    TangentSpec,
    TranslationDof,
    all_mate_type_schemas,
    describe_mate,
    mate_category,
    mate_type_schema,
)
from animacore.tracks import Clip, evaluate_clip

# The mate-authoring vocabulary lives in ``animacore.mates``; rig.py
# re-exports it so ``from animacore.rig import JointType`` (and the
# other typed-mate names) keeps working.
__all__ = [
    "JOINT_TYPE_DOF_TEMPLATES",
    "DegreeOfFreedom",
    "DofKind",
    "JointType",
    "MateCategory",
    "MateConnector",
    "MateControls",
    "MateOffset",
    "RotationAxis",
    "RotationDof",
    "SecondaryAxisRotation",
    "TangentSpec",
    "TranslationDof",
    "all_mate_type_schemas",
    "describe_mate",
    "mate_category",
    "mate_type_schema",
    "Part",
    "Joint",
    "Parameter",
    "OutputMapping",
    "RelationKind",
    "RELATION_KIND_DOF_KINDS",
    "RELATION_DISPLAY_KEYS",
    "RELATION_KIND_LABELS",
    "Relation",
    "relation_type_schema",
    "all_relation_type_schemas",
    "describe_relation",
    "relations_in_dependency_order",
    "RigClip",
    "Identity",
    "JointKind",
    "ChainJoint",
    "KinematicChain",
    "Rig",
    "LimitViolation",
    "LimitViolationError",
    "Pose",
    "evaluate_pose",
    "project_channels",
]


def _validate_safe_relative_path(value: str, part_name: str) -> None:
    """Reject an unsafe per-part asset path (absolute / traversal / empty).

    A ``Part.model`` is resolved against the character's ``assets/``
    folder, so it must be a *safe relative* path: no leading ``/``
    (absolute), no ``..`` traversal segment, no empty segment (a leading,
    trailing, or doubled ``/``). The engine still never opens or parses
    the file — this guards only against a path escaping the character
    folder on the app's side.
    """
    if value.startswith("/"):
        raise ValueError(
            f"part {part_name!r} model must be a relative path within the "
            f"character's assets/, got absolute path {value!r}"
        )
    for segment in value.split("/"):
        if segment == "":
            raise ValueError(
                f"part {part_name!r} model has an empty path segment "
                f"(leading/trailing/doubled '/'): {value!r}"
            )
        if segment == "..":
            raise ValueError(
                f"part {part_name!r} model must not contain a '..' "
                f"traversal segment: {value!r}"
            )


def _as_vec3(
    value: object, part_name: str, field_name: str
) -> tuple[float, float, float]:
    """Validate a rest-transform 3-tuple (position/euler), returning floats."""
    if not isinstance(value, (tuple, list)) or len(value) != 3:
        raise ValueError(
            f"part {part_name!r} {field_name} must be a 3-tuple, got {value!r}"
        )
    return tuple(float(component) for component in value)


@dataclass(frozen=True)
class Part:
    """A rigid body in the mechanism.

    A character is an *assembly* of rigid parts (the parametric-assembly
    paradigm, not a skinned mesh), each part backed by its own imported
    geometry. Two independent, fully opaque geometry references — the
    runtime stores and round-trips both but never parses either, so any
    mesh format (STL / OBJ / STEP / USD / ...) is treated identically:

    - ``model`` — a relative path to the part's asset FILE within the
      character's ``assets/`` folder (e.g. ``"assets/head.stl"``,
      ``"assets/robot.usdz"``). Empty when the part has no geometry of
      its own. It must be a *safe relative* path (validated below) so a
      character folder stays portable.
    - ``model_node`` — an optional node path WITHIN a multi-node file
      (e.g. a subtree of a USD stage); null/absent for a single-mesh
      file like an STL.

    The two combine freely: a multi-file assembly gives each part its
    own ``model`` and no ``model_node``; a single multi-node USD gives
    parts a shared ``model`` plus distinct ``model_node``s.

    ``parent`` is optional assembly-tree metadata; kinematic
    connectivity is carried by ``Joint``, not here.

    ``position_m`` and ``rotation_euler_rad`` are the part's **rest
    transform** — its placement in **CHARACTER space** (the transform
    from part space to character space), NOT world space. ``position_m``
    is the part origin's position in metres; ``rotation_euler_rad`` is
    the rest orientation as XYZ Euler angles in radians (matching the
    app's ``rotationEulerRadians``; intrinsic XYZ, see
    ``kinematics.Transform.from_euler_xyz``). This rest transform is the
    part's placement when it is a **ROOT** or **GROUNDED** part; a
    **mated** child is positioned instead by its mate
    (``kinematics.child_in_parent``), so its rest transform is only its
    pre-mate placement and is not applied on top of the mate. World
    placement of the whole character is a separate scene-level concern
    (default identity when authoring one character) — see
    ``dev/docs/roadmap/Coordinate_Frames.md``. Both default to the zero
    transform, so an existing rig is unchanged.

    ``suppressed`` and ``grounded`` are persistent *rig-semantic* object
    states (round-tripped through the file, unlike the app's transient
    hidden/lock view-state): a **suppressed** part is excluded from the
    solve entirely (its geometry vanishes and any joint touching it goes
    inactive); a **grounded** part is pinned as a fixed root at its rest
    transform, overriding any incoming joint. Both default off, so an
    existing rig is unchanged. See ``kinematics.resolve_pose`` for the
    exact FK rules.
    """

    name: str
    parent: str | None = None
    model_node: str | None = None
    description: str = ""
    model: str = ""
    suppressed: bool = False
    grounded: bool = False
    position_m: tuple[float, float, float] = (0.0, 0.0, 0.0)
    rotation_euler_rad: tuple[float, float, float] = (0.0, 0.0, 0.0)

    def __post_init__(self) -> None:
        if not self.name:
            raise ValueError("part name must not be empty")
        if self.parent == self.name:
            raise ValueError(f"part {self.name!r} cannot be its own parent")
        if self.model:
            _validate_safe_relative_path(self.model, self.name)
        object.__setattr__(
            self, "position_m", _as_vec3(self.position_m, self.name, "position_m")
        )
        object.__setattr__(
            self,
            "rotation_euler_rad",
            _as_vec3(self.rotation_euler_rad, self.name, "rotation_euler_rad"),
        )


@dataclass(frozen=True)
class Joint:
    """A typed mate connecting a child part to a parent part.

    The joint type defines the DOF set (count, kinds, order — see
    ``JOINT_TYPE_DOF_TEMPLATES``); ``dofs`` supplies the named
    instances. A DOF list whose kinds do not match the type is
    rejected. Each DOF is addressable as ``"<joint_name>.<dof_name>"``.

    ``id`` is a stable tracking identity (e.g. ``"Fastened 33"``),
    distinct from the editable ``name`` and preserved verbatim — empty
    is allowed (the app assigns it). ``controls`` carries the universal
    connector/offset/flip/orient controls (``MateControls``); the
    as-mated offset lives at ``controls.offset``. The headless runtime
    round-trips connectors and offsets without spatial math.

    Geometry-constraint mates (``width``, ``tangent``) are 0-DOF and
    app-resolved (``mate_category``). ``width`` reuses ``controls`` (its
    two connectors are the app-computed midplanes) but carries no
    offset — Onshape allows none. ``tangent`` uses no mate connectors:
    it carries ``controls=None`` and a ``tangent`` (``TangentSpec``)
    block of two opaque surface selections plus a propagation flag,
    round-tripped for the app.

    ``suppressed`` is a persistent rig-semantic state (round-tripped
    through the file, unlike app view-state): a suppressed joint
    contributes no driven DOF in ``evaluate_pose`` and is skipped in the
    ``resolve_pose`` FK walk, so its child is not positioned by it.
    Defaults off, so an existing rig is unchanged.
    """

    name: str
    joint_type: JointType
    parent_part: str
    child_part: str
    dofs: tuple[DegreeOfFreedom, ...] = ()
    description: str = ""
    id: str = ""
    controls: MateControls | None = None
    tangent: TangentSpec | None = None
    suppressed: bool = False

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
            kind for _, kind, _ in JOINT_TYPE_DOF_TEMPLATES[self.joint_type]
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
        self._validate_geometry_constraint()

    def _validate_geometry_constraint(self) -> None:
        """Geometry-constraint invariants (width/tangent are 0-DOF).

        The template-kind check above already forces both to zero DOF.
        Here: tangent carries a ``tangent`` block and no mate
        controls/connectors/offset; width reuses ``controls`` but must
        not set an as-mated offset (Onshape allows none); a kinematic
        mate must not carry a ``tangent`` block.
        """
        if self.joint_type is JointType.TANGENT:
            if self.controls is not None:
                raise ValueError(
                    f"tangent joint {self.name!r} must not carry mate "
                    f"controls (no connectors/offset — its geometry is "
                    f"app-resolved)"
                )
            return
        if self.tangent is not None:
            raise ValueError(
                f"joint {self.name!r} of type {self.joint_type.value!r} "
                f"must not carry a tangent block (tangent mates only)"
            )
        if self.joint_type is JointType.WIDTH and self.controls is not None:
            offset = self.controls.offset
            if (
                offset.enabled
                or any(offset.translation_m)
                or offset.rotation_radians
            ):
                raise ValueError(
                    f"width joint {self.name!r} must not set an as-mated "
                    f"offset (Onshape allows no offset on Width)"
                )

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


class RelationKind(StrEnum):
    """The four linear DOF couplings (Kinematics.md §5)."""

    GEAR = "gear"
    RACK_PINION = "rack_pinion"
    SCREW = "screw"
    LINEAR = "linear"


# Each relation kind DEFINES its (driver kind, driven kind) pairing.
RELATION_KIND_DOF_KINDS: dict[RelationKind, tuple[DofKind, DofKind]] = {
    RelationKind.GEAR: (DofKind.ROTATION, DofKind.ROTATION),
    RelationKind.RACK_PINION: (DofKind.ROTATION, DofKind.TRANSLATION),
    RelationKind.SCREW: (DofKind.ROTATION, DofKind.TRANSLATION),
    RelationKind.LINEAR: (DofKind.TRANSLATION, DofKind.TRANSLATION),
}

# Non-semantic display fields a relation may carry per kind (teeth,
# lead, ...). They round-trip for UI display; ``ratio`` stays the one
# semantic value and no consistency between the two is enforced.
RELATION_DISPLAY_KEYS: dict[RelationKind, frozenset[str]] = {
    RelationKind.GEAR: frozenset({"driver_teeth", "driven_teeth"}),
    RelationKind.RACK_PINION: frozenset({"pinion_diameter_mm"}),
    RelationKind.SCREW: frozenset({"lead_mm_per_rev"}),
    RelationKind.LINEAR: frozenset(),
}


@dataclass(frozen=True)
class Relation:
    """A linear coupling between exactly two DOF (Kinematics.md §5).

    ``driven_value = ratio * driver_value + offset``, all in model
    units: ``ratio`` is driven model units per driver model unit
    (unitless for gear/linear, meters per radian for rack_pinion and
    screw) and ``offset`` is in the driven DOF's model units (radians
    or meters). ``driver`` and ``driven`` are DOF paths
    (``"<joint_name>.<dof_name>"``). The relation always computes —
    no collision detection, no clamping; limit handling for the driven
    DOF is violation reporting in ``evaluate_pose``.

    ``suppressed`` is a persistent rig-semantic state: a suppressed
    relation is skipped (not applied) in ``evaluate_pose``'s dependency
    pass, so its driven DOF falls back to its own neutral. Defaults off.
    """

    kind: RelationKind
    driver: str
    driven: str
    ratio: float
    offset: float = 0.0
    display: Mapping[str, float] = field(default_factory=dict)
    suppressed: bool = False

    def __post_init__(self) -> None:
        for role, path in (("driver", self.driver), ("driven", self.driven)):
            if "." not in path:
                raise ValueError(
                    f"relation {role} {path!r} must be a dof path "
                    f"(\"<joint_name>.<dof_name>\")"
                )
        if self.driver == self.driven:
            raise ValueError(
                f"relation cannot couple dof {self.driver!r} to itself"
            )
        if not math.isfinite(self.ratio) or self.ratio == 0.0:
            raise ValueError(
                f"relation {self.describe()} ratio must be a nonzero "
                f"finite number, got {self.ratio!r}"
            )
        if not math.isfinite(self.offset):
            raise ValueError(
                f"relation {self.describe()} offset must be finite, "
                f"got {self.offset!r}"
            )
        allowed = RELATION_DISPLAY_KEYS[self.kind]
        for key, value in self.display.items():
            if key not in allowed:
                valid = ", ".join(sorted(allowed)) or "none"
                raise ValueError(
                    f"relation {self.describe()} has unknown display "
                    f"field {key!r} for kind {self.kind.value!r} "
                    f"(expected: {valid})"
                )
            if not isinstance(value, (int, float)) or isinstance(value, bool):
                raise ValueError(
                    f"relation {self.describe()} display field {key!r} "
                    f"must be a number, got {value!r}"
                )
            if value <= 0:
                raise ValueError(
                    f"relation {self.describe()} display field {key!r} "
                    f"must be > 0, got {value!r}"
                )

    def describe(self) -> str:
        """Stable human identity used in validation errors."""
        return f"{self.kind.value} {self.driver} -> {self.driven}"


# Relation UI hooks -----------------------------------------------------------
#
# The relation equivalents of the mate hooks in ``animacore.mates``
# (``mate_type_schema`` / ``all_mate_type_schemas`` / ``describe_mate``).
# They live here, beside the ``Relation`` model, because the mate module
# does not know the relation vocabulary and ``rig`` already owns it.
#
# Reverse / ratio-sign convention (Kinematics.md §5): the engine stores
# exactly one signed ``ratio``. The UI never edits that sign directly —
# it shows a *magnitude* field plus a "reverse direction" checkbox and
# sends back the signed ratio (``reverse`` ⇔ ``ratio < 0``). So
# ``describe_relation`` splits the stored ratio into ``magnitude`` +
# ``reverse`` for display while keeping the raw signed ``ratio`` as the
# semantic truth.

# Operator-facing label per relation kind (the Rig-ribbon / palette name).
RELATION_KIND_LABELS: dict[RelationKind, str] = {
    RelationKind.GEAR: "Gear",
    RelationKind.RACK_PINION: "Rack and pinion",
    RelationKind.SCREW: "Screw",
    RelationKind.LINEAR: "Linear",
}

# The one editable ratio field each kind shows in its dialog. GEAR and
# LINEAR edit the unitless ratio directly ("Relation ratio"); RACK_PINION
# and SCREW edit distance-per-revolution in mm (the engine stores meters
# per radian — see ``_MM_PER_REVOLUTION_FROM_M_PER_RAD``).
_RELATION_RATIO_FIELDS: dict[RelationKind, dict[str, str]] = {
    RelationKind.GEAR: {"key": "relation_ratio", "unit": "ratio"},
    RelationKind.LINEAR: {"key": "relation_ratio", "unit": "ratio"},
    RelationKind.RACK_PINION: {"key": "distance_per_revolution", "unit": "mm"},
    RelationKind.SCREW: {"key": "distance_per_revolution", "unit": "mm"},
}

# meters-per-radian → millimeters-per-revolution: one revolution is 2π
# radians, and 1 m = 1000 mm. The rack/screw ratio is meters of travel
# per radian of drive, so a full turn advances ``ratio * 2π`` meters =
# ``ratio * 2π * 1000`` mm.
_MM_PER_REVOLUTION_FROM_M_PER_RAD = 2.0 * math.pi * 1000.0


def relation_type_schema(kind: RelationKind) -> dict:
    """The static per-kind relation descriptor the palette/panel reads.

    Mirrors ``mate_type_schema``. ``driver_kind`` / ``driven_kind`` are
    ``"rotation"`` / ``"translation"`` (from ``RELATION_KIND_DOF_KINDS``)
    so the UI knows which mates/DOF are selectable on each side.
    ``ratio_field`` names the kind's one editable field: ``relation_ratio``
    (unitless) for GEAR/LINEAR, ``distance_per_revolution`` (mm) for
    RACK_PINION/SCREW. All four support the "reverse direction" checkbox.
    """
    driver_kind, driven_kind = RELATION_KIND_DOF_KINDS[kind]
    return {
        "kind": kind.value,
        "label": RELATION_KIND_LABELS[kind],
        "driver_kind": driver_kind.value,
        "driven_kind": driven_kind.value,
        "ratio_field": dict(_RELATION_RATIO_FIELDS[kind]),
        "reverse_supported": True,
    }


def all_relation_type_schemas() -> list[dict]:
    """Every relation kind's static schema, in ``RelationKind`` order.

    The four-entry palette hook: Gear, Rack and pinion, Screw, Linear.
    """
    return [relation_type_schema(kind) for kind in RelationKind]


def _relation_ratio_field_value(kind: RelationKind, ratio: float) -> float:
    """The UI-facing (positive) number for ``ratio_field``, per kind.

    GEAR/LINEAR: the unitless magnitude. RACK_PINION/SCREW: the
    distance-per-revolution in mm (``abs(ratio) * 2π * 1000``).
    """
    magnitude = abs(ratio)
    if _RELATION_RATIO_FIELDS[kind]["unit"] == "mm":
        return magnitude * _MM_PER_REVOLUTION_FROM_M_PER_RAD
    return magnitude


def describe_relation(relation: Relation) -> dict:
    """The per-instance relation descriptor the bridge surfaces.

    Mirrors ``describe_mate``. Splits the stored signed ``ratio`` into a
    display ``magnitude`` + ``reverse`` flag (``ratio < 0``) and the
    kind-specific ``ratio_field_value`` (unitless for gear/linear,
    mm-per-revolution for rack_pinion/screw), while keeping the raw
    signed ``ratio`` as the semantic truth. ``display`` passes the
    round-tripped non-semantic fields (teeth, lead, ...) through
    unchanged.
    """
    return {
        "kind": relation.kind.value,
        "driver": relation.driver,
        "driven": relation.driven,
        "ratio": relation.ratio,
        "offset": relation.offset,
        "reverse": relation.ratio < 0,
        "magnitude": abs(relation.ratio),
        "ratio_field_value": _relation_ratio_field_value(
            relation.kind, relation.ratio
        ),
        "display": dict(relation.display),
        "suppressed": relation.suppressed,
    }


def relations_in_dependency_order(
    relations: tuple[Relation, ...],
) -> tuple[Relation, ...]:
    """Order relations so every driver is resolved before its driven.

    Raises ``ValueError`` on a cycle. Deterministic: ready relations
    keep their declaration order (assumes at most one relation per
    driven DOF, which ``Rig`` validates).
    """
    pending = list(relations)
    pending_driven = {relation.driven for relation in pending}
    order: list[Relation] = []
    while pending:
        ready = [
            relation
            for relation in pending
            if relation.driver not in pending_driven
        ]
        if not ready:
            unresolved = ", ".join(
                relation.describe() for relation in pending
            )
            raise ValueError(
                f"relation graph has a cycle (unresolvable: {unresolved})"
            )
        for relation in ready:
            order.append(relation)
            pending.remove(relation)
            pending_driven.discard(relation.driven)
    return tuple(order)


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
class ChainJoint:
    """One Denavit-Hartenberg link of an articulated-arm chain, as a DOF.

    Wraps a :class:`animacore.dh.DHLink`'s four standard-DH parameters
    (``a_m`` / ``d_m`` in metres, ``alpha_rad`` / ``theta_rad`` in
    radians — the file carries metres and degrees) plus the joint
    variable's optional ``min`` / ``max`` limits and ``neutral`` (radians
    for a revolute joint, metres for a prismatic one). ``name`` is the
    joint's DOF name — its addressable DOF path is
    ``"<chain_name>.<name>"``, the same namespace clips target. ``part``
    is the optional rig part that RIDES this link's frame for rendering
    (``resolve_pose`` places it there via DH forward kinematics).

    The joint variable is a real drivable DOF: it validates and clamps
    exactly like a mate DOF (see :meth:`as_dof`), so a chain joint's
    limits and neutral obey the same rules as any other degree of freedom.
    """

    name: str
    a_m: float = 0.0
    alpha_rad: float = 0.0
    d_m: float = 0.0
    theta_rad: float = 0.0
    joint_type: JointKind = JointKind.REVOLUTE
    min: float | None = None
    max: float | None = None
    neutral: float = 0.0
    part: str | None = None

    def __post_init__(self) -> None:
        if not self.name:
            raise ValueError("chain joint name must not be empty")
        if "." in self.name:
            raise ValueError(
                f"chain joint name must not contain '.': {self.name!r}"
            )
        object.__setattr__(self, "joint_type", JointKind(self.joint_type))
        # Validate limits/neutral through the DOF rules (raises on a bad
        # range or an out-of-range neutral) so a chain joint's variable is
        # governed exactly like any mate DOF.
        self.as_dof()

    @property
    def dof_kind(self) -> DofKind:
        """The DOF kind of this link's variable (rotation / translation)."""
        return (
            DofKind.ROTATION
            if self.joint_type is JointKind.REVOLUTE
            else DofKind.TRANSLATION
        )

    def as_dof(self) -> DegreeOfFreedom:
        """This link's joint variable as a rig ``DegreeOfFreedom``.

        A revolute link is a ``RotationDof`` (radians); a prismatic link
        a ``TranslationDof`` (metres). This is what makes a chain joint a
        first-class DOF: clips validate against it and evaluation falls
        back to its neutral, identical to a mate DOF.
        """
        if self.joint_type is JointKind.REVOLUTE:
            return RotationDof(
                name=self.name,
                min_radians=self.min,
                max_radians=self.max,
                neutral_radians=self.neutral,
            )
        return TranslationDof(
            name=self.name,
            min_meters=self.min,
            max_meters=self.max,
            neutral_meters=self.neutral,
        )

    def to_dh_link(self) -> DHLink:
        """This chain joint as a pure :class:`animacore.dh.DHLink`."""
        return DHLink(
            a=self.a_m,
            alpha=self.alpha_rad,
            d=self.d_m,
            theta=self.theta_rad,
            joint_type=self.joint_type,
            min=self.min,
            max=self.max,
            neutral=self.neutral,
        )


@dataclass(frozen=True)
class KinematicChain:
    """A serial Denavit-Hartenberg chain — the articulated-arm rig type.

    A character that declares a ``kinematic_chain`` IS that type: its DH
    joints are the animatable DOF (``"<name>.<joint>"``), clips drive
    them, ``resolve_pose`` places the parts by DH forward kinematics, and
    the bridge can solve inverse kinematics against a target pose. This is
    distinct from the general parts + typed-mate assembly (see
    ``dev/docs/roadmap/DH_Kinematics.md``).

    - ``name`` — the chain id; every joint's DOF path is
      ``"<name>.<joint_name>"``.
    - ``joints`` — the ordered :class:`ChainJoint` list (link order is
      the DH chain order).
    - ``base_part`` — the part the chain is mounted on. The chain's base
      frame is that part's rest transform in character space (identity
      when ``None``); see ``dev/docs/roadmap/Coordinate_Frames.md``.
    - ``tool_part`` — the optional end-effector part, placed at the tool
      pose.
    - ``tool_position_m`` / ``tool_rotation_euler_rad`` — the tool frame
      offset from the last link (file: metres and degrees), default
      identity.
    """

    name: str
    joints: tuple[ChainJoint, ...] = ()
    base_part: str | None = None
    tool_part: str | None = None
    tool_position_m: tuple[float, float, float] = (0.0, 0.0, 0.0)
    tool_rotation_euler_rad: tuple[float, float, float] = (0.0, 0.0, 0.0)

    def __post_init__(self) -> None:
        object.__setattr__(self, "joints", tuple(self.joints))
        if not self.name:
            raise ValueError("kinematic_chain name must not be empty")
        if "." in self.name:
            raise ValueError(
                f"kinematic_chain name must not contain '.': {self.name!r}"
            )
        if not self.joints:
            raise ValueError(
                "kinematic_chain must have at least one joint"
            )
        names = [joint.name for joint in self.joints]
        if len(names) != len(set(names)):
            raise ValueError(
                f"kinematic_chain {self.name!r} has duplicate joint names"
            )
        object.__setattr__(
            self,
            "tool_position_m",
            _as_vec3(self.tool_position_m, self.name, "tool_position_m"),
        )
        object.__setattr__(
            self,
            "tool_rotation_euler_rad",
            _as_vec3(
                self.tool_rotation_euler_rad,
                self.name,
                "tool_rotation_euler_rad",
            ),
        )

    def dof_paths(self) -> dict[str, DegreeOfFreedom]:
        """Each chain joint's DOF, keyed ``"<chain_name>.<joint_name>"``."""
        return {
            f"{self.name}.{joint.name}": joint.as_dof()
            for joint in self.joints
        }

    def tool_frame(self):
        """The end-effector offset from the last link as a ``Transform``."""
        from animacore.kinematics import Transform

        rx, ry, rz = self.tool_rotation_euler_rad
        rotation = Transform.from_euler_xyz(rx, ry, rz).rotation
        return Transform(
            rotation, tuple(float(c) for c in self.tool_position_m)
        )

    def to_dh_chain(self, base_frame) -> DHChain:
        """Build the pure :class:`animacore.dh.DHChain` for FK / IK.

        ``base_frame`` places the chain root in character space (the
        caller resolves it from ``base_part``'s rest transform, or
        identity). The tool frame comes from this chain's tool offset.
        """
        return DHChain(
            links=tuple(joint.to_dh_link() for joint in self.joints),
            base_frame=base_frame,
            tool_frame=self.tool_frame(),
        )


@dataclass(frozen=True)
class Rig:
    """A mechanism's movable structure: what a clip is evaluated against.

    Clip track keys are DOF paths (``"<joint_name>.<dof_name>"``) or
    parameter names, and every key must resolve to a declared DOF or
    parameter. Parameter names never contain ``.`` and DOF paths always
    do, so the two namespaces cannot collide.

    Relation rules (validated here): the graph is acyclic, at most one
    relation drives any DOF, a driven DOF carries no animation tracks
    (one source of truth), and each kind's (driver, driven) DOF-kind
    pairing must match ``RELATION_KIND_DOF_KINDS``. An output mapping
    may not target a DOF without limits — a bounded actuator channel
    needs a range to project to 0..1.
    """

    identity: Identity
    parts: Mapping[str, Part] = field(default_factory=dict)
    joints: Mapping[str, Joint] = field(default_factory=dict)
    parameters: Mapping[str, Parameter] = field(default_factory=dict)
    clips: Mapping[str, RigClip] = field(default_factory=dict)
    outputs: tuple[OutputMapping, ...] = ()
    relations: tuple[Relation, ...] = ()
    kinematic_chain: KinematicChain | None = None

    def __post_init__(self) -> None:
        object.__setattr__(self, "outputs", tuple(self.outputs))
        object.__setattr__(self, "relations", tuple(self.relations))
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
        chain_paths = self.chain_dof_paths()
        if self.kinematic_chain is not None:
            chain = self.kinematic_chain
            for ref, label in (
                (chain.base_part, "base_part"),
                (chain.tool_part, "tool_part"),
            ):
                if ref is not None and ref not in self.parts:
                    raise ValueError(
                        f"kinematic_chain {label} references undeclared part "
                        f"{ref!r}"
                    )
            for joint in chain.joints:
                if joint.part is not None and joint.part not in self.parts:
                    raise ValueError(
                        f"kinematic_chain joint {joint.name!r} references "
                        f"undeclared part {joint.part!r}"
                    )
            for path in chain_paths:
                if path in paths:
                    raise ValueError(
                        f"chain dof {path!r} collides with a mate dof of the "
                        f"same path"
                    )
        # Chain DOF share the mate DOF namespace for clip targeting.
        all_paths = {**paths, **chain_paths}
        driven_by: dict[str, Relation] = {}
        for relation in self.relations:
            expected = RELATION_KIND_DOF_KINDS[relation.kind]
            for role, path, expected_kind in (
                ("driver", relation.driver, expected[0]),
                ("driven", relation.driven, expected[1]),
            ):
                dof = paths.get(path)
                if dof is None:
                    raise ValueError(
                        f"relation {relation.describe()} {role} references "
                        f"undeclared dof {path!r}"
                    )
                if dof.kind is not expected_kind:
                    raise ValueError(
                        f"relation {relation.describe()} {role} must be a "
                        f"{expected_kind.value} dof, got {dof.kind.value} "
                        f"({path!r})"
                    )
            if relation.driven in driven_by:
                raise ValueError(
                    f"dof {relation.driven!r} is driven by two relations: "
                    f"{driven_by[relation.driven].describe()} and "
                    f"{relation.describe()} (at most one driver per dof)"
                )
            driven_by[relation.driven] = relation
        relations_in_dependency_order(self.relations)  # rejects cycles
        for clip_name, rig_clip in self.clips.items():
            for key in rig_clip.clip.tracks:
                if key not in all_paths and key not in self.parameters:
                    raise ValueError(
                        f"clip {clip_name!r} animates unknown target {key!r}"
                    )
                if key in driven_by:
                    raise ValueError(
                        f"clip {clip_name!r} animates {key!r}, which is "
                        f"driven by relation {driven_by[key].describe()}; "
                        f"a driven dof has one source of truth — remove "
                        f"the track or the relation"
                    )
        seen_channels: set[int] = set()
        for mapping in self.outputs:
            dof = all_paths.get(mapping.target)
            if dof is None and mapping.target not in self.parameters:
                raise ValueError(
                    f"output mapping references unknown target "
                    f"{mapping.target!r}"
                )
            if dof is not None and not dof.has_limits:
                raise ValueError(
                    f"output mapping on channel {mapping.channel} targets "
                    f"unlimited dof {mapping.target!r}: a bounded actuator "
                    f"channel needs a dof range to project to 0..1 — add "
                    f"limits to the dof or remove the mapping"
                )
            if mapping.channel in seen_channels:
                raise ValueError(f"duplicate output channel: {mapping.channel}")
            seen_channels.add(mapping.channel)

    def dof_paths(self) -> dict[str, DegreeOfFreedom]:
        """Every addressable mate DOF, keyed ``"<joint_name>.<dof_name>"``.

        Chain-joint DOF are addressed the same way but reported separately
        by :meth:`chain_dof_paths` (their prefix is the chain name, not a
        mate joint name, so mate-joint lookups on the prefix stay valid).
        """
        paths: dict[str, DegreeOfFreedom] = {}
        for joint in self.joints.values():
            paths.update(joint.dof_paths())
        return paths

    def chain_dof_paths(self) -> dict[str, DegreeOfFreedom]:
        """The kinematic chain's DOF, keyed ``"<chain_name>.<joint_name>"``.

        Empty for a non-chain (general assembly) rig. These share the DOF
        path namespace with mate DOF for clip targeting; ``Rig`` rejects a
        collision between the two.
        """
        if self.kinematic_chain is None:
            return {}
        return self.kinematic_chain.dof_paths()

    def dh_chain(self) -> DHChain:
        """The pure :class:`animacore.dh.DHChain` for FK / IK.

        The base frame is ``base_part``'s rest transform in character
        space (identity when no ``base_part``), so FK/IK link frames and
        the tool pose come out in character space — consistent with
        ``resolve_pose``. Raises ``ValueError`` when the rig has no chain.
        """
        if self.kinematic_chain is None:
            raise ValueError("rig has no kinematic_chain")
        from animacore.kinematics import IDENTITY, part_rest_transform

        chain = self.kinematic_chain
        base_frame = (
            part_rest_transform(self.parts[chain.base_part])
            if chain.base_part is not None
            else IDENTITY
        )
        return chain.to_dh_chain(base_frame)


@dataclass(frozen=True)
class LimitViolation:
    """A relation-driven DOF evaluated outside its enabled limits.

    Values are in the DOF's native units (radians / meters). Per
    Kinematics.md §5 the relation always computes and nothing clamps —
    the violation is reported here, and ``project_channels`` refuses
    to project the violated DOF.
    """

    dof_path: str
    value: float
    min_value: float
    max_value: float


class LimitViolationError(ValueError):
    """Channel projection refused: a mapped DOF is outside its limits."""


@dataclass(frozen=True)
class Pose:
    """One evaluated rig state.

    ``dof_values`` is keyed by DOF path in each DOF's native units
    (radians for rotation, meters for translation); ``parameter_values``
    is keyed by parameter name, 0..1. ``limit_violations`` lists every
    relation-driven DOF whose computed value exited its enabled limits
    (in relation dependency order); it is empty for a rig without
    relations, because clip values are load-validated against limits
    and neutrals must lie within them.
    """

    dof_values: Mapping[str, float]
    parameter_values: Mapping[str, float]
    limit_violations: tuple[LimitViolation, ...] = ()


def evaluate_pose(
    rig: Rig, clip_name: str | None = None, time_seconds: float = 0.0
) -> Pose:
    """Evaluate the rig at ``time_seconds``, deterministically.

    ``clip_name`` selects one of ``rig.clips``; ``None`` gives the
    neutral pose. Every DOF or parameter the clip does not animate
    falls back to its neutral. Looping clips wrap time modulo the
    duration; non-looping clips clamp.

    Order per Kinematics.md §5: driver DOF resolve from the clip (or
    neutral), relations apply in dependency order, then limits — a
    driven value outside its enabled limits is reported in
    ``Pose.limit_violations``, never clamped.

    Object states (persistent, per-element — no cascade): a **suppressed
    joint** contributes no driven DOF — its DOF are not read from the
    clip and never appear in ``dof_values`` (they are simply not part of
    the active solve). A **suppressed relation** is skipped in the
    dependency pass, so its driven DOF keeps its own neutral. A relation
    whose driver/driven DOF belongs to a suppressed joint is also skipped
    (that DOF is not in the active solve), avoiding a dangling reference.
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

    # A suppressed joint's DOF are excluded from the active solve: joint
    # names carry no '.', so the path prefix before the first '.' is the
    # joint name.
    paths = {
        path: dof
        for path, dof in rig.dof_paths().items()
        if not rig.joints[path.split(".", 1)[0]].suppressed
    }
    # Chain-joint DOF are always active (a chain has no per-joint
    # suppression); they drive DH forward kinematics in ``resolve_pose``.
    paths.update(rig.chain_dof_paths())
    dof_values = {
        path: animated.get(path, dof.neutral) for path, dof in paths.items()
    }
    # Skip a suppressed relation, and one whose driver/driven DOF is not
    # in the active solve (belongs to a suppressed joint).
    # ponytail: suppression is strictly per-element — there is no cascade
    # here (suppressing a joint does not touch its parts, or vice versa).
    # The UI composes folder-level effects by suppressing each member.
    active_relations = tuple(
        relation
        for relation in rig.relations
        if not relation.suppressed
        and relation.driver in dof_values
        and relation.driven in dof_values
    )
    violations: list[LimitViolation] = []
    for relation in relations_in_dependency_order(active_relations):
        driven_value = (
            relation.ratio * dof_values[relation.driver] + relation.offset
        )
        dof_values[relation.driven] = driven_value
        dof = paths[relation.driven]
        if dof.has_limits and not dof.minimum <= driven_value <= dof.maximum:
            violations.append(
                LimitViolation(
                    dof_path=relation.driven,
                    value=driven_value,
                    min_value=dof.minimum,
                    max_value=dof.maximum,
                )
            )

    return Pose(
        dof_values=dof_values,
        parameter_values={
            name: animated.get(name, parameter.neutral_value)
            for name, parameter in rig.parameters.items()
        },
        limit_violations=tuple(violations),
    )


def project_channels(rig: Rig, pose: Pose) -> dict[int, float]:
    """Project a pose's mapped targets to normalized 0..1 channel values.

    The result is exactly what ``wire.encode_frm`` takes. Unmapped DOF
    and parameters are omitted. A mapping whose target is in
    ``pose.limit_violations`` raises ``LimitViolationError`` — hardware
    must refuse to arm on a violated pose, never clamp it.
    """
    violated = {
        violation.dof_path: violation
        for violation in pose.limit_violations
    }
    channels: dict[int, float] = {}
    for mapping in rig.outputs:
        violation = violated.get(mapping.target)
        if violation is not None:
            raise LimitViolationError(
                f"channel {mapping.channel} target {mapping.target!r} is "
                f"outside its limits ({violation.value} not in "
                f"[{violation.min_value}, {violation.max_value}]); "
                f"refusing to project a violated dof to hardware"
            )
        if "." in mapping.target:
            value = pose.dof_values[mapping.target]
        else:
            value = pose.parameter_values[mapping.target]
        channels[mapping.channel] = mapping.channel_value(value)
    return channels
