"""Mate authoring model: typed mate kinds, per-kind DOF, and the
universal connector/offset/flip/orient controls every mate exposes.

A mate (an Onshape-style typed ``Joint`` in ``animacore.rig``) aligns
two mate connectors and, by its kind alone, defines which of the six
physical freedoms remain as controllable ``DegreeOfFreedom``. This
module is the single home for that vocabulary and for the *universal
controls* — the connector pair, the as-mated offset, the primary-axis
flip, the secondary-axis 90° reorientation, and the simulation-
connection toggle — that are identical across all eight kinds so the
UI has one consistent hook. Only the DOF set differs per kind
(``JOINT_TYPE_DOF_TEMPLATES``).

Two UI seams live here:

- ``mate_type_schema`` / ``all_mate_type_schemas`` — the *static*
  per-kind descriptor (label, DOF slots, the shared universal-control
  ids) the palette/panel-builder reads.
- ``describe_mate`` — the *per-instance* descriptor (stable id, name,
  parts, every control's current value, DOF paths + limits) the bridge
  surfaces for one loaded mate.

Kinematics is the contract (``dev/docs/roadmap/Kinematics.md`` §1 DOF,
§2 limits, §4 flip/reorient/offsets): this module unifies §4's flip,
reorient, and offset into one ``MateControls`` value. Physics/dynamics
stays deferred; the headless engine round-trips connectors and offsets
without spatial math — Studio consumes them geometrically.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import IntEnum, StrEnum
from typing import TYPE_CHECKING, ClassVar

if TYPE_CHECKING:
    from animacore.rig import Joint


class DofKind(StrEnum):
    ROTATION = "rotation"
    TRANSLATION = "translation"


class JointType(StrEnum):
    """Typed mates, modeled on Onshape mate connectors.

    The first eight are *kinematic* mates (abstract connector frames +
    DOF; the engine owns their motion fully). ``WIDTH`` and ``TANGENT``
    are *geometry-constraint* mates that depend on real surface geometry
    — which lives app-side (RealityKit), not in this abstract engine.
    The engine recognizes and round-trips them and exposes them in the
    catalog, but their geometry is resolved app-side (see
    ``MateCategory`` / ``mate_category``).
    """

    FASTENED = "fastened"
    PARALLEL = "parallel"
    REVOLUTE = "revolute"
    PRISMATIC = "prismatic"
    CYLINDRICAL = "cylindrical"
    PIN_SLOT = "pin_slot"
    PLANAR = "planar"
    BALL = "ball"
    # Geometry-constraint mates (app-resolved geometry; see MateCategory).
    WIDTH = "width"
    TANGENT = "tangent"


class MateCategory(StrEnum):
    """How a mate's spatial resolution is owned.

    ``KINEMATIC`` — the eight Onshape-style mates: abstract connector
    frames plus DOF, resolved entirely by the engine's forward
    kinematics. ``GEOMETRY_CONSTRAINT`` — ``width`` and ``tangent``:
    their placement depends on real surface geometry, which lives in the
    app (RealityKit), so the engine recognizes and round-trips them but
    the geometry is resolved app-side.
    """

    KINEMATIC = "kinematic"
    GEOMETRY_CONSTRAINT = "geometry_constraint"


# The geometry-constraint mates — everything else is kinematic.
_GEOMETRY_CONSTRAINT_TYPES: frozenset[JointType] = frozenset(
    {JointType.WIDTH, JointType.TANGENT}
)


def mate_category(joint_type: JointType) -> MateCategory:
    """The category a mate kind belongs to (kinematic vs geometry)."""
    if joint_type in _GEOMETRY_CONSTRAINT_TYPES:
        return MateCategory.GEOMETRY_CONSTRAINT
    return MateCategory.KINEMATIC


# Operator-facing label per kind (the UI catalog name; ``prismatic`` is
# shown as "Slider", per the Studio ribbon and Kinematics.md §1).
JOINT_TYPE_LABELS: dict[JointType, str] = {
    JointType.FASTENED: "Fastened",
    JointType.PARALLEL: "Parallel",
    JointType.REVOLUTE: "Revolute",
    JointType.PRISMATIC: "Slider",
    JointType.CYLINDRICAL: "Cylindrical",
    JointType.PIN_SLOT: "Pin Slot",
    JointType.PLANAR: "Planar",
    JointType.BALL: "Ball",
    JointType.WIDTH: "Width",
    JointType.TANGENT: "Tangent",
}


# Each joint type DEFINES its DOF set: the ordered (default name, kind)
# pairs a joint of that type must carry. Authors may rename a DOF but
# cannot add, drop, or re-kind one.
# Each entry is (dof name, kind, canonical axis). The axis is the
# connector-frame axis the DOF acts on — the UI needs it to label a
# Slider's travel as Z↕ but a Pin Slot's as X↔ (both are one bare
# "translation" DOF). Matches the Onshape mate dialogs: every rotation
# is about Z except Ball's three; Slider/Cylindrical translate along Z,
# Pin Slot along X, Planar/Parallel along X/Y(/Z).
JOINT_TYPE_DOF_TEMPLATES: dict[JointType, tuple[tuple[str, DofKind, str], ...]] = {
    JointType.FASTENED: (),
    # Parallel keeps the connector axes parallel: free XYZ translation
    # plus rotation about the shared Z axis — no tilting.
    JointType.PARALLEL: (
        ("translation_x", DofKind.TRANSLATION, "x"),
        ("translation_y", DofKind.TRANSLATION, "y"),
        ("translation_z", DofKind.TRANSLATION, "z"),
        ("rotation", DofKind.ROTATION, "z"),
    ),
    JointType.REVOLUTE: (("rotation", DofKind.ROTATION, "z"),),
    JointType.PRISMATIC: (("translation", DofKind.TRANSLATION, "z"),),
    JointType.CYLINDRICAL: (
        ("rotation", DofKind.ROTATION, "z"),
        ("translation", DofKind.TRANSLATION, "z"),
    ),
    JointType.PIN_SLOT: (
        ("rotation", DofKind.ROTATION, "z"),
        ("translation", DofKind.TRANSLATION, "x"),
    ),
    JointType.PLANAR: (
        ("translation_x", DofKind.TRANSLATION, "x"),
        ("translation_y", DofKind.TRANSLATION, "y"),
        ("rotation", DofKind.ROTATION, "z"),
    ),
    JointType.BALL: (
        ("rotation_x", DofKind.ROTATION, "x"),
        ("rotation_y", DofKind.ROTATION, "y"),
        ("rotation_z", DofKind.ROTATION, "z"),
    ),
    # Geometry-constraint mates expose no engine-drivable DOF: WIDTH
    # resolves to a centered 0-DOF fastened once the app supplies the
    # two midplane connectors; TANGENT's contact is app-resolved.
    JointType.WIDTH: (),
    JointType.TANGENT: (),
}


def _template_axes(joint_type: JointType) -> tuple[str, ...]:
    """The canonical axis per DOF, in template order (joint.dofs order)."""
    return tuple(axis for _, _, axis in JOINT_TYPE_DOF_TEMPLATES[joint_type])


def dof_unit(kind: DofKind) -> str:
    """The native model unit for a DOF kind (radians / meters)."""
    return "radians" if kind is DofKind.ROTATION else "meters"


def _validate_dof(
    name: str,
    minimum: float | None,
    maximum: float | None,
    neutral: float,
    axis: tuple[float, float, float] | None,
    unit: str,
) -> None:
    if not name:
        raise ValueError("dof name must not be empty")
    if "." in name:
        raise ValueError(f"dof name must not contain '.': {name!r}")
    if (minimum is None) != (maximum is None):
        raise ValueError(
            f"dof {name!r} limits must set both min and max or neither "
            f"(an unlimited dof has no partial range)"
        )
    if minimum is not None and maximum is not None:
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
    """One rotational degree of freedom; limits and neutral in radians.

    Limits are optional (``None``/``None`` = continuous rotation, e.g.
    a wheel); when present they are hard stops. Neutral is always
    required and, when limits are present, must lie within them.
    """

    name: str
    min_radians: float | None = None
    max_radians: float | None = None
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
    def has_limits(self) -> bool:
        return self.min_radians is not None

    @property
    def minimum(self) -> float | None:
        return self.min_radians

    @property
    def maximum(self) -> float | None:
        return self.max_radians

    @property
    def neutral(self) -> float:
        return self.neutral_radians


@dataclass(frozen=True)
class TranslationDof:
    """One translational degree of freedom; limits and neutral in meters.

    Limits are optional (``None``/``None`` = unbounded travel); when
    present they are hard stops. Neutral is always required and, when
    limits are present, must lie within them.
    """

    name: str
    min_meters: float | None = None
    max_meters: float | None = None
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
    def has_limits(self) -> bool:
        return self.min_meters is not None

    @property
    def minimum(self) -> float | None:
        return self.min_meters

    @property
    def maximum(self) -> float | None:
        return self.max_meters

    @property
    def neutral(self) -> float:
        return self.neutral_meters


DegreeOfFreedom = RotationDof | TranslationDof


# Universal mate controls -----------------------------------------------------


class RotationAxis(StrEnum):
    """A connector-frame axis a mate offset may rotate about."""

    X = "x"
    Y = "y"
    Z = "z"


class SecondaryAxisRotation(IntEnum):
    """The four 90° secondary-axis reorientation steps (degrees)."""

    DEG_0 = 0
    DEG_90 = 90
    DEG_180 = 180
    DEG_270 = 270


_AXIS_EPS = 1e-9


def _clean_axis(axis: tuple[float, float, float], label: str) -> tuple[
    float, float, float
]:
    axis = tuple(float(component) for component in axis)
    if len(axis) != 3:
        raise ValueError(f"{label} must have 3 components, got {axis!r}")
    if all(component == 0.0 for component in axis):
        raise ValueError(f"{label} must not be all zero")
    return axis


def _cross(
    a: tuple[float, float, float], b: tuple[float, float, float]
) -> tuple[float, float, float]:
    return (
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    )


@dataclass(frozen=True)
class MateConnector:
    """One side's part-local mate connector frame (Kinematics.md §0).

    A connector is an origin plus an oriented basis on ``part``:
    ``primary_axis`` is the connector Z (the axis a revolute turns
    about, a slider travels along), ``secondary_axis`` is the connector
    X (pin-slot's slot direction, and the reference the 90° secondary
    reorientation steps from). ``flipped`` reverses the primary axis for
    this side; ``feature`` is opaque provenance (which inferred
    face/edge/axis the connector snapped to) the runtime never
    interprets. Axes must be non-zero and non-parallel — a degenerate
    frame cannot define a mate.
    """

    part: str
    origin_m: tuple[float, float, float] = (0.0, 0.0, 0.0)
    primary_axis: tuple[float, float, float] = (0.0, 0.0, 1.0)
    secondary_axis: tuple[float, float, float] = (1.0, 0.0, 0.0)
    flipped: bool = False
    feature: str = ""

    def __post_init__(self) -> None:
        if not self.part:
            raise ValueError("connector part must not be empty")
        origin = tuple(float(component) for component in self.origin_m)
        if len(origin) != 3:
            raise ValueError(
                f"connector origin_m must have 3 components, got "
                f"{self.origin_m!r}"
            )
        object.__setattr__(self, "origin_m", origin)
        primary = _clean_axis(self.primary_axis, "connector primary_axis")
        secondary = _clean_axis(
            self.secondary_axis, "connector secondary_axis"
        )
        object.__setattr__(self, "primary_axis", primary)
        object.__setattr__(self, "secondary_axis", secondary)
        cross = _cross(primary, secondary)
        if sum(component * component for component in cross) <= _AXIS_EPS:
            raise ValueError(
                "connector primary_axis and secondary_axis must not be "
                f"parallel (primary={primary!r}, secondary={secondary!r})"
            )


@dataclass(frozen=True)
class MateOffset:
    """The as-mated offset between the two aligned connector frames.

    Kinematics.md §4: a translation along the connector-frame axes in
    meters plus a rotation about one connector axis in radians, applied
    before DOF values shift the pose. ``enabled`` mirrors the Onshape
    dialog's Offset checkbox (a disabled offset round-trips its stored
    values but is inert). Files carry degrees; the model carries
    radians. The headless runtime stores it for round-trip only —
    Studio consumes it spatially.
    """

    enabled: bool = False
    translation_m: tuple[float, float, float] = (0.0, 0.0, 0.0)
    rotation_axis: RotationAxis = RotationAxis.Z
    rotation_radians: float = 0.0

    def __post_init__(self) -> None:
        translation = tuple(float(c) for c in self.translation_m)
        if len(translation) != 3:
            raise ValueError(
                f"offset translation_m must have 3 components, got "
                f"{self.translation_m!r}"
            )
        object.__setattr__(self, "translation_m", translation)
        object.__setattr__(
            self, "rotation_axis", RotationAxis(self.rotation_axis)
        )


@dataclass(frozen=True)
class MateControls:
    """The universal controls every mate exposes, kind-independent.

    Identical across all eight kinds (only the DOF set differs), so the
    UI binds one panel: the two flippable connectors, the as-mated
    ``offset``, a primary-axis flip on the mate as a whole, the
    secondary-axis reorientation in 90° steps, and the Onshape
    "simulation connection" toggle.
    """

    connector_a: MateConnector | None = None
    connector_b: MateConnector | None = None
    offset: MateOffset = field(default_factory=MateOffset)
    flip_primary_axis: bool = False
    secondary_axis_rotation_deg: int = 0
    simulation_connection: bool = True

    def __post_init__(self) -> None:
        try:
            SecondaryAxisRotation(self.secondary_axis_rotation_deg)
        except ValueError:
            allowed = ", ".join(
                str(step.value) for step in SecondaryAxisRotation
            )
            raise ValueError(
                f"secondary_axis_rotation_deg must be one of ({allowed}), "
                f"got {self.secondary_axis_rotation_deg!r}"
            ) from None


# The shared control ids, in panel order — the one universal-controls
# list the kinematic static schema advertises and the UI builds its hook
# from. (Geometry-constraint mates advertise their own reduced/distinct
# control lists — see ``_TYPE_CONTROL_IDS``.)
UNIVERSAL_CONTROL_IDS: tuple[str, ...] = (
    "connector_a",
    "connector_b",
    "offset",
    "flip_primary_axis",
    "secondary_axis_rotation",
    "simulation_connection",
)


# The control ids each geometry-constraint mate exposes. WIDTH keeps the
# two (app-computed midplane) connectors, the whole-mate flip, and the
# simulation toggle — but NO offset and NO secondary reorientation
# (Onshape allows no offset on Width). TANGENT uses no mate connectors
# and no offset; it carries two opaque surface selections plus a
# propagation flag.
_WIDTH_CONTROL_IDS: tuple[str, ...] = (
    "connector_a",
    "connector_b",
    "flip_primary_axis",
    "simulation_connection",
)
_TANGENT_CONTROL_IDS: tuple[str, ...] = (
    "tangent_selection_a",
    "tangent_selection_b",
    "tangent_propagation",
    "simulation_connection",
)


def _type_control_ids(joint_type: JointType) -> tuple[str, ...]:
    """The control ids a mate kind exposes (kind-specific for geometry)."""
    if joint_type is JointType.WIDTH:
        return _WIDTH_CONTROL_IDS
    if joint_type is JointType.TANGENT:
        return _TANGENT_CONTROL_IDS
    return UNIVERSAL_CONTROL_IDS


# The app-resolved-geometry note the two geometry-constraint schemas
# carry so a UI reader knows the engine does not drive them.
_GEOMETRY_CONSTRAINT_NOTES: dict[JointType, str] = {
    JointType.WIDTH: (
        "Geometry-constraint mate: the app selects two faces on a tab "
        "part and two faces on a width part and centers the tab "
        "symmetrically between them (midplane to midplane). No offset. "
        "Once the app supplies the two computed midplane connectors the "
        "engine resolves it as a 0-DOF fastened at the centered position."
    ),
    JointType.TANGENT: (
        "Geometry-constraint mate: forces two surfaces (face/edge/vertex) "
        "to stay in contact. No mate connectors, no offset; its free DOF "
        "are geometry-dependent. Deferred — the engine has no geometry "
        "kernel, so it recognizes and round-trips the mate and marks it "
        "non-driving (not for use as a driving mate). Contact is resolved "
        "app-side."
    ),
}


@dataclass(frozen=True)
class TangentSpec:
    """A tangent mate's two contacting surface selections (round-trip).

    ``selection_a`` / ``selection_b`` are opaque app-side surface
    identifiers (face/edge/vertex on the two parts) the engine never
    interprets — it has no geometry kernel. ``propagation`` mirrors
    Onshape's tangent-propagation option (extend contact across tangent-
    connected faces). Carried for round-trip only; contact is resolved
    app-side.
    """

    selection_a: str
    selection_b: str
    propagation: bool = True

    def __post_init__(self) -> None:
        if not self.selection_a:
            raise ValueError("tangent selection_a must not be empty")
        if not self.selection_b:
            raise ValueError("tangent selection_b must not be empty")


# UI hooks --------------------------------------------------------------------


def _dof_slots(joint_type: JointType) -> list[dict]:
    return [
        {"name": name, "kind": kind.value, "unit": dof_unit(kind), "axis": axis}
        for name, kind, axis in JOINT_TYPE_DOF_TEMPLATES[joint_type]
    ]


def mate_type_schema(joint_type: JointType) -> dict:
    """The static per-kind descriptor the palette/panel-builder reads.

    Every schema carries a ``category`` (``kinematic`` for the eight
    engine-driven mates, ``geometry_constraint`` for width/tangent) and
    a ``drivable`` flag (true for the eight, false for the geometry pair
    — the engine does not drive them). ``universal_controls`` is the id
    list *this kind* exposes: the shared six for kinematic kinds, a
    reduced/distinct list for width/tangent. Geometry-constraint kinds
    also carry a ``note`` explaining the geometry is app-resolved.
    """
    category = mate_category(joint_type)
    schema = {
        "type": joint_type.value,
        "label": JOINT_TYPE_LABELS[joint_type],
        "category": category.value,
        "drivable": category is MateCategory.KINEMATIC,
        "dof_count": len(JOINT_TYPE_DOF_TEMPLATES[joint_type]),
        "universal_controls": list(_type_control_ids(joint_type)),
        "dofs": _dof_slots(joint_type),
    }
    if joint_type in _GEOMETRY_CONSTRAINT_NOTES:
        schema["note"] = _GEOMETRY_CONSTRAINT_NOTES[joint_type]
    return schema


def all_mate_type_schemas() -> list[dict]:
    """Every kind's static schema, in ``JointType`` order (the palette).

    Ten schemas: the eight kinematic mates then the two
    geometry-constraint mates (width, tangent).
    """
    return [mate_type_schema(joint_type) for joint_type in JointType]


def _connector_dict(connector: MateConnector | None) -> dict | None:
    if connector is None:
        return None
    return {
        "part": connector.part,
        "origin_m": list(connector.origin_m),
        "primary_axis": list(connector.primary_axis),
        "secondary_axis": list(connector.secondary_axis),
        "flipped": connector.flipped,
        "feature": connector.feature,
    }


def _offset_dict(offset: MateOffset) -> dict:
    # Native units, like the DOF descriptors: radians here, the app
    # formats to degrees for display.
    return {
        "enabled": offset.enabled,
        "translation_m": list(offset.translation_m),
        "rotation_axis": offset.rotation_axis.value,
        "rotation_radians": offset.rotation_radians,
    }


def controls_dict(controls: MateControls | None) -> dict:
    """A ``MateControls`` (or its default when absent) as plain JSON."""
    if controls is None:
        controls = MateControls()
    return {
        "connectors": {
            "a": _connector_dict(controls.connector_a),
            "b": _connector_dict(controls.connector_b),
        },
        "offset": _offset_dict(controls.offset),
        "flip_primary_axis": controls.flip_primary_axis,
        "secondary_axis_rotation_deg": controls.secondary_axis_rotation_deg,
        "simulation_connection": controls.simulation_connection,
    }


def _tangent_dict(spec: TangentSpec | None) -> dict:
    """A ``TangentSpec`` (or empty default when absent) as plain JSON."""
    if spec is None:
        return {"selection_a": "", "selection_b": "", "propagation": True}
    return {
        "selection_a": spec.selection_a,
        "selection_b": spec.selection_b,
        "propagation": spec.propagation,
    }


def describe_mate(joint: Joint) -> dict:
    """The per-instance descriptor the bridge surfaces for one mate.

    THE consistent per-mate hook: a mate's stable ``id`` (distinct from
    the editable ``name``), its ``category``, parts, DOF paths + limits
    in native units, and its controls. Kinematic mates and ``width``
    carry a ``controls`` block (the connector/offset/flip/simulation
    universal controls — width's two connectors are the app-computed
    midplanes, its offset inert). ``tangent`` carries no mate connectors;
    it reports a distinct ``tangent`` block ``{selection_a, selection_b,
    propagation}`` instead.
    """
    described = {
        "id": joint.id,
        "name": joint.name,
        "type": joint.joint_type.value,
        "category": mate_category(joint.joint_type).value,
        "parent_part": joint.parent_part,
        "child_part": joint.child_part,
        "dofs": [
            {
                "path": f"{joint.name}.{dof.name}",
                "kind": dof.kind.value,
                "unit": dof_unit(dof.kind),
                "axis": axis,
                "min": dof.minimum,
                "max": dof.maximum,
                "neutral": dof.neutral,
            }
            for dof, axis in zip(joint.dofs, _template_axes(joint.joint_type))
        ],
    }
    if joint.joint_type is JointType.TANGENT:
        described["tangent"] = _tangent_dict(getattr(joint, "tangent", None))
    else:
        described["controls"] = controls_dict(joint.controls)
    return described
