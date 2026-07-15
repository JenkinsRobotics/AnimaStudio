"""Rig-aware runtime model: joints, blend shapes, poses, servo projection.

The Python mirror of AnimaCore's rig semantics for headless playback: a
clip drives some parameters, and every unanimated joint or blend shape
falls back to its neutral — empty or missing tracks are legal at rig
level. Per-track hold/linear interpolation is reused from
``anima_studio.tracks``; this module adds the rig layer on top, plus the
joint→normalized-channel projection (the B04 seam) whose 0..1 output
feeds ``wire.encode_frm``. Rigs come from ``.character.anima`` files via
``anima_studio.loader``.
"""

from __future__ import annotations

from collections.abc import Mapping
from dataclasses import dataclass, field

from anima_studio.tracks import Clip, evaluate_clip


@dataclass(frozen=True)
class Joint:
    """A named rotational joint with explicit radian limits."""

    name: str
    min_radians: float
    max_radians: float
    neutral_radians: float = 0.0
    description: str = ""

    def __post_init__(self) -> None:
        if self.min_radians >= self.max_radians:
            raise ValueError(
                f"joint {self.name!r} has bad range: "
                f"{self.min_radians} >= {self.max_radians}"
            )
        if not self.min_radians <= self.neutral_radians <= self.max_radians:
            raise ValueError(
                f"joint {self.name!r} neutral {self.neutral_radians} "
                f"outside range [{self.min_radians}, {self.max_radians}]"
            )


@dataclass(frozen=True)
class BlendShape:
    """A named normalized expression parameter, always 0.0..1.0."""

    name: str
    neutral_value: float = 0.0
    description: str = ""

    def __post_init__(self) -> None:
        if not 0.0 <= self.neutral_value <= 1.0:
            raise ValueError(
                f"blend shape {self.name!r} neutral outside 0..1: "
                f"{self.neutral_value}"
            )


@dataclass(frozen=True)
class ServoMapping:
    """Joint angle → normalized wire channel value (the B04 seam).

    ``angle_at_zero_radians`` / ``angle_at_one_radians`` are the joint
    angles that map to channel values 0.0 and 1.0; a descending pair
    inverts the channel. Angles outside the pair clamp to 0..1. Pulse
    widths, pins, and other hardware detail stay in the wire ``CFG``
    layer, never here.
    """

    joint_name: str
    servo_channel: int
    angle_at_zero_radians: float
    angle_at_one_radians: float

    def __post_init__(self) -> None:
        if self.servo_channel < 0:
            raise ValueError(
                f"servo channel must be >= 0: {self.servo_channel}"
            )
        if self.angle_at_zero_radians == self.angle_at_one_radians:
            raise ValueError(
                f"mapping for joint {self.joint_name!r} has zero span: "
                f"both ends are {self.angle_at_zero_radians}"
            )

    def channel_value(self, angle_radians: float) -> float:
        """Project a joint angle to the normalized 0..1 channel value."""
        span = self.angle_at_one_radians - self.angle_at_zero_radians
        value = (angle_radians - self.angle_at_zero_radians) / span
        return min(max(value, 0.0), 1.0)


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
    """A character's movable structure: what a clip is evaluated against.

    Joints and blend shapes share one parameter namespace: clip track
    keys are parameter names, and every key must name a declared joint
    or blend shape.
    """

    identity: Identity
    joints: Mapping[str, Joint] = field(default_factory=dict)
    blend_shapes: Mapping[str, BlendShape] = field(default_factory=dict)
    clips: Mapping[str, RigClip] = field(default_factory=dict)
    servo_mappings: tuple[ServoMapping, ...] = ()
    physical_enabled: bool = False

    def __post_init__(self) -> None:
        for name, joint in self.joints.items():
            if name != joint.name:
                raise ValueError(f"joint key {name!r} != name {joint.name!r}")
        for name, shape in self.blend_shapes.items():
            if name != shape.name:
                raise ValueError(
                    f"blend shape key {name!r} != name {shape.name!r}"
                )
        collisions = set(self.joints) & set(self.blend_shapes)
        if collisions:
            raise ValueError(
                f"joint/blend-shape name collision: {sorted(collisions)}"
            )
        for clip_name, rig_clip in self.clips.items():
            for key in rig_clip.clip.tracks:
                if key not in self.joints and key not in self.blend_shapes:
                    raise ValueError(
                        f"clip {clip_name!r} animates unknown parameter "
                        f"{key!r}"
                    )
        seen_channels: set[int] = set()
        for mapping in self.servo_mappings:
            if mapping.joint_name not in self.joints:
                raise ValueError(
                    f"servo mapping references unknown joint "
                    f"{mapping.joint_name!r}"
                )
            if mapping.servo_channel in seen_channels:
                raise ValueError(
                    f"duplicate servo channel: {mapping.servo_channel}"
                )
            seen_channels.add(mapping.servo_channel)


@dataclass(frozen=True)
class Pose:
    """One evaluated rig state: radians per joint, 0..1 per blend shape."""

    joint_angles_radians: Mapping[str, float]
    blend_shape_values: Mapping[str, float]


def evaluate_pose(
    rig: Rig, clip_name: str | None = None, time_seconds: float = 0.0
) -> Pose:
    """Evaluate the rig at ``time_seconds``, deterministically.

    ``clip_name`` selects one of ``rig.clips``; ``None`` gives the
    neutral pose. Every parameter the clip does not animate falls back
    to its neutral. Looping clips wrap time modulo the duration;
    non-looping clips clamp.
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
        joint_angles_radians={
            name: animated.get(name, joint.neutral_radians)
            for name, joint in rig.joints.items()
        },
        blend_shape_values={
            name: animated.get(name, shape.neutral_value)
            for name, shape in rig.blend_shapes.items()
        },
    )


def project_channels(rig: Rig, pose: Pose) -> dict[int, float]:
    """Project a pose's mapped joints to normalized 0..1 channel targets.

    The result is exactly what ``wire.encode_frm`` takes. Unmapped
    joints and all blend shapes are omitted (no blend-shape servo
    mapping in this packet — see ``anima_studio.loader``).
    """
    return {
        mapping.servo_channel: mapping.channel_value(
            pose.joint_angles_radians[mapping.joint_name]
        )
        for mapping in rig.servo_mappings
    }
