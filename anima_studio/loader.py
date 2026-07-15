"""Load ``.character.anima`` YAML into the runtime rig model.

Parses the character-format subset that ``anima_studio.rig`` models —
identity, blend shapes, bones (degrees in the file, radians in the
rig), hold/linear clips, and the physical bone→servo channel mapping —
and rejects, with a ``CharacterFormatError`` naming the offending path,
every spec section this runtime does not execute yet (``expressions``,
``lip_sync``, ``digital``, ``voice``, ``blend_shape_mapping``,
``led_mapping``, ``smoothing``, ``easing``) rather than silently
dropping it. Spec: ``dev/docs/roadmap/Character_Format.md``.
"""

from __future__ import annotations

import math
from pathlib import Path

import yaml

from anima_studio.rig import (
    BlendShape,
    Identity,
    Joint,
    Rig,
    RigClip,
    ServoMapping,
)
from anima_studio.tracks import Clip, Interpolation, Keyframe, Track

SUPPORTED_ANIMA_VERSION = "1.0"
SUPPORTED_TYPE = "character"

# Spec sections the runtime does not execute yet. Kept explicit so a
# file using them fails loudly instead of playing back incompletely.
_UNSUPPORTED_TOP_LEVEL = ("expressions", "lip_sync", "digital", "voice")


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
    blend_shapes = _parse_blend_shapes(document.get("blend_shapes"))
    joints = _parse_bones(document.get("bones"))
    clips = _parse_clips(document.get("clips"), joints, blend_shapes)
    physical_enabled, servo_mappings = _parse_physical(
        document.get("physical"), joints
    )

    try:
        return Rig(
            identity=identity,
            joints=joints,
            blend_shapes=blend_shapes,
            clips=clips,
            servo_mappings=servo_mappings,
            physical_enabled=physical_enabled,
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
        "blend_shapes",
        "bones",
        "clips",
        "physical",
    }
    for key in document:
        if key in _UNSUPPORTED_TOP_LEVEL:
            raise CharacterFormatError(
                str(key),
                "spec section not supported by the runtime loader yet",
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


def _parse_blend_shapes(raw: object) -> dict[str, BlendShape]:
    if raw is None:
        return {}
    shapes: dict[str, BlendShape] = {}
    for name, entry in _mapping(raw, "blend_shapes").items():
        path = f"blend_shapes.{name}"
        entry = _mapping(entry, path)
        _reject_unknown_fields(entry, path, {"default", "description"})
        neutral = _number(entry.get("default", 0.0), f"{path}.default")
        if not 0.0 <= neutral <= 1.0:
            raise CharacterFormatError(
                f"{path}.default", f"outside 0..1: {neutral}"
            )
        shapes[str(name)] = BlendShape(
            name=str(name),
            neutral_value=neutral,
            description=_string(
                entry.get("description", ""), f"{path}.description"
            ),
        )
    return shapes


def _parse_bones(raw: object) -> dict[str, Joint]:
    if raw is None:
        return {}
    joints: dict[str, Joint] = {}
    for name, entry in _mapping(raw, "bones").items():
        path = f"bones.{name}"
        entry = _mapping(entry, path)
        _reject_unknown_fields(
            entry, path, {"description", "neutral_deg", "range_deg"}
        )
        min_deg, max_deg = _degree_pair(
            entry.get("range_deg"), f"{path}.range_deg"
        )
        if min_deg >= max_deg:
            raise CharacterFormatError(
                f"{path}.range_deg",
                f"range must be ascending: [{min_deg}, {max_deg}]",
            )
        neutral_deg = _number(
            entry.get("neutral_deg", 0.0), f"{path}.neutral_deg"
        )
        if not min_deg <= neutral_deg <= max_deg:
            raise CharacterFormatError(
                f"{path}.neutral_deg",
                f"{neutral_deg} outside range [{min_deg}, {max_deg}]",
            )
        joints[str(name)] = Joint(
            name=str(name),
            min_radians=math.radians(min_deg),
            max_radians=math.radians(max_deg),
            neutral_radians=math.radians(neutral_deg),
            description=_string(
                entry.get("description", ""), f"{path}.description"
            ),
        )
    return joints


def _parse_clips(
    raw: object,
    joints: dict[str, Joint],
    blend_shapes: dict[str, BlendShape],
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

        tracks: dict[int | str, Track] = {}
        groups = _mapping(entry.get("tracks", {}), f"{path}.tracks")
        for group_name, group in groups.items():
            group_path = f"{path}.tracks.{group_name}"
            if group_name == "easing":
                raise CharacterFormatError(
                    group_path,
                    "easing curves are not supported yet; hold/linear only",
                )
            if group_name == "bones":
                tracks.update(
                    _parse_track_group(
                        group, group_path, duration_seconds, joints
                    )
                )
            elif group_name == "blend_shapes":
                tracks.update(
                    _parse_track_group(
                        group, group_path, duration_seconds, blend_shapes
                    )
                )
            else:
                raise CharacterFormatError(group_path, "unknown field")

        clips[str(name)] = RigClip(
            clip=Clip(
                name=str(name),
                duration_seconds=duration_seconds,
                tracks=tracks,
            ),
            loop=loop,
        )
    return clips


def _parse_track_group(
    raw: object,
    path: str,
    duration_seconds: float,
    parameters: dict[str, Joint] | dict[str, BlendShape],
) -> dict[int | str, Track]:
    """Parse one ``bones:`` / ``blend_shapes:`` keyframe-entry list.

    Entries are sparse: each parameter's track is built from the entries
    whose ``values`` mention it. Bone values are degrees in the file;
    blend shape values are 0..1.
    """
    if not isinstance(raw, list):
        raise CharacterFormatError(
            path, f"expected a list of keyframe entries, got {type(raw).__name__}"
        )
    per_parameter: dict[str, list[Keyframe]] = {}
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
        for parameter_name, raw_value in values.items():
            value_path = f"{entry_path}.values.{parameter_name}"
            parameter = parameters.get(str(parameter_name))
            if parameter is None:
                raise CharacterFormatError(
                    value_path, "references an undeclared parameter"
                )
            value = _number(raw_value, value_path)
            if isinstance(parameter, Joint):
                value = math.radians(value)
                minimum, maximum = parameter.min_radians, parameter.max_radians
            else:
                minimum, maximum = 0.0, 1.0
            if not minimum <= value <= maximum:
                raise CharacterFormatError(
                    value_path,
                    f"{raw_value} outside the parameter's range",
                )
            per_parameter.setdefault(str(parameter_name), []).append(
                Keyframe(
                    time_seconds=time_seconds,
                    value=value,
                    interpolation=interpolation,
                )
            )
    return {
        name: Track(
            keyframes=tuple(keyframes),
            minimum_value=(
                parameters[name].min_radians
                if isinstance(parameters[name], Joint)
                else 0.0
            ),
            maximum_value=(
                parameters[name].max_radians
                if isinstance(parameters[name], Joint)
                else 1.0
            ),
        )
        for name, keyframes in per_parameter.items()
    }


def _parse_physical(
    raw: object, joints: dict[str, Joint]
) -> tuple[bool, tuple[ServoMapping, ...]]:
    if raw is None:
        return False, ()
    physical = _mapping(raw, "physical")
    for unsupported in ("blend_shape_mapping", "led_mapping"):
        if unsupported in physical:
            raise CharacterFormatError(
                f"physical.{unsupported}",
                "not supported by the runtime loader yet",
            )
    _reject_unknown_fields(physical, "physical", {"enabled", "bone_mapping"})
    enabled = physical.get("enabled", True)
    if not isinstance(enabled, bool):
        raise CharacterFormatError(
            "physical.enabled", f"expected true/false, got {enabled!r}"
        )

    mappings: list[ServoMapping] = []
    seen_channels: set[int] = set()
    for joint_name, entry in _mapping(
        physical.get("bone_mapping", {}), "physical.bone_mapping"
    ).items():
        path = f"physical.bone_mapping.{joint_name}"
        entry = _mapping(entry, path)
        if "smoothing" in entry:
            raise CharacterFormatError(
                f"{path}.smoothing",
                "not supported by the runtime loader yet",
            )
        _reject_unknown_fields(entry, path, {"servo_channel", "range"})
        if str(joint_name) not in joints:
            raise CharacterFormatError(path, "references an undeclared bone")
        if "servo_channel" not in entry:
            raise CharacterFormatError(
                f"{path}.servo_channel", "missing required field"
            )
        channel = entry["servo_channel"]
        if not isinstance(channel, int) or isinstance(channel, bool):
            raise CharacterFormatError(
                f"{path}.servo_channel", f"expected an integer, got {channel!r}"
            )
        if channel < 0:
            raise CharacterFormatError(
                f"{path}.servo_channel", f"must be >= 0: {channel}"
            )
        if channel in seen_channels:
            raise CharacterFormatError(
                f"{path}.servo_channel", f"duplicate servo channel: {channel}"
            )
        seen_channels.add(channel)
        angle_at_zero_deg, angle_at_one_deg = _degree_pair(
            entry.get("range"), f"{path}.range"
        )
        if angle_at_zero_deg == angle_at_one_deg:
            raise CharacterFormatError(
                f"{path}.range", "range ends must differ"
            )
        mappings.append(
            ServoMapping(
                joint_name=str(joint_name),
                servo_channel=channel,
                angle_at_zero_radians=math.radians(angle_at_zero_deg),
                angle_at_one_radians=math.radians(angle_at_one_deg),
            )
        )
    return enabled, tuple(mappings)


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


def _degree_pair(value: object, path: str) -> tuple[float, float]:
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
