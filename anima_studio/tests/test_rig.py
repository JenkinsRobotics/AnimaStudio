"""Rig model: typed joints/DOF, validation, evaluation, projection."""

import math

import pytest

from anima_studio.rig import (
    JOINT_TYPE_DOF_TEMPLATES,
    DofKind,
    Identity,
    Joint,
    JointType,
    OutputMapping,
    Parameter,
    Part,
    Pose,
    Rig,
    RigClip,
    RotationDof,
    TranslationDof,
    evaluate_pose,
    project_channels,
)
from anima_studio.sim import SimulatedDevice
from anima_studio.tracks import Clip, Keyframe, Track

PAN_RANGE_RADIANS = math.radians(45.0)


def rotation_dof(
    name: str = "rotation",
    min_radians: float = -PAN_RANGE_RADIANS,
    max_radians: float = PAN_RANGE_RADIANS,
    neutral_radians: float = 0.0,
) -> RotationDof:
    return RotationDof(
        name=name,
        min_radians=min_radians,
        max_radians=max_radians,
        neutral_radians=neutral_radians,
    )


def translation_dof(
    name: str = "translation",
    min_meters: float = 0.0,
    max_meters: float = 0.1,
    neutral_meters: float = 0.0,
) -> TranslationDof:
    return TranslationDof(
        name=name,
        min_meters=min_meters,
        max_meters=max_meters,
        neutral_meters=neutral_meters,
    )


def template_dofs(joint_type: JointType) -> tuple:
    """Build a valid DOF tuple straight from the type's template."""
    dofs = []
    for default_name, kind in JOINT_TYPE_DOF_TEMPLATES[joint_type]:
        if kind is DofKind.ROTATION:
            dofs.append(rotation_dof(name=default_name))
        else:
            dofs.append(translation_dof(name=default_name))
    return tuple(dofs)


def pan_joint() -> Joint:
    return Joint(
        name="pan",
        joint_type=JointType.REVOLUTE,
        parent_part="base",
        child_part="carriage",
        dofs=(rotation_dof(),),
    )


def slide_joint(neutral_meters: float = 0.02) -> Joint:
    return Joint(
        name="slide",
        joint_type=JointType.PRISMATIC,
        parent_part="base",
        child_part="slider",
        dofs=(translation_dof(neutral_meters=neutral_meters),),
    )


def pan_clip(name: str = "sweep", loop: bool = False) -> RigClip:
    return RigClip(
        clip=Clip(
            name=name,
            duration_seconds=1.0,
            tracks={
                "pan.rotation": Track(
                    keyframes=(
                        Keyframe(time_seconds=0.0, value=0.0),
                        Keyframe(time_seconds=1.0, value=PAN_RANGE_RADIANS),
                    ),
                    minimum_value=-PAN_RANGE_RADIANS,
                    maximum_value=PAN_RANGE_RADIANS,
                ),
            },
        ),
        loop=loop,
    )


def mechanism_rig(**overrides) -> Rig:
    fields = {
        "identity": Identity(name="test"),
        "parts": {
            "base": Part(name="base"),
            "carriage": Part(name="carriage", parent="base"),
            "slider": Part(name="slider", parent="base"),
        },
        "joints": {"pan": pan_joint(), "slide": slide_joint()},
        "parameters": {"glow": Parameter(name="glow")},
        "clips": {"sweep": pan_clip()},
    }
    fields.update(overrides)
    return Rig(**fields)


