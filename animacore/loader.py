"""Load ``.character.anima`` YAML into the runtime mechanism rig model.

Parses the character-format 2.0 subset that ``animacore.rig``
models — identity, parts, typed joints with per-DOF optional ``limits``
blocks and per-joint ``offset`` blocks (``_deg`` degree keys and ``_m``
meter keys in the file; radians and meters in the model), generic 0..1
parameters, hold/linear clips whose tracks are keyed by DOF path or
parameter name, the ``relations`` DOF-coupling list, and the target →
normalized output-channel mappings — and rejects, with a
``CharacterFormatError``
naming the offending path, every spec section this runtime does not
execute yet (``expressions``, ``lip_sync``, ``digital``, ``voice``)
and every format-1.0 section superseded by the mechanism model
(``bones``, ``blend_shapes``, ``physical``) rather than silently
dropping or mistranslating it. Spec:
``dev/docs/roadmap/Character_Format.md``.
"""

from __future__ import annotations

import math
from pathlib import Path

import yaml

from animacore.mates import (
    MateConnector,
    MateControls,
    MateOffset,
    RotationAxis,
    SecondaryAxisRotation,
    TangentSpec,
)
from animacore.rig import (
    JOINT_TYPE_DOF_TEMPLATES,
    RELATION_DISPLAY_KEYS,
    RELATION_KIND_DOF_KINDS,
    DegreeOfFreedom,
    DofKind,
    Identity,
    Joint,
    JointType,
    OutputMapping,
    Parameter,
    Part,
    Relation,
    RelationKind,
    Rig,
    RigClip,
    RotationDof,
    TranslationDof,
)
from animacore.tracks import Clip, Interpolation, Keyframe, Track

SUPPORTED_ANIMA_VERSION = "2.0"
SUPPORTED_TYPE = "character"

# Spec sections the runtime does not execute yet. Kept explicit so a
# file using them fails loudly instead of playing back incompletely.
_UNSUPPORTED_TOP_LEVEL = ("expressions", "lip_sync", "digital", "voice")

# Format-1.0 sections replaced by the parts/joints/DOF model.
_SUPERSEDED_TOP_LEVEL = ("blend_shapes", "bones", "physical")

# Per-DOF-kind limit/neutral keys: explicit units in the file, always.
# min/max live inside the optional per-DOF ``limits`` block; the
# neutral key sits beside it on the dof entry.
_DOF_LIMIT_KEYS: dict[DofKind, tuple[str, str, str]] = {
    DofKind.ROTATION: ("min_deg", "max_deg", "neutral_deg"),
    DofKind.TRANSLATION: ("min_m", "max_m", "neutral_m"),
}

# Per-driven-DOF-kind relation offset key (mirrors the outputs
# ``range_deg``/``range_m`` pattern).
_RELATION_OFFSET_KEYS: dict[DofKind, str] = {
    DofKind.ROTATION: "offset_deg",
    DofKind.TRANSLATION: "offset_m",
}


class CharacterFormatError(ValueError):
    """A character file that cannot be loaded; ``path`` names the field."""

    def __init__(self, path: str, message: str):
        super().__init__(f"{path}: {message}")
        self.path = path
        self.message = message


def load_character_file(file_path: str | Path) -> Rig:
    """Read and parse one ``.character.anima`` file."""
    return parse_character(Path(file_path).read_text(encoding="utf-8"))


def parse_character(text: str) -> Rig:
    """Parse ``.character.anima`` YAML text into a validated ``Rig``."""
    try:
        document = yaml.safe_load(text)
    except yaml.YAMLError as error:
        raise CharacterFormatError(
            "<document>", f"not valid YAML: {error}"
        ) from error
    document = _mapping(document, "<document>")

    _check_header(document)
    _check_top_level_fields(document)

    identity = _parse_identity(_mapping(document["identity"], "identity"))
    parts = _parse_parts(document.get("parts"))
    joints = _parse_joints(document.get("joints"), parts)
    parameters = _parse_parameters(document.get("parameters"))
    dof_paths: dict[str, DegreeOfFreedom] = {}
    for joint in joints.values():
        dof_paths.update(joint.dof_paths())
    clips = _parse_clips(document.get("clips"), dof_paths, parameters)
    outputs = _parse_outputs(document.get("outputs"), dof_paths, parameters)
    relations = _parse_relations(document.get("relations"), dof_paths)

    try:
        return Rig(
            identity=identity,
            parts=parts,
            joints=joints,
            parameters=parameters,
            clips=clips,
            outputs=outputs,
            relations=relations,
        )
    except ValueError as error:
        # Rig re-validates cross-references; the checks above should
        # have produced a pathed error first, but never swallow one.
        raise CharacterFormatError("<document>", str(error)) from error


# Header and section dispatch ------------------------------------------------


