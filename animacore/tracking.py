"""Face-tracking parameter vocabulary for VR / live-avatar characters.

A **VR character** is an avatar (a 2D canvas or a 3D rig) driven in real time by
face tracking. A tracker — ARKit on an iPhone/iPad, or a Mac vision pipeline —
produces a standard set of blendshape coefficients (0..1) plus a head pose; these
become the evaluated ``values`` a character's drivers bind to (a surface driver
with ``source="face.jawOpen"`` opens the mouth, exactly like any other parameter).

This module is the renderer- and tracker-neutral *contract*: the canonical
parameter names (Apple's 52 ARKit blendshapes, the de-facto standard that
VTuber tooling also speaks) + head pose, and a frame -> values helper. The
avatar side (``canvas2d`` + drivers, or a rig) already consumes ``values``, so a
VR character works end-to-end the moment a tracker emits these names. Stdlib only.
"""

from __future__ import annotations

from collections.abc import Mapping
from dataclasses import dataclass, field

NAMESPACE = "face"

# Apple ARKit ``ARFaceAnchor.BlendShapeLocation`` — 52 coefficients, each 0..1.
ARKIT_BLENDSHAPES: tuple[str, ...] = (
    "browDownLeft", "browDownRight", "browInnerUp", "browOuterUpLeft", "browOuterUpRight",
    "cheekPuff", "cheekSquintLeft", "cheekSquintRight",
    "eyeBlinkLeft", "eyeBlinkRight",
    "eyeLookDownLeft", "eyeLookDownRight", "eyeLookInLeft", "eyeLookInRight",
    "eyeLookOutLeft", "eyeLookOutRight", "eyeLookUpLeft", "eyeLookUpRight",
    "eyeSquintLeft", "eyeSquintRight", "eyeWideLeft", "eyeWideRight",
    "jawForward", "jawLeft", "jawOpen", "jawRight",
    "mouthClose", "mouthDimpleLeft", "mouthDimpleRight", "mouthFrownLeft", "mouthFrownRight",
    "mouthFunnel", "mouthLeft", "mouthLowerDownLeft", "mouthLowerDownRight",
    "mouthPressLeft", "mouthPressRight", "mouthPucker", "mouthRight",
    "mouthRollLower", "mouthRollUpper", "mouthShrugLower", "mouthShrugUpper",
    "mouthSmileLeft", "mouthSmileRight", "mouthStretchLeft", "mouthStretchRight",
    "mouthUpperUpLeft", "mouthUpperUpRight",
    "noseSneerLeft", "noseSneerRight", "tongueOut",
)

# Head orientation in radians (from the tracker's head anchor transform).
HEAD_POSE: tuple[str, ...] = ("headYaw", "headPitch", "headRoll")

_BLENDSHAPE_SET = frozenset(ARKIT_BLENDSHAPES)

__all__ = [
    "NAMESPACE",
    "ARKIT_BLENDSHAPES",
    "HEAD_POSE",
    "FaceTrackingFrame",
    "is_blendshape",
    "namespaced",
]


def is_blendshape(name: str) -> bool:
    """True if ``name`` is a known ARKit blendshape coefficient."""
    return name in _BLENDSHAPE_SET


def namespaced(name: str, namespace: str = NAMESPACE) -> str:
    """``"jawOpen"`` -> ``"face.jawOpen"`` — the source path a driver binds to."""
    return f"{namespace}.{name}"


@dataclass(frozen=True)
class FaceTrackingFrame:
    """One tracked moment: blendshape coefficients (0..1) + head pose (radians).

    Unknown blendshape names are rejected so a typo can't silently drive nothing.
    Missing coefficients simply don't appear in ``values`` (a driver for an
    absent input keeps its base value, per ``evaluate_surfaces``).
    """

    blendshapes: Mapping[str, float] = field(default_factory=dict)
    head_yaw: float = 0.0
    head_pitch: float = 0.0
    head_roll: float = 0.0

    def __post_init__(self) -> None:
        for name in self.blendshapes:
            if name not in _BLENDSHAPE_SET:
                raise ValueError(f"unknown ARKit blendshape {name!r}")

    def values(self, namespace: str = NAMESPACE) -> dict[str, float]:
        """The evaluated ``values`` dict a character's drivers read.

        Keys are namespaced (``"face.jawOpen"``, ``"face.headYaw"``) so tracking
        inputs never collide with rig DOF paths or other parameters.
        """
        resolved = {
            namespaced(name, namespace): min(max(float(value), 0.0), 1.0)
            for name, value in self.blendshapes.items()
        }
        resolved[namespaced("headYaw", namespace)] = self.head_yaw
        resolved[namespaced("headPitch", namespace)] = self.head_pitch
        resolved[namespaced("headRoll", namespace)] = self.head_roll
        return resolved
