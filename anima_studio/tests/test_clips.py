"""Keyframe clip evaluation: hold/linear, clamping, determinism."""

import pytest

from anima_studio.clips import (
    Clip,
    Interpolation,
    Keyframe,
    Track,
    evaluate_clip,
    evaluate_track,
)


def linear_track() -> Track:
    return Track(keyframes=(
        Keyframe(time_seconds=0.0, value=0.0),
        Keyframe(time_seconds=1.0, value=1.0),
        Keyframe(time_seconds=2.0, value=0.5),
    ))


class TestEvaluateTrack:
    def test_linear_interpolation(self):
        track = linear_track()
        assert evaluate_track(track, 0.5) == pytest.approx(0.5)
        assert evaluate_track(track, 1.5) == pytest.approx(0.75)

    def test_exact_keyframe_times(self):
        track = linear_track()
        assert evaluate_track(track, 0.0) == 0.0
        assert evaluate_track(track, 1.0) == 1.0
        assert evaluate_track(track, 2.0) == 0.5

    def test_hold_keeps_value_until_next_keyframe(self):
        track = Track(keyframes=(
            Keyframe(time_seconds=0.0, value=0.2,
                     interpolation=Interpolation.HOLD),
            Keyframe(time_seconds=1.0, value=0.8),
        ))
        assert evaluate_track(track, 0.0) == 0.2
        assert evaluate_track(track, 0.999) == 0.2
        assert evaluate_track(track, 1.0) == 0.8

    def test_clamps_before_first_and_after_last_keyframe(self):
        track = Track(keyframes=(
            Keyframe(time_seconds=0.5, value=0.3),
            Keyframe(time_seconds=1.0, value=0.7),
        ))
        assert evaluate_track(track, 0.0) == 0.3
        assert evaluate_track(track, 5.0) == 0.7

    def test_clamps_values_to_track_limits(self):
        track = Track(
            keyframes=(
                Keyframe(time_seconds=0.0, value=0.0),
                Keyframe(time_seconds=1.0, value=1.0),
            ),
            minimum_value=0.25,
            maximum_value=0.75,
        )
        assert evaluate_track(track, 0.0) == 0.25
        assert evaluate_track(track, 0.5) == 0.5
        assert evaluate_track(track, 1.0) == 0.75

    def test_deterministic(self):
        track = linear_track()
        assert evaluate_track(track, 0.73) == evaluate_track(track, 0.73)

    def test_single_keyframe(self):
        track = Track(keyframes=(Keyframe(time_seconds=0.5, value=0.4),))
        assert evaluate_track(track, 0.0) == 0.4
        assert evaluate_track(track, 1.0) == 0.4


class TestEvaluateClip:
    def test_clamps_time_to_clip_range(self):
        clip = Clip(name="c", duration_seconds=2.0, tracks={"jaw": linear_track()})
        assert evaluate_clip(clip, -1.0) == {"jaw": 0.0}
        assert evaluate_clip(clip, 99.0) == {"jaw": 0.5}

    def test_evaluates_every_track(self):
        clip = Clip(
            name="c",
            duration_seconds=1.0,
            tracks={
                0: Track(keyframes=(Keyframe(time_seconds=0.0, value=0.1),)),
                1: Track(keyframes=(Keyframe(time_seconds=0.0, value=0.9),)),
            },
        )
        assert evaluate_clip(clip, 0.5) == {0: 0.1, 1: 0.9}


class TestValidation:
    def test_negative_keyframe_time_rejected(self):
        with pytest.raises(ValueError):
            Keyframe(time_seconds=-0.1, value=0.5)

    def test_empty_track_rejected(self):
        with pytest.raises(ValueError):
            Track(keyframes=())

    def test_non_increasing_times_rejected(self):
        with pytest.raises(ValueError):
            Track(keyframes=(
                Keyframe(time_seconds=1.0, value=0.0),
                Keyframe(time_seconds=1.0, value=1.0),
            ))

    def test_bad_limits_rejected(self):
        with pytest.raises(ValueError):
            Track(
                keyframes=(Keyframe(time_seconds=0.0, value=0.0),),
                minimum_value=0.9,
                maximum_value=0.1,
            )

    def test_negative_duration_rejected(self):
        with pytest.raises(ValueError):
            Clip(name="c", duration_seconds=-1.0)

    def test_keyframes_past_clip_end_rejected(self):
        with pytest.raises(ValueError):
            Clip(name="c", duration_seconds=0.5, tracks={"jaw": linear_track()})