def _check_header(document: dict) -> None:
    version = document.get("anima_version")
    if version is None:
        raise CharacterFormatError("anima_version", "missing required field")
    if version != SUPPORTED_ANIMA_VERSION:
        raise CharacterFormatError(
            "anima_version",
            f"unsupported version {version!r} "
            f"(expected {SUPPORTED_ANIMA_VERSION!r})",
        )
    file_type = document.get("type")
    if file_type is None:
        raise CharacterFormatError("type", "missing required field")
    if file_type != SUPPORTED_TYPE:
        raise CharacterFormatError(
            "type", f"expected {SUPPORTED_TYPE!r}, got {file_type!r}"
        )
    if "identity" not in document:
        raise CharacterFormatError("identity", "missing required section")


def _check_top_level_fields(document: dict) -> None:
    supported = {
        "anima_version",
        "type",
        "identity",
        "parts",
        "joints",
        "parameters",
        "clips",
        "outputs",
        "relations",
    }
    for key in document:
        if key in _UNSUPPORTED_TOP_LEVEL:
            raise CharacterFormatError(
                str(key),
                "spec section not supported by the runtime loader yet",
            )
        if key in _SUPERSEDED_TOP_LEVEL:
            raise CharacterFormatError(
                str(key),
                "format-1.0 section superseded in 2.0 "
                "(use parts/joints/parameters/outputs)",
            )
        if key not in supported:
            raise CharacterFormatError(str(key), "unknown field")


# Sections --------------------------------------------------------------------


def _parse_identity(raw: dict) -> Identity:
    _reject_unknown_fields(
        raw,
        "identity",
        {"name", "display_name", "description", "version", "author"},
    )
    if "name" not in raw:
        raise CharacterFormatError("identity.name", "missing required field")
    name = _string(raw["name"], "identity.name")
    if not name:
        raise CharacterFormatError("identity.name", "must not be empty")
    return Identity(
        name=name,
        display_name=_string(
            raw.get("display_name", ""), "identity.display_name"
        ),
        description=_string(
            raw.get("description", ""), "identity.description"
        ),
        version=_string(raw.get("version", ""), "identity.version"),
        author=_string(raw.get("author", ""), "identity.author"),
    )


def _parse_parts(raw: object) -> dict[str, Part]:
    if raw is None:
        return {}
    section = _mapping(raw, "parts")
    declared = {str(name) for name in section}
    parts: dict[str, Part] = {}
    for name, entry in section.items():
        path = f"parts.{name}"
        entry = _mapping(entry if entry is not None else {}, path)
        _reject_unknown_fields(
            entry, path, {"parent", "model_node", "description"}
        )
        parent = entry.get("parent")
        if parent is not None:
            parent = _string(parent, f"{path}.parent")
            if parent not in declared:
                raise CharacterFormatError(
                    f"{path}.parent", "references an undeclared part"
                )
        model_node = entry.get("model_node")
        if model_node is not None:
            model_node = _string(model_node, f"{path}.model_node")
        try:
            parts[str(name)] = Part(
                name=str(name),
                parent=parent,
                model_node=model_node,
                description=_string(
                    entry.get("description", ""), f"{path}.description"
                ),
            )
        except ValueError as error:
            raise CharacterFormatError(path, str(error)) from error
    return parts


def _parse_joints(raw: object, parts: dict[str, Part]) -> dict[str, Joint]:
    if raw is None:
        return {}
    joints: dict[str, Joint] = {}
    for name, entry in _mapping(raw, "joints").items():
        path = f"joints.{name}"
        entry = _mapping(entry, path)
        for required in ("type", "parent", "child"):
            if required not in entry:
                raise CharacterFormatError(
                    f"{path}.{required}", "missing required field"
                )
        try:
            joint_type = JointType(entry["type"])
        except ValueError:
            valid = ", ".join(sorted(t.value for t in JointType))
            raise CharacterFormatError(
                f"{path}.type",
                f"unknown joint type {entry['type']!r} "
                f"(expected one of: {valid})",
            ) from None
        # The allowed field set is type-specific: geometry-constraint
        # mates reject the kinematic controls they do not use, so e.g.
        # an ``offset`` on a width or ``connectors`` on a tangent fails
        # loudly instead of silently round-tripping.
        _reject_unknown_fields(entry, path, _joint_allowed_fields(joint_type))
        parent = _string(entry["parent"], f"{path}.parent")
        child = _string(entry["child"], f"{path}.child")
        for field_name, part_name in (("parent", parent), ("child", child)):
            if part_name not in parts:
                raise CharacterFormatError(
                    f"{path}.{field_name}", "references an undeclared part"
                )
        if joint_type in (JointType.WIDTH, JointType.TANGENT):
            joints[str(name)] = _parse_geometry_constraint_joint(
                str(name), joint_type, entry, path, parent, child, parts
            )
            continue
        template = JOINT_TYPE_DOF_TEMPLATES[joint_type]
        dofs_raw = _mapping(entry.get("dofs") or {}, f"{path}.dofs")
        if len(dofs_raw) != len(template):
            raise CharacterFormatError(
                f"{path}.dofs",
                f"joint type {joint_type.value!r} defines "
                f"{len(template)} degree(s) of freedom, got {len(dofs_raw)}",
            )
        # The joint type defines each DOF's kind. An entry declares its
        # kind through its unit keys and is matched against the type's
        # kind sequence (order within one kind follows file order), so
        # an author cannot attach a mismatched DOF list to a typed joint.
        pending: dict[DofKind, list[tuple[str, dict]]] = {
            kind: [] for kind in DofKind
        }
        for dof_name, dof_entry in dofs_raw.items():
            dof_path = f"{path}.dofs.{dof_name}"
            dof_map = _mapping(dof_entry, dof_path)
            kind = _infer_dof_kind(dof_map, dof_path)
            pending[kind].append((str(dof_name), dof_map))
        dofs = []
        for _, kind, _ in template:
            if not pending[kind]:
                expected = ", ".join(k for _, k, _ in template)
                raise CharacterFormatError(
                    f"{path}.dofs",
                    f"joint type {joint_type.value!r} defines dof kinds "
                    f"({expected}), which the given limit units do not "
                    f"match",
                )
            dof_name, dof_map = pending[kind].pop(0)
            dofs.append(
                _parse_dof(dof_name, kind, dof_map, f"{path}.dofs.{dof_name}")
            )
        controls = _parse_mate_controls(entry, path, parts)
        joint_id = _string(entry.get("id", ""), f"{path}.id")
        try:
            joints[str(name)] = Joint(
                name=str(name),
                joint_type=joint_type,
                parent_part=parent,
                child_part=child,
                dofs=tuple(dofs),
                description=_string(
                    entry.get("description", ""), f"{path}.description"
                ),
                id=joint_id,
                controls=controls,
            )
        except ValueError as error:
            raise CharacterFormatError(path, str(error)) from error
    return joints


