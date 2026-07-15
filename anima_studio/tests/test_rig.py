"""Rig model: validation, neutral fallback, servo-channel projection."""

import math

import pytest

from anima_studio.rig import (
    BlendShape,
    Identity,
    Joint,
    Pose,
    Rig,
    RigClip,
    ServoMapping,
    evaluate_pose,
    project_channels,
)
from anima_studio.sim import SimulatedDevice
from anima_studio.tracks import Clip, Keyframe, Track

YAW_RANGE_RADIANS = math.radians(45.0)


def yaw_joint() -> Joint:
    return Joint(
        name="head_yaw",
        min_radians=-YAW_RANGE_RADIANS,
        max_radians=YAW_RANGE_RADIANS,
    )


def pitch_joint(neutral_radians: float = 0.1) -> Joint:
    return Joint(
        name="head_pitch",
        min_radians=-0.5,
        max_radians=0.5,
        neutral_radians=neutral_radians,
    )


def yaw_clip(name: str = "turn", loop: bool = False) -> RigClip:
    return RigClip(
        clip=Clip(
            name=name,
            duration_seconds=1.0,
            tracks={
                "head_yaw": Track(
                    keyframes=(
                        Keyframe(time_seconds=0.0, value=0.0),
                        Keyframe(time_seconds=1.0, value=YAW_RANGE_RADIANS),
                    ),
                    minimum_value=-YAW_RANGE_RADIANS,
                    maximum_value=YAW_RANGE_RADIANS,
                ),
            },
        ),
        loop=loop,
    )


def two_joint_rig(**overrides) -> Rig:
    fields = {
        "identity": Identity(name="test"),
        "joints": {"head_yaw": yaw_joint(), "head_pitch": pitch_joint()},
        "blend_shapes": {"jawOpen": BlendShape(name="jawOpen")},
        "clips": {"turn": yaw_clip()},
    }
    fields.update(overrides)
    return Rig(**fields)


class TestJointValidation:
    def test_bad_range_rejected(self):
        with pytest.raises(ValueError):
            Joint(name="j", min_radians=1.0, max_radians=1.0)

    def test_neutral_outside_range_rejected(self):
        with pytest.raises(ValueError):
            Joint(name="j", min_radians=0.0, max_radians=1.0,
                  neutral_radians=2.0)

    def test_blend_shape_neutral_outside_unit_range_rejected(self):
        with pytest.raises(ValueError):
            BlendShape(name="b", neutral_value=1.5)


class TestRigValidation:
    def test_joint_blend_shape_name_collision_rejected(self):
        with pytest.raises(ValueError):
            two_joint_rig(
                blend_shapes={"head_yaw": BlendShape(name="head_yaw")}
            )

    def test_joint_key_name_mismatch_rejected(self):
        with pytest.raises(ValueError):
            two_joint_rig(joints={"other": yaw_joint()}, clips={})

    def test_clip_animating_unknown_parameter_rejected(self):
        with pytest.raises(ValueError):
            two_joint_rig(joints={"head_pitch": pitch_joint()})

    def test_mapping_to_unknown_joint_rejected(self):
        with pytest.raises(ValueError):
            two_joint_rig(servo_mappings=(
                ServoMapping(
                    joint_name="tail",
                    servo_channel=0,
                    angle_at_zero_radians=-1.0,
                    angle_at_one_radians=1.0,
                ),
            ))

    def test_duplicate_servo_channel_rejected(self):
        mapping = ServoMapping(
            joint_name="head_yaw",
            servo_channel=0,
            angle_at_zero_radians=-1.0,
            angle_at_one_radians=1.0,
        )
        with pytest.raises(ValueError):
            two_joint_rig(servo_mappings=(
                mapping,
                ServoMapping(
                    joint_name="head_pitch",
                    servo_channel=0,
                    angle_at_zero_radians=-1.0,
                    angle_at_one_radians=1.0,
                ),
            ))


class TestEvaluatePose:
    def test_no_clip_gives_every_neutral(self):
        pose = evaluate_pose(two_joint_rig())
        assert pose.joint_angles_radians == {
            "head_yaw": 0.0, "head_pitch": 0.1,
        }
        assert pose.blend_shape_values == {"jawOpen": 0.0}

    def test_unanimated_parameters_fall_back_to_neutral(self):
        pose = evaluate_pose(two_joint_rig(), "turn", 0.5)
        assert pose.joint_angles_radians["head_yaw"] == pytest.approx(
            YAW_RANGE_RADIANS / 2)
        assert pose.joint_angles_radians["head_pitch"] == 0.1  # neutral
        assert pose.blend_shape_values["jawOpen"] == 0.0  # neutral

    def test_empty_clip_is_legal_and_gives_neutrals(self):
        rig = two_joint_rig(clips={
            "rest": RigClip(clip=Clip(name="rest", duration_seconds=1.0)),
        })
        pose = evaluate_pose(rig, "rest", 0.5)
        assert pose.joint_angles_radians["head_pitch"] == 0.1

    def test_non_looping_clip_clamps_past_the_end(self):
        pose = evaluate_pose(two_joint_rig(), "turn", 99.0)
        assert pose.joint_angles_radians["head_yaw"] == YAW_RANGE_RADIANS

    def test_looping_clip_wraps_time(self):
        rig = two_joint_rig(clips={"turn": yaw_clip(loop=True)})
        wrapped = evaluate_pose(rig, "turn", 2.25)
        direct = evaluate_pose(rig, "turn", 0.25)
        assert wrapped == direct

    def test_unknown_clip_name_raises(self):
        with pytest.raises(KeyError):
            evaluate_pose(two_joint_rig(), "missing", 0.0)

    def test_deterministic(self):
        rig = two_joint_rig()
        assert evaluate_pose(rig, "turn", 0.73) == evaluate_pose(
            rig, "turn", 0.73)


