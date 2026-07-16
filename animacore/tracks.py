"""Normalized output-track evaluation for wire streaming.

Deterministic hold/linear keyframe evaluation over normalized 0..1
channel values — what the runtime feeds to `wire.encode_frm`. This is
deliberately NOT a rig evaluator and claims no semantic parity with
AnimaCore's `AnimationEvaluator.swift` (rig-aware joint radians, neutral
fallback, empty tracks); that stays in Swift, and a rig-aware runtime
evaluator arrives with the `.anima` loader. Bézier interpolation is
planned — Studio lands it first (see the active briefing).
"""

from __future__ import annotations

from bisect import bisect_right
from collections.abc import Mapping
from dataclasses import dataclass, field
from enum import StrEnum


class Interpolation(StrEnum):
    HOLD = "hold"
    LINEAR = "linear"


@dataclass(frozen=True)
class Keyframe:
    time_seconds: float
    value: float
    interpolation: Interpolation = Interpolation.LINEAR

    def __post_init__(self) -> None:
        if self.time_seconds < 0:
            raise ValueError(f"keyframe time must be >= 0: {self.time_seconds}")


@dataclass(frozen=True)
class Track:
    """Keyframes for one channel; values clamp to the configured limits."""

    keyframes: tuple[Keyframe, ...]
    minimum_value: float = 0.0
    maximum_value: float = 1.0

    def __post_init__(self) -> None:
        object.__setattr__(self, "keyframes", tuple(self.keyframes))
        if not self.keyframes:
            raise ValueError("track requires at least one keyframe")
        times = [keyframe.time_seconds for keyframe in self.keyframes]
        if any(a >= b for a, b in zip(times, times[1:])):
            raise ValueError("keyframe times must be strictly increasing")
        if self.minimum_value > self.maximum_value:
            raise ValueError(
                f"bad limits: {self.minimum_value} > {self.maximum_value}"
            )


@dataclass(frozen=True)
class Clip:
    name: str
    duration_seconds: float
    tracks: Mapping[int | str, Track] = field(default_factory=dict)

    def __post_init__(self) -> None:
        if self.duration_seconds < 0:
            raise ValueError(f"duration must be >= 0: {self.duration_seconds}")
        for key, track in self.tracks.items():
            if track.keyframes[-1].time_seconds > self.duration_seconds:
                raise ValueError(f"track {key!r} has keyframes past the clip end")


def evaluate_track(track: Track, time_seconds: float) -> float:
    """Deterministic hold/linear evaluation, clamped to the track limits."""
    return min(max(_interpolate(track, time_seconds), track.minimum_value),
               track.maximum_value)


def evaluate_clip(clip: Clip, time_seconds: float) -> dict[int | str, float]:
    """Evaluate every track at ``time_seconds``, clamped to the clip range."""
    clamped_seconds = min(max(time_seconds, 0.0), clip.duration_seconds)
    return {
        key: evaluate_track(track, clamped_seconds)
        for key, track in clip.tracks.items()
    }


def _interpolate(track: Track, time_seconds: float) -> float:
    keyframes = track.keyframes
    if time_seconds <= keyframes[0].time_seconds:
        return keyframes[0].value
    if time_seconds >= keyframes[-1].time_seconds:
        return keyframes[-1].value

    times = [keyframe.time_seconds for keyframe in keyframes]
    lower_index = bisect_right(times, time_seconds) - 1
    lower = keyframes[lower_index]
    upper = keyframes[lower_index + 1]
    if lower.interpolation is Interpolation.HOLD:
        return lower.value

    progress = (
        (time_seconds - lower.time_seconds)
        / (upper.time_seconds - lower.time_seconds)
    )
    return lower.value + ((upper.value - lower.value) * progress)