# Field sets allowed on a joint entry, per type. The eight kinematic
# mates carry the full universal-control block; geometry-constraint
# mates (Kinematics.md "Mate categories") carry only the controls their
# category exposes, so an ``offset`` on a width or ``connectors`` on a
# tangent is a loud unknown-field error, not a silent round-trip.
_KINEMATIC_JOINT_FIELDS = {
    "type",
    "parent",
    "child",
    "dofs",
    "description",
    "id",
    "connectors",
    "offset",
    "flip_primary_axis",
    "secondary_axis_rotation_deg",
    "simulation_connection",
}
_WIDTH_JOINT_FIELDS = {
    "type",
    "parent",
    "child",
    "description",
    "id",
    "connectors",
    "flip_primary_axis",
    "simulation_connection",
}
_TANGENT_JOINT_FIELDS = {
    "type",
    "parent",
    "child",
    "description",
    "id",
    "tangent",
}


def _joint_allowed_fields(joint_type: JointType) -> set[str]:
    if joint_type is JointType.WIDTH:
        return _WIDTH_JOINT_FIELDS
    if joint_type is JointType.TANGENT:
        return _TANGENT_JOINT_FIELDS
    return _KINEMATIC_JOINT_FIELDS


def _parse_geometry_constraint_joint(
    name: str,
    joint_type: JointType,
    entry: dict,
    path: str,
    parent: str,
    child: str,
    parts: dict[str, Part],
) -> Joint:
    """A ``width`` or ``tangent`` mate: 0-DOF, geometry app-resolved.

    Width reuses the connector/flip/simulation controls (no offset, no
    secondary reorientation — both rejected by the width field set);
    tangent carries a ``tangent`` block of two opaque surface selections
    and no mate connectors. A ``dofs`` block on either is already an
    unknown field (the type defines none).
    """
    joint_id = _string(entry.get("id", ""), f"{path}.id")
    description = _string(entry.get("description", ""), f"{path}.description")
    controls = None
    tangent = None
    if joint_type is JointType.WIDTH:
        controls = _parse_width_controls(entry, path, parts)
    else:
        tangent = _parse_tangent_spec(entry.get("tangent"), f"{path}.tangent")
    try:
        return Joint(
            name=name,
            joint_type=joint_type,
            parent_part=parent,
            child_part=child,
            description=description,
            id=joint_id,
            controls=controls,
            tangent=tangent,
        )
    except ValueError as error:
        raise CharacterFormatError(path, str(error)) from error


def _parse_width_controls(
    entry: dict, path: str, parts: dict[str, Part]
) -> MateControls | None:
    """A width mate's controls: the two connectors, flip, simulation.

    No offset, no secondary reorientation (Onshape allows none on
    Width). ``None`` when the entry declares no control field at all.
    """
    connector_a = None
    connector_b = None
    if "connectors" in entry:
        connectors = _mapping(entry["connectors"], f"{path}.connectors")
        _reject_unknown_fields(connectors, f"{path}.connectors", {"a", "b"})
        connector_a = _parse_connector(
            connectors.get("a"), f"{path}.connectors.a", parts
        )
        connector_b = _parse_connector(
            connectors.get("b"), f"{path}.connectors.b", parts
        )
    has_control = any(
        key in entry
        for key in ("connectors", "flip_primary_axis", "simulation_connection")
    )
    if not has_control:
        return None
    flip = _bool(
        entry.get("flip_primary_axis", False), f"{path}.flip_primary_axis"
    )
    simulation = _bool(
        entry.get("simulation_connection", True),
        f"{path}.simulation_connection",
    )
    try:
        return MateControls(
            connector_a=connector_a,
            connector_b=connector_b,
            flip_primary_axis=flip,
            simulation_connection=simulation,
        )
    except ValueError as error:
        raise CharacterFormatError(path, str(error)) from error