class TestServoMapping:
    def test_negative_channel_rejected(self):
        with pytest.raises(ValueError):
            ServoMapping(
                joint_name="j",
                servo_channel=-1,
                angle_at_zero_radians=0.0,
                angle_at_one_radians=1.0,
            )

    def test_zero_span_rejected(self):
        with pytest.raises(ValueError):
            ServoMapping(
                joint_name="j",
                servo_channel=0,
                angle_at_zero_radians=0.5,
                angle_at_one_radians=0.5,
            )

    def test_projection_and_clamping(self):
        mapping = ServoMapping(
            joint_name="head_yaw",
            servo_channel=0,
            angle_at_zero_radians=-1.0,
            angle_at_one_radians=1.0,
        )
        assert mapping.channel_value(-1.0) == 0.0
        assert mapping.channel_value(0.0) == 0.5
        assert mapping.channel_value(0.5) == pytest.approx(0.75)
        assert mapping.channel_value(-5.0) == 0.0  # clamped
        assert mapping.channel_value(5.0) == 1.0  # clamped

    def test_descending_range_inverts(self):
        mapping = ServoMapping(
            joint_name="head_yaw",
            servo_channel=0,
            angle_at_zero_radians=1.0,
            angle_at_one_radians=-1.0,
        )
        assert mapping.channel_value(1.0) == 0.0
        assert mapping.channel_value(-1.0) == 1.0
        assert mapping.channel_value(0.5) == pytest.approx(0.25)


class TestProjectChannels:
    def rig_with_mappings(self) -> Rig:
        return two_joint_rig(servo_mappings=(
            ServoMapping(
                joint_name="head_yaw",
                servo_channel=0,
                angle_at_zero_radians=-YAW_RANGE_RADIANS,
                angle_at_one_radians=YAW_RANGE_RADIANS,
            ),
            ServoMapping(
                joint_name="head_pitch",
                servo_channel=1,
                angle_at_zero_radians=0.5,
                angle_at_one_radians=-0.5,
            ),
        ))

    def test_projects_every_mapped_joint(self):
        rig = self.rig_with_mappings()
        channels = project_channels(rig, evaluate_pose(rig, "turn", 1.0))
        assert channels[0] == 1.0  # yaw at max
        assert channels[1] == pytest.approx(0.4)  # pitch neutral 0.1, inverted

    def test_unmapped_joints_and_blend_shapes_omitted(self):
        rig = two_joint_rig()
        assert project_channels(rig, evaluate_pose(rig)) == {}

    def test_projection_matches_simulated_pulse_math(self):
        """Round-trip: joint angle → channel value → FRM → pulse width
        equals the pulse computed directly from the angle."""
        rig = self.rig_with_mappings()
        device = SimulatedDevice(channel_count=2)
        device.receive_line("CFG,0,servo,pin=9,min_us=600,max_us=2400")
        device.receive_line("EN,0,1")

        angle_radians = math.radians(22.5)
        pose = Pose(
            joint_angles_radians={
                "head_yaw": angle_radians, "head_pitch": 0.0,
            },
            blend_shape_values={"jawOpen": 0.0},
        )
        channels = project_channels(rig, pose)
        assert device.receive_line(f"FRM,0,0:{channels[0]:.3f}") == "OK"

        # Direct pulse math: -45° → 600 us, +45° → 2400 us, linear.
        expected_pulse_us = 600 + 1800 * (
            (angle_radians + YAW_RANGE_RADIANS) / (2 * YAW_RANGE_RADIANS)
        )
        assert device.channel_pulse_us(0) == pytest.approx(
            expected_pulse_us, abs=1.0)  # 3-decimal wire quantization

    def test_descending_range_equals_cfg_invert(self):
        """A descending mapping pair and the wire CFG invert flag are two
        routes to the same pulse."""
        ascending = ServoMapping(
            joint_name="head_yaw",
            servo_channel=0,
            angle_at_zero_radians=-YAW_RANGE_RADIANS,
            angle_at_one_radians=YAW_RANGE_RADIANS,
        )
        descending = ServoMapping(
            joint_name="head_yaw",
            servo_channel=1,
            angle_at_zero_radians=YAW_RANGE_RADIANS,
            angle_at_one_radians=-YAW_RANGE_RADIANS,
        )
        device = SimulatedDevice(channel_count=2)
        device.receive_line("CFG,0,servo,pin=9,min_us=600,max_us=2400,invert=1")
        device.receive_line("CFG,1,servo,pin=10,min_us=600,max_us=2400")

        angle_radians = math.radians(10.0)
        line = (
            f"FRM,0,0:{ascending.channel_value(angle_radians):.3f}"
            f",1:{descending.channel_value(angle_radians):.3f}"
        )
        assert device.receive_line(line) == "OK"
        assert device.channel_pulse_us(0) == pytest.approx(
            device.channel_pulse_us(1), abs=1.0)