class TestJointTypeDofSets:
    @pytest.mark.parametrize("joint_type", list(JointType))
    def test_template_shaped_dofs_accepted(self, joint_type):
        joint = Joint(
            name="j",
            joint_type=joint_type,
            parent_part="a",
            child_part="b",
            dofs=template_dofs(joint_type),
        )
        assert len(joint.dofs) == len(JOINT_TYPE_DOF_TEMPLATES[joint_type])

    def test_fastened_has_zero_dof(self):
        assert JOINT_TYPE_DOF_TEMPLATES[JointType.FASTENED] == ()

    def test_revolute_is_one_rotation(self):
        kinds = [k for _, k in JOINT_TYPE_DOF_TEMPLATES[JointType.REVOLUTE]]
        assert kinds == [DofKind.ROTATION]

    def test_prismatic_is_one_translation(self):
        kinds = [k for _, k in JOINT_TYPE_DOF_TEMPLATES[JointType.PRISMATIC]]
        assert kinds == [DofKind.TRANSLATION]

    def test_cylindrical_and_pin_slot_are_rotation_plus_translation(self):
        for joint_type in (JointType.CYLINDRICAL, JointType.PIN_SLOT):
            kinds = [k for _, k in JOINT_TYPE_DOF_TEMPLATES[joint_type]]
            assert kinds == [DofKind.ROTATION, DofKind.TRANSLATION]

    def test_planar_is_two_translations_one_rotation(self):
        kinds = [k for _, k in JOINT_TYPE_DOF_TEMPLATES[JointType.PLANAR]]
        assert kinds == [
            DofKind.TRANSLATION, DofKind.TRANSLATION, DofKind.ROTATION,
        ]

    def test_ball_is_three_rotations(self):
        kinds = [k for _, k in JOINT_TYPE_DOF_TEMPLATES[JointType.BALL]]
        assert kinds == [DofKind.ROTATION] * 3


class TestJointValidation:
    def test_mismatched_dof_kind_rejected(self):
        with pytest.raises(ValueError):
            Joint(
                name="j",
                joint_type=JointType.REVOLUTE,
                parent_part="a",
                child_part="b",
                dofs=(translation_dof(),),
            )

    def test_extra_dof_rejected(self):
        with pytest.raises(ValueError):
            Joint(
                name="j",
                joint_type=JointType.REVOLUTE,
                parent_part="a",
                child_part="b",
                dofs=(rotation_dof("a"), rotation_dof("b")),
            )

    def test_fastened_with_a_dof_rejected(self):
        with pytest.raises(ValueError):
            Joint(
                name="j",
                joint_type=JointType.FASTENED,
                parent_part="a",
                child_part="b",
                dofs=(rotation_dof(),),
            )

    def test_missing_dofs_rejected(self):
        with pytest.raises(ValueError):
            Joint(
                name="j",
                joint_type=JointType.BALL,
                parent_part="a",
                child_part="b",
                dofs=(rotation_dof(),),
            )

    def test_duplicate_dof_names_rejected(self):
        with pytest.raises(ValueError):
            Joint(
                name="j",
                joint_type=JointType.CYLINDRICAL,
                parent_part="a",
                child_part="b",
                dofs=(rotation_dof("same"), translation_dof("same")),
            )

    def test_self_connection_rejected(self):
        with pytest.raises(ValueError):
            Joint(
                name="j",
                joint_type=JointType.REVOLUTE,
                parent_part="a",
                child_part="a",
                dofs=(rotation_dof(),),
            )

    def test_dot_in_joint_name_rejected(self):
        with pytest.raises(ValueError):
            Joint(
                name="a.b",
                joint_type=JointType.REVOLUTE,
                parent_part="a",
                child_part="b",
                dofs=(rotation_dof(),),
            )

    def test_dot_in_dof_name_rejected(self):
        with pytest.raises(ValueError):
            rotation_dof(name="a.b")

    def test_bad_rotation_range_rejected(self):
        with pytest.raises(ValueError):
            rotation_dof(min_radians=1.0, max_radians=1.0)

    def test_rotation_neutral_outside_range_rejected(self):
        with pytest.raises(ValueError):
            rotation_dof(min_radians=0.0, max_radians=1.0,
                         neutral_radians=2.0)

    def test_bad_translation_range_rejected(self):
        with pytest.raises(ValueError):
            translation_dof(min_meters=0.1, max_meters=0.1)

    def test_translation_neutral_outside_range_rejected(self):
        with pytest.raises(ValueError):
            translation_dof(min_meters=0.0, max_meters=0.1,
                            neutral_meters=0.5)

    def test_zero_axis_rejected(self):
        with pytest.raises(ValueError):
            RotationDof(
                name="rotation",
                min_radians=-1.0,
                max_radians=1.0,
                axis=(0.0, 0.0, 0.0),
            )


class TestPartAndParameterValidation:
    def test_part_cannot_be_its_own_parent(self):
        with pytest.raises(ValueError):
            Part(name="a", parent="a")

    def test_parameter_neutral_outside_unit_range_rejected(self):
        with pytest.raises(ValueError):
            Parameter(name="p", neutral_value=1.5)

    def test_dot_in_parameter_name_rejected(self):
        with pytest.raises(ValueError):
            Parameter(name="a.b")