def _parse_tangent_spec(raw: object, path: str) -> TangentSpec:
    """A tangent mate's required ``tangent`` block.

    ``selection_a`` / ``selection_b`` are opaque app-side surface
    identifiers (the engine has no geometry kernel); ``propagation`` is
    the optional tangent-propagation flag (default ``true``).
    """
    if raw is None:
        raise CharacterFormatError(
            path,
            "tangent mate requires a tangent block "
            "(selection_a, selection_b)",
        )
    entry = _mapping(raw, path)
    _reject_unknown_fields(
        entry, path, {"selection_a", "selection_b", "propagation"}
    )
    for required in ("selection_a", "selection_b"):
        if required not in entry:
            raise CharacterFormatError(
                f"{path}.{required}", "missing required field"
            )
    selection_a = _string(entry["selection_a"], f"{path}.selection_a")
    selection_b = _string(entry["selection_b"], f"{path}.selection_b")
    propagation = _bool(entry.get("propagation", True), f"{path}.propagation")
    try:
        return TangentSpec(
            selection_a=selection_a,
            selection_b=selection_b,
            propagation=propagation,
        )
    except ValueError as error:
        raise CharacterFormatError(path, str(error)) from error


# The universal mate controls (Kinematics.md §4) shared by all kinds.
_CONTROL_KEYS = (
    "connectors",
    "offset",
    "flip_primary_axis",
    "secondary_axis_rotation_deg",
    "simulation_connection",
)


def _parse_mate_controls(
    entry: dict, path: str, parts: dict[str, Part]
) -> MateControls | None:
    """The optional universal controls block on a joint entry.

    Connectors, as-mated offset, primary-axis flip, secondary-axis 90°
    reorientation, and the simulation-connection toggle — all optional
    with sensible defaults (a mate with none is legal, so ``None`` when
    the entry declares no control field at all).
    """
    if not any(key in entry for key in _CONTROL_KEYS):
        return None
    connector_a = None
    connector_b = None
    if "connectors" in entry:
        connectors = _mapping(entry["connectors"], f"{path}.connectors")
        _reject_unknown_fields(connectors, f"{path}.connectors", {"a", "b"})
        connector_a = _parse_connector(
            connectors.get("a"), f"{path}.connectors.a", parts
        )
        connector_b = _parse_connector(
            connectors.get("b"), f"{path}.connectors.b", parts
        )
    offset = _parse_mate_offset(entry.get("offset"), f"{path}.offset")
    flip_primary_axis = _bool(
        entry.get("flip_primary_axis", False), f"{path}.flip_primary_axis"
    )
    secondary_rotation = _secondary_axis_rotation(
        entry.get("secondary_axis_rotation_deg", 0),
        f"{path}.secondary_axis_rotation_deg",
    )
    simulation_connection = _bool(
        entry.get("simulation_connection", True),
        f"{path}.simulation_connection",
    )
    try:
        return MateControls(
            connector_a=connector_a,
            connector_b=connector_b,
            offset=offset,
            flip_primary_axis=flip_primary_axis,
            secondary_axis_rotation_deg=secondary_rotation,
            simulation_connection=simulation_connection,
        )
    except ValueError as error:
        raise CharacterFormatError(path, str(error)) from error


def _parse_connector(
    raw: object, path: str, parts: dict[str, Part]
) -> MateConnector | None:
    """One side's mate connector frame, or ``None`` when absent."""
    if raw is None:
        return None
    entry = _mapping(raw, path)
    _reject_unknown_fields(
        entry,
        path,
        {"part", "origin_m", "primary_axis", "secondary_axis", "flipped",
         "feature"},
    )
    if "part" not in entry:
        raise CharacterFormatError(f"{path}.part", "missing required field")
    part = _string(entry["part"], f"{path}.part")
    if part not in parts:
        raise CharacterFormatError(f"{path}.part", "references an undeclared part")
    origin = _vector3(entry.get("origin_m", [0.0, 0.0, 0.0]), f"{path}.origin_m")
    primary = _vector3(
        entry.get("primary_axis", [0.0, 0.0, 1.0]), f"{path}.primary_axis"
    )
    secondary = _vector3(
        entry.get("secondary_axis", [1.0, 0.0, 0.0]), f"{path}.secondary_axis"
    )
    flipped = _bool(entry.get("flipped", False), f"{path}.flipped")
    feature = _string(entry.get("feature", ""), f"{path}.feature")
    try:
        return MateConnector(
            part=part,
            origin_m=origin,
            primary_axis=primary,
            secondary_axis=secondary,
            flipped=flipped,
            feature=feature,
        )
    except ValueError as error:
        raise CharacterFormatError(path, str(error)) from error


def _parse_mate_offset(raw: object, path: str) -> MateOffset:
    """The as-mated ``offset`` block (Kinematics.md §4).

    ``translation_m`` in meters, ``rotate_about`` (``x``/``y``/``z``)
    plus ``angle_deg`` in degrees (radians in the model), and an
    ``enabled`` flag mirroring the Onshape dialog. Absent → a disabled
    zero offset. The runtime round-trips it; Studio consumes it
    spatially.
    """
    if raw is None:
        return MateOffset()
    entry = _mapping(raw, path)
    _reject_unknown_fields(
        entry, path, {"enabled", "translation_m", "rotate_about", "angle_deg"}
    )
    enabled = _bool(entry.get("enabled", False), f"{path}.enabled")
    translation = _vector3(
        entry.get("translation_m", [0.0, 0.0, 0.0]), f"{path}.translation_m"
    )
    rotate_about = entry.get("rotate_about", RotationAxis.Z.value)
    try:
        axis = RotationAxis(rotate_about)
    except ValueError:
        valid = ", ".join(a.value for a in RotationAxis)
        raise CharacterFormatError(
            f"{path}.rotate_about",
            f"expected one of ({valid}), got {rotate_about!r}",
        ) from None
    angle_degrees = _number(entry.get("angle_deg", 0.0), f"{path}.angle_deg")
    try:
        return MateOffset(
            enabled=enabled,
            translation_m=translation,
            rotation_axis=axis,
            rotation_radians=math.radians(angle_degrees),
        )
    except ValueError as error:
        raise CharacterFormatError(path, str(error)) from error