class TestRigValidation:
    def test_joint_referencing_undeclared_part_rejected(self):
        with pytest.raises(ValueError):
            mechanism_rig(parts={"base": Part(name="base")})

    def test_part_parent_referencing_undeclared_part_rejected(self):
        with pytest.raises(ValueError):
            mechanism_rig(parts={
                "base": Part(name="base", parent="ghost"),
                "carriage": Part(name="carriage"),
                "slider": Part(name="slider"),
            })

    def test_key_name_mismatch_rejected(self):
        with pytest.raises(ValueError):
            mechanism_rig(joints={"other": pan_joint()}, clips={})

    def test_clip_animating_unknown_target_rejected(self):
        with pytest.raises(ValueError):
            mechanism_rig(joints={"slide": slide_joint()})

    def test_clip_targeting_fastened_joint_rejected(self):
        # A fastened joint has no DOF, so no path under it is animatable.
        lock = Joint(
            name="pan",
            joint_type=JointType.FASTENED,
            parent_part="base",
            child_part="carriage",
        )
        with pytest.raises(ValueError):
            mechanism_rig(joints={"pan": lock, "slide": slide_joint()})

    def test_output_to_unknown_target_rejected(self):
        with pytest.raises(ValueError):
            mechanism_rig(outputs=(
                OutputMapping(
                    target="tail.rotation",
                    channel=0,
                    value_at_zero=-1.0,
                    value_at_one=1.0,
                ),
            ))

    def test_duplicate_output_channel_rejected(self):
        with pytest.raises(ValueError):
            mechanism_rig(outputs=(
                OutputMapping(
                    target="pan.rotation",
                    channel=0,
                    value_at_zero=-1.0,
                    value_at_one=1.0,
                ),
                OutputMapping(
                    target="glow",
                    channel=0,
                    value_at_zero=0.0,
                    value_at_one=1.0,
                ),
            ))


class TestDofPaths:
    def test_paths_are_joint_dot_dof(self):
        rig = mechanism_rig()
        assert set(rig.dof_paths()) == {"pan.rotation", "slide.translation"}

    def test_multi_dof_joint_paths(self):
        joint = Joint(
            name="j",
            joint_type=JointType.BALL,
            parent_part="a",
            child_part="b",
            dofs=template_dofs(JointType.BALL),
        )
        assert set(joint.dof_paths()) == {
            "j.rotation_x", "j.rotation_y", "j.rotation_z",
        }


class TestEvaluatePose:
    def test_no_clip_gives_every_neutral(self):
        pose = evaluate_pose(mechanism_rig())
        assert pose.dof_values == {"pan.rotation": 0.0,
                                   "slide.translation": 0.02}
        assert pose.parameter_values == {"glow": 0.0}

    def test_unanimated_targets_fall_back_to_neutral(self):
        pose = evaluate_pose(mechanism_rig(), "sweep", 0.5)
        assert pose.dof_values["pan.rotation"] == pytest.approx(
            PAN_RANGE_RADIANS / 2)
        assert pose.dof_values["slide.translation"] == 0.02  # neutral meters
        assert pose.parameter_values["glow"] == 0.0  # neutral

    def test_empty_clip_is_legal_and_gives_neutrals(self):
        rig = mechanism_rig(clips={
            "rest": RigClip(clip=Clip(name="rest", duration_seconds=1.0)),
        })
        pose = evaluate_pose(rig, "rest", 0.5)
        assert pose.dof_values["slide.translation"] == 0.02

    def test_non_looping_clip_clamps_past_the_end(self):
        pose = evaluate_pose(mechanism_rig(), "sweep", 99.0)
        assert pose.dof_values["pan.rotation"] == PAN_RANGE_RADIANS

    def test_looping_clip_wraps_time(self):
        rig = mechanism_rig(clips={"sweep": pan_clip(loop=True)})
        wrapped = evaluate_pose(rig, "sweep", 2.25)
        direct = evaluate_pose(rig, "sweep", 0.25)
        assert wrapped == direct

    def test_unknown_clip_name_raises(self):
        with pytest.raises(KeyError):
            evaluate_pose(mechanism_rig(), "missing", 0.0)

    def test_deterministic(self):
        rig = mechanism_rig()
        assert evaluate_pose(rig, "sweep", 0.73) == evaluate_pose(
            rig, "sweep", 0.73)