def _secondary_axis_rotation(value: object, path: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise CharacterFormatError(
            path, f"expected an integer degree step, got {value!r}"
        )
    try:
        return int(SecondaryAxisRotation(value))
    except ValueError:
        valid = ", ".join(str(step.value) for step in SecondaryAxisRotation)
        raise CharacterFormatError(
            path, f"must be one of ({valid}), got {value}"
        ) from None


def _infer_dof_kind(entry: dict, path: str) -> DofKind:
    """A dof entry's kind, declared by its explicit-unit keys.

    With the ``limits`` block optional, the unit family may come from
    the limit keys inside it and/or the neutral key beside it; exactly
    one family must be declared (an unlimited dof therefore always
    carries an explicit ``neutral_deg``/``neutral_m``).
    """
    limits = entry.get("limits")
    limit_keys = set(limits) if isinstance(limits, dict) else set()
    has_rotation = (
        bool({"min_deg", "max_deg"} & limit_keys) or "neutral_deg" in entry
    )
    has_translation = (
        bool({"min_m", "max_m"} & limit_keys) or "neutral_m" in entry
    )
    if has_rotation == has_translation:
        raise CharacterFormatError(
            path,
            "dof must declare exactly one unit family through its limits "
            "block (min_deg/max_deg or min_m/max_m) and/or its neutral key "
            "(neutral_deg or neutral_m); an unlimited dof needs an "
            "explicit neutral",
        )
    return DofKind.ROTATION if has_rotation else DofKind.TRANSLATION


def _parse_dof(
    name: str, kind: DofKind, raw: object, path: str
) -> DegreeOfFreedom:
    entry = _mapping(raw, path)
    min_key, max_key, neutral_key = _DOF_LIMIT_KEYS[kind]
    _reject_unknown_fields(
        entry, path, {"limits", neutral_key, "axis", "description"}
    )
    minimum: float | None = None
    maximum: float | None = None
    if "limits" in entry:
        limits_path = f"{path}.limits"
        limits = _mapping(entry["limits"], limits_path)
        _reject_unknown_fields(limits, limits_path, {min_key, max_key})
        for required in (min_key, max_key):
            if required not in limits:
                raise CharacterFormatError(
                    f"{limits_path}.{required}", "missing required field"
                )
        minimum = _number(limits[min_key], f"{limits_path}.{min_key}")
        maximum = _number(limits[max_key], f"{limits_path}.{max_key}")
        if minimum >= maximum:
            raise CharacterFormatError(
                f"{limits_path}.{min_key}",
                f"range must be ascending: [{minimum}, {maximum}]",
            )
    neutral = _number(entry.get(neutral_key, 0.0), f"{path}.{neutral_key}")
    if minimum is not None and not minimum <= neutral <= maximum:
        raise CharacterFormatError(
            f"{path}.{neutral_key}",
            f"{neutral} outside range [{minimum}, {maximum}]",
        )
    axis_raw = entry.get("axis")
    axis: tuple[float, float, float] | None = None
    if axis_raw is not None:
        if not isinstance(axis_raw, list) or len(axis_raw) != 3:
            raise CharacterFormatError(
                f"{path}.axis",
                f"expected a three-number list, got {axis_raw!r}",
            )
        axis = tuple(
            _number(component, f"{path}.axis[{index}]")
            for index, component in enumerate(axis_raw)
        )
    description = _string(entry.get("description", ""), f"{path}.description")
    try:
        if kind is DofKind.ROTATION:
            return RotationDof(
                name=name,
                min_radians=None if minimum is None else math.radians(minimum),
                max_radians=None if maximum is None else math.radians(maximum),
                neutral_radians=math.radians(neutral),
                axis=axis,
                description=description,
            )
        return TranslationDof(
            name=name,
            min_meters=minimum,
            max_meters=maximum,
            neutral_meters=neutral,
            axis=axis,
            description=description,
        )
    except ValueError as error:
        raise CharacterFormatError(path, str(error)) from error


def _parse_parameters(raw: object) -> dict[str, Parameter]:
    if raw is None:
        return {}
    parameters: dict[str, Parameter] = {}
    for name, entry in _mapping(raw, "parameters").items():
        path = f"parameters.{name}"
        entry = _mapping(entry if entry is not None else {}, path)
        _reject_unknown_fields(entry, path, {"default", "description"})
        neutral = _number(entry.get("default", 0.0), f"{path}.default")
        if not 0.0 <= neutral <= 1.0:
            raise CharacterFormatError(
                f"{path}.default", f"outside 0..1: {neutral}"
            )
        try:
            parameters[str(name)] = Parameter(
                name=str(name),
                neutral_value=neutral,
                description=_string(
                    entry.get("description", ""), f"{path}.description"
                ),
            )
        except ValueError as error:
            raise CharacterFormatError(path, str(error)) from error
    return parameters


def _parse_clips(
    raw: object,
    dof_paths: dict[str, DegreeOfFreedom],
    parameters: dict[str, Parameter],
) -> dict[str, RigClip]:
    if raw is None:
        return {}
    clips: dict[str, RigClip] = {}
    for name, entry in _mapping(raw, "clips").items():
        path = f"clips.{name}"
        entry = _mapping(entry, path)
        _reject_unknown_fields(entry, path, {"duration_s", "loop", "tracks"})
        if "duration_s" not in entry:
            raise CharacterFormatError(
                f"{path}.duration_s", "missing required field"
            )
        duration_seconds = _number(entry["duration_s"], f"{path}.duration_s")
        if duration_seconds < 0:
            raise CharacterFormatError(
                f"{path}.duration_s", f"must be >= 0: {duration_seconds}"
            )
        loop = entry.get("loop", False)
        if not isinstance(loop, bool):
            raise CharacterFormatError(
                f"{path}.loop", f"expected true/false, got {loop!r}"
            )
        tracks = _parse_track_entries(
            entry.get("tracks", []),
            f"{path}.tracks",
            duration_seconds,
            dof_paths,
            parameters,
        )
        clips[str(name)] = RigClip(
            clip=Clip(
                name=str(name),
                duration_seconds=duration_seconds,
                tracks=tracks,
            ),
            loop=loop,
        )
    return clips


def _target_bounds(
    target: str,
    dof_paths: dict[str, DegreeOfFreedom],
    parameters: dict[str, Parameter],
) -> tuple[float, float] | None:
    """Model-unit bounds of a track/output target, or None if undeclared.

    An unlimited DOF gets infinite bounds: its track values pass
    validation untouched and evaluation never clamps them.
    """
    dof = dof_paths.get(target)
    if dof is not None:
        if not dof.has_limits:
            return -math.inf, math.inf
        return dof.minimum, dof.maximum
    if target in parameters:
        return 0.0, 1.0
    return None


def _parse_track_entries(
    raw: object,
    path: str,
    duration_seconds: float,
    dof_paths: dict[str, DegreeOfFreedom],
    parameters: dict[str, Parameter],
) -> dict[int | str, Track]:
    """Parse one clip's keyframe-entry list.

    Entries are sparse: each target's track is built from the entries
    whose ``values`` mention it. Value keys are DOF paths or parameter
    names; rotation values are degrees in the file, translation values
    meters, parameter values 0..1.
    """
    if not isinstance(raw, list):
        raise CharacterFormatError(
            path,
            f"expected a list of keyframe entries, got {type(raw).__name__}",
        )
    per_target: dict[str, list[Keyframe]] = {}
    previous_time = -1.0
    for index, entry in enumerate(raw):
        entry_path = f"{path}[{index}]"
        entry = _mapping(entry, entry_path)
        _reject_unknown_fields(
            entry, entry_path, {"time", "values", "interpolation"}
        )
        if "time" not in entry:
            raise CharacterFormatError(
                f"{entry_path}.time", "missing required field"
            )
        time_seconds = _number(entry["time"], f"{entry_path}.time")
        if time_seconds < 0:
            raise CharacterFormatError(
                f"{entry_path}.time", f"must be >= 0: {time_seconds}"
            )
        if time_seconds > duration_seconds:
            raise CharacterFormatError(
                f"{entry_path}.time",
                f"keyframe at {time_seconds} is past the clip end "
                f"({duration_seconds})",
            )
        if time_seconds <= previous_time:
            raise CharacterFormatError(
                f"{entry_path}.time",
                f"entry times must be strictly increasing: {time_seconds}",
            )
        previous_time = time_seconds
        interpolation = _interpolation(
            entry.get("interpolation", "linear"),
            f"{entry_path}.interpolation",
        )
        values = _mapping(entry.get("values"), f"{entry_path}.values")
        if not values:
            raise CharacterFormatError(
                f"{entry_path}.values", "requires at least one value"
            )
        for target_name, raw_value in values.items():
            value_path = f"{entry_path}.values.{target_name}"
            target = str(target_name)
            bounds = _target_bounds(target, dof_paths, parameters)
            if bounds is None:
                raise CharacterFormatError(
                    value_path,
                    "references an undeclared DOF path or parameter",
                )
            value = _number(raw_value, value_path)
            dof = dof_paths.get(target)
            if dof is not None and dof.kind is DofKind.ROTATION:
                value = math.radians(value)
            minimum, maximum = bounds
            if not minimum <= value <= maximum:
                raise CharacterFormatError(
                    value_path,
                    f"{raw_value} outside the target's range",
                )
            per_target.setdefault(target, []).append(
                Keyframe(
                    time_seconds=time_seconds,
                    value=value,
                    interpolation=interpolation,
                )
            )
    tracks: dict[int | str, Track] = {}
    for target, keyframes in per_target.items():
        minimum, maximum = _target_bounds(target, dof_paths, parameters)
        tracks[target] = Track(
            keyframes=tuple(keyframes),
            minimum_value=minimum,
            maximum_value=maximum,
        )
    return tracks


def _parse_outputs(
    raw: object,
    dof_paths: dict[str, DegreeOfFreedom],
    parameters: dict[str, Parameter],
) -> tuple[OutputMapping, ...]:
    if raw is None:
        return ()
    if not isinstance(raw, list):
        raise CharacterFormatError(
            "outputs",
            f"expected a list of channel mappings, got {type(raw).__name__}",
        )
    mappings: list[OutputMapping] = []
    seen_channels: set[int] = set()
    for index, entry in enumerate(raw):
        path = f"outputs[{index}]"
        entry = _mapping(entry, path)
        for required in ("target", "channel"):
            if required not in entry:
                raise CharacterFormatError(
                    f"{path}.{required}", "missing required field"
                )
        target = _string(entry["target"], f"{path}.target")
        dof = dof_paths.get(target)
        if dof is not None and not dof.has_limits:
            raise CharacterFormatError(
                f"{path}.target",
                f"{target!r} has no limits; a bounded actuator channel "
                f"needs a dof range to project to 0..1 — add a limits "
                f"block to the dof or remove this mapping",
            )
        if dof is not None:
            range_key = "range_deg" if dof.kind is DofKind.ROTATION else "range_m"
        elif target in parameters:
            range_key = "range"
        else:
            raise CharacterFormatError(
                f"{path}.target",
                "references an undeclared DOF path or parameter",
            )
        # Only the range key matching the target's units is legal, so a
        # mismatched one (e.g. degrees for a translation DOF) is rejected.
        _reject_unknown_fields(entry, path, {"target", "channel", range_key})
        if range_key not in entry:
            raise CharacterFormatError(
                f"{path}.{range_key}", "missing required field"
            )
        at_zero, at_one = _number_pair(entry[range_key], f"{path}.{range_key}")
        if range_key == "range_deg":
            at_zero, at_one = math.radians(at_zero), math.radians(at_one)
        if at_zero == at_one:
            raise CharacterFormatError(
                f"{path}.{range_key}", "range ends must differ"
            )
        channel = entry["channel"]
        if not isinstance(channel, int) or isinstance(channel, bool):
            raise CharacterFormatError(
                f"{path}.channel", f"expected an integer, got {channel!r}"
            )
        if channel < 0:
            raise CharacterFormatError(
                f"{path}.channel", f"must be >= 0: {channel}"
            )
        if channel in seen_channels:
            raise CharacterFormatError(
                f"{path}.channel", f"duplicate output channel: {channel}"
            )
        seen_channels.add(channel)
        mappings.append(
            OutputMapping(
                target=target,
                channel=channel,
                value_at_zero=at_zero,
                value_at_one=at_one,
            )
        )
    return tuple(mappings)


def _parse_relations(
    raw: object, dof_paths: dict[str, DegreeOfFreedom]
) -> tuple[Relation, ...]:
    """The ``relations`` list: linear DOF couplings (Kinematics.md §5).

    ``ratio`` is the semantic signed float in model units (driven model
    unit per driver model unit); the optional offset key matches the
    driven DOF's file units (``offset_deg``/``offset_m``) and converts
    to model units. Graph-level rules — acyclic, one driver per DOF,
    no animation tracks on a driven DOF — are enforced by ``Rig``.
    """
    if raw is None:
        return ()
    if not isinstance(raw, list):
        raise CharacterFormatError(
            "relations",
            f"expected a list of dof couplings, got {type(raw).__name__}",
        )
    relations: list[Relation] = []
    for index, entry in enumerate(raw):
        path = f"relations[{index}]"
        entry = _mapping(entry, path)
        for required in ("kind", "driver", "driven", "ratio"):
            if required not in entry:
                raise CharacterFormatError(
                    f"{path}.{required}", "missing required field"
                )
        try:
            kind = RelationKind(entry["kind"])
        except ValueError:
            valid = ", ".join(sorted(k.value for k in RelationKind))
            raise CharacterFormatError(
                f"{path}.kind",
                f"unknown relation kind {entry['kind']!r} "
                f"(expected one of: {valid})",
            ) from None
        driver_kind, driven_kind = RELATION_KIND_DOF_KINDS[kind]
        for role, expected_kind in (
            ("driver", driver_kind),
            ("driven", driven_kind),
        ):
            target = _string(entry[role], f"{path}.{role}")
            dof = dof_paths.get(target)
            if dof is None:
                raise CharacterFormatError(
                    f"{path}.{role}", "references an undeclared dof path"
                )
            if dof.kind is not expected_kind:
                raise CharacterFormatError(
                    f"{path}.{role}",
                    f"{kind.value} requires a {expected_kind.value} dof, "
                    f"got {dof.kind.value} ({target!r})",
                )
        offset_key = _RELATION_OFFSET_KEYS[driven_kind]
        _reject_unknown_fields(
            entry,
            path,
            {"kind", "driver", "driven", "ratio", offset_key, "display"},
        )
        ratio = _number(entry["ratio"], f"{path}.ratio")
        if ratio == 0.0:
            raise CharacterFormatError(
                f"{path}.ratio",
                "must be nonzero: a zero ratio pins the driven dof "
                "instead of coupling it",
            )
        offset = _number(entry.get(offset_key, 0.0), f"{path}.{offset_key}")
        if offset_key == "offset_deg":
            offset = math.radians(offset)
        display: dict[str, float] = {}
        if "display" in entry:
            display_path = f"{path}.display"
            display_map = _mapping(entry["display"], display_path)
            allowed_keys = RELATION_DISPLAY_KEYS[kind]
            for key, value in display_map.items():
                key_path = f"{display_path}.{key}"
                if key not in allowed_keys:
                    valid = ", ".join(sorted(allowed_keys)) or "none"
                    raise CharacterFormatError(
                        key_path,
                        f"unknown display field for {kind.value} "
                        f"(expected: {valid})",
                    )
                number = _number(value, key_path)
                if number <= 0:
                    raise CharacterFormatError(
                        key_path, f"must be > 0: {value!r}"
                    )
                display[str(key)] = number
        try:
            relations.append(
                Relation(
                    kind=kind,
                    driver=_string(entry["driver"], f"{path}.driver"),
                    driven=_string(entry["driven"], f"{path}.driven"),
                    ratio=ratio,
                    offset=offset,
                    display=display,
                )
            )
        except ValueError as error:
            raise CharacterFormatError(path, str(error)) from error
    return tuple(relations)


# Primitive validators --------------------------------------------------------


def _mapping(value: object, path: str) -> dict:
    if not isinstance(value, dict):
        raise CharacterFormatError(
            path, f"expected a mapping, got {type(value).__name__}"
        )
    return value


def _string(value: object, path: str) -> str:
    if not isinstance(value, str):
        raise CharacterFormatError(
            path, f"expected a string, got {value!r}"
        )
    return value


def _number(value: object, path: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise CharacterFormatError(path, f"expected a number, got {value!r}")
    return float(value)


def _bool(value: object, path: str) -> bool:
    if not isinstance(value, bool):
        raise CharacterFormatError(
            path, f"expected true/false, got {value!r}"
        )
    return value


def _vector3(value: object, path: str) -> tuple[float, float, float]:
    if not isinstance(value, list) or len(value) != 3:
        raise CharacterFormatError(
            path, f"expected a three-number list, got {value!r}"
        )
    return tuple(
        _number(component, f"{path}[{index}]")
        for index, component in enumerate(value)
    )


def _number_pair(value: object, path: str) -> tuple[float, float]:
    if not isinstance(value, list) or len(value) != 2:
        raise CharacterFormatError(
            path, f"expected a two-number list, got {value!r}"
        )
    return _number(value[0], f"{path}[0]"), _number(value[1], f"{path}[1]")


def _interpolation(value: object, path: str) -> Interpolation:
    try:
        return Interpolation(value)
    except ValueError:
        raise CharacterFormatError(
            path, f"expected 'hold' or 'linear', got {value!r}"
        ) from None


def _reject_unknown_fields(
    raw: dict, path: str, allowed: set[str]
) -> None:
    for key in raw:
        if key not in allowed:
            raise CharacterFormatError(f"{path}.{key}", "unknown field")