class TestOutputMapping:
    def test_negative_channel_rejected(self):
        with pytest.raises(ValueError):
            OutputMapping(target="t", channel=-1,
                          value_at_zero=0.0, value_at_one=1.0)

    def test_zero_span_rejected(self):
        with pytest.raises(ValueError):
            OutputMapping(target="t", channel=0,
                          value_at_zero=0.5, value_at_one=0.5)

    def test_projection_and_clamping(self):
        mapping = OutputMapping(target="pan.rotation", channel=0,
                                value_at_zero=-1.0, value_at_one=1.0)
        assert mapping.channel_value(-1.0) == 0.0
        assert mapping.channel_value(0.0) == 0.5
        assert mapping.channel_value(0.5) == pytest.approx(0.75)
        assert mapping.channel_value(-5.0) == 0.0  # clamped
        assert mapping.channel_value(5.0) == 1.0  # clamped

    def test_descending_range_inverts(self):
        mapping = OutputMapping(target="pan.rotation", channel=0,
                                value_at_zero=1.0, value_at_one=-1.0)
        assert mapping.channel_value(1.0) == 0.0
        assert mapping.channel_value(-1.0) == 1.0
        assert mapping.channel_value(0.5) == pytest.approx(0.25)


class TestProjectChannels:
    def rig_with_outputs(self) -> Rig:
        return mechanism_rig(outputs=(
            OutputMapping(
                target="pan.rotation",
                channel=0,
                value_at_zero=-PAN_RANGE_RADIANS,
                value_at_one=PAN_RANGE_RADIANS,
            ),
            OutputMapping(
                target="slide.translation",
                channel=1,
                value_at_zero=0.0,
                value_at_one=0.1,
            ),
            OutputMapping(
                target="glow",
                channel=2,
                value_at_zero=0.0,
                value_at_one=1.0,
            ),
        ))

    def test_projects_dof_and_parameter_targets(self):
        rig = self.rig_with_outputs()
        channels = project_channels(rig, evaluate_pose(rig, "sweep", 1.0))
        assert channels[0] == 1.0  # pan at max radians
        assert channels[1] == pytest.approx(0.2)  # slide neutral 0.02 m
        assert channels[2] == 0.0  # glow neutral

    def test_unmapped_targets_omitted(self):
        rig = mechanism_rig()
        assert project_channels(rig, evaluate_pose(rig)) == {}

    def test_projection_matches_simulated_pulse_math(self):
        """Round-trip: DOF value → channel value → FRM → pulse width
        equals the pulse computed directly from the value."""
        rig = self.rig_with_outputs()
        device = SimulatedDevice(channel_count=3)
        device.receive_line("CFG,0,servo,pin=9,min_us=600,max_us=2400")
        device.receive_line("EN,0,1")

        angle_radians = math.radians(22.5)
        pose = Pose(
            dof_values={"pan.rotation": angle_radians,
                        "slide.translation": 0.0},
            parameter_values={"glow": 0.0},
        )
        channels = project_channels(rig, pose)
        assert device.receive_line(f"FRM,0,0:{channels[0]:.3f}") == "OK"

        # Direct pulse math: -45° → 600 us, +45° → 2400 us, linear.
        expected_pulse_us = 600 + 1800 * (
            (angle_radians + PAN_RANGE_RADIANS) / (2 * PAN_RANGE_RADIANS)
        )
        assert device.channel_pulse_us(0) == pytest.approx(
            expected_pulse_us, abs=1.0)  # 3-decimal wire quantization

    def test_descending_range_equals_cfg_invert(self):
        """A descending mapping pair and the wire CFG invert flag are two
        routes to the same pulse."""
        ascending = OutputMapping(
            target="pan.rotation",
            channel=0,
            value_at_zero=-PAN_RANGE_RADIANS,
            value_at_one=PAN_RANGE_RADIANS,
        )
        descending = OutputMapping(
            target="pan.rotation",
            channel=1,
            value_at_zero=PAN_RANGE_RADIANS,
            value_at_one=-PAN_RANGE_RADIANS,
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
