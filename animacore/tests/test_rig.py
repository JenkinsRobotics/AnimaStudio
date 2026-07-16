"""Rig model: typed joints/DOF, validation, evaluation, projection."""

import math

import pytest

from animacore.rig import (
    JOINT_TYPE_DOF_TEMPLATES,
    RELATION_KIND_DOF_KINDS,
    DofKind,
    Identity,
    Joint,
    JointType,
    LimitViolationError,
    MateConnector,
    MateControls,
    MateOffset,
    OutputMapping,
    Parameter,
    Part,
    Pose,
    Relation,
    RelationKind,
    RotationAxis,
    Rig,
    RigClip,
    RotationDof,
    TranslationDof,
    evaluate_pose,
    project_channels,
    relations_in_dependency_order,
)
from animacore.sim import SimulatedDevice
from animacore.tracks import Clip, Keyframe, Track

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
    for default_name, kind, _ in JOINT_TYPE_DOF_TEMPLATES[joint_type]:
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
        kinds = [k for _, k, _ in JOINT_TYPE_DOF_TEMPLATES[JointType.REVOLUTE]]
        assert kinds == [DofKind.ROTATION]

    def test_prismatic_is_one_translation(self):
        kinds = [k for _, k, _ in JOINT_TYPE_DOF_TEMPLATES[JointType.PRISMATIC]]
        assert kinds == [DofKind.TRANSLATION]

    def test_cylindrical_and_pin_slot_are_rotation_plus_translation(self):
        for joint_type in (JointType.CYLINDRICAL, JointType.PIN_SLOT):
            kinds = [k for _, k, _ in JOINT_TYPE_DOF_TEMPLATES[joint_type]]
            assert kinds == [DofKind.ROTATION, DofKind.TRANSLATION]

    def test_parallel_is_three_translations_one_rotation(self):
        template = JOINT_TYPE_DOF_TEMPLATES[JointType.PARALLEL]
        assert [(n, k) for n, k, _ in template] == [
            ("translation_x", DofKind.TRANSLATION),
            ("translation_y", DofKind.TRANSLATION),
            ("translation_z", DofKind.TRANSLATION),
            ("rotation", DofKind.ROTATION),
        ]

    def test_planar_is_two_translations_one_rotation(self):
        kinds = [k for _, k, _ in JOINT_TYPE_DOF_TEMPLATES[JointType.PLANAR]]
        assert kinds == [
            DofKind.TRANSLATION, DofKind.TRANSLATION, DofKind.ROTATION,
        ]

    def test_ball_is_three_rotations(self):
        kinds = [k for _, k, _ in JOINT_TYPE_DOF_TEMPLATES[JointType.BALL]]
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

class TestMateControls:
    def test_defaults_absent_id_and_controls(self):
        joint = pan_joint()
        assert joint.id == ""
        assert joint.controls is None

    def test_id_round_trips_verbatim(self):
        joint = Joint(
            name="pan",
            joint_type=JointType.REVOLUTE,
            parent_part="base",
            child_part="carriage",
            dofs=(rotation_dof(),),
            id="Fastened 33",
        )
        assert joint.id == "Fastened 33"

    def test_controls_round_trip_on_the_joint(self):
        controls = MateControls(
            connector_a=MateConnector(part="base"),
            connector_b=MateConnector(part="carriage"),
            offset=MateOffset(
                enabled=True,
                translation_m=(0.0, 0.0, 0.01),
                rotation_axis=RotationAxis.Z,
                rotation_radians=0.1,
            ),
            flip_primary_axis=True,
            secondary_axis_rotation_deg=90,
            simulation_connection=False,
        )
        joint = Joint(
            name="pan",
            joint_type=JointType.REVOLUTE,
            parent_part="base",
            child_part="carriage",
            dofs=(rotation_dof(),),
            controls=controls,
        )
        assert joint.controls == controls
        assert joint.controls.offset.translation_m == (0.0, 0.0, 0.01)

    def test_default_offset_is_disabled_zero(self):
        controls = MateControls()
        assert controls.offset == MateOffset()
        assert controls.offset.enabled is False
        assert controls.offset.rotation_axis is RotationAxis.Z
        assert controls.simulation_connection is True


class TestMateConnector:
    def test_zero_primary_axis_rejected(self):
        with pytest.raises(ValueError):
            MateConnector(part="base", primary_axis=(0.0, 0.0, 0.0))

    def test_zero_secondary_axis_rejected(self):
        with pytest.raises(ValueError):
            MateConnector(part="base", secondary_axis=(0.0, 0.0, 0.0))

    def test_parallel_axes_rejected(self):
        with pytest.raises(ValueError):
            MateConnector(
                part="base",
                primary_axis=(0.0, 0.0, 1.0),
                secondary_axis=(0.0, 0.0, 2.0),
            )

    def test_antiparallel_axes_rejected(self):
        with pytest.raises(ValueError):
            MateConnector(
                part="base",
                primary_axis=(0.0, 0.0, 1.0),
                secondary_axis=(0.0, 0.0, -1.0),
            )

    def test_empty_part_rejected(self):
        with pytest.raises(ValueError):
            MateConnector(part="")

    def test_perpendicular_axes_accepted(self):
        connector = MateConnector(
            part="base",
            primary_axis=(0.0, 0.0, 1.0),
            secondary_axis=(1.0, 0.0, 0.0),
        )
        assert connector.primary_axis == (0.0, 0.0, 1.0)


class TestMateOffset:
    @pytest.mark.parametrize("axis", list(RotationAxis))
    def test_each_rotation_axis(self, axis):
        offset = MateOffset(enabled=True, rotation_axis=axis)
        assert offset.rotation_axis is axis

    def test_enabled_flag_round_trips(self):
        assert MateOffset(enabled=True).enabled is True

    def test_bad_translation_shape_rejected(self):
        with pytest.raises(ValueError):
            MateOffset(translation_m=(0.0, 0.1))


class TestSecondaryAxisRotation:
    @pytest.mark.parametrize("deg", [0, 90, 180, 270])
    def test_allowed_steps_accepted(self, deg):
        controls = MateControls(secondary_axis_rotation_deg=deg)
        assert controls.secondary_axis_rotation_deg == deg

    @pytest.mark.parametrize("deg", [45, 1, 360, -90])
    def test_other_steps_rejected(self, deg):
        with pytest.raises(ValueError):
            MateControls(secondary_axis_rotation_deg=deg)


class TestOptionalLimits:
    def spin_joint(self) -> Joint:
        return Joint(
            name="spin",
            joint_type=JointType.REVOLUTE,
            parent_part="base",
            child_part="carriage",
            dofs=(RotationDof(name="rotation"),),
        )

    def test_unlimited_dof_legal(self):
        dof = RotationDof(name="rotation")
        assert not dof.has_limits
        assert dof.minimum is None and dof.maximum is None
        assert dof.neutral == 0.0

    def test_limited_dof_reports_limits(self):
        assert rotation_dof().has_limits

    @pytest.mark.parametrize(
        "kwargs",
        [
            {"min_radians": -1.0},  # min without max
            {"max_radians": 1.0},  # max without min
        ],
    )
    def test_partial_rotation_limits_rejected(self, kwargs):
        with pytest.raises(ValueError):
            RotationDof(name="rotation", **kwargs)

    def test_partial_translation_limits_rejected(self):
        with pytest.raises(ValueError):
            TranslationDof(name="travel", min_meters=0.0)

    def test_unlimited_dof_skips_neutral_range_check(self):
        assert RotationDof(
            name="rotation", neutral_radians=100.0
        ).neutral == 100.0

    def test_unlimited_dof_evaluates_unclamped(self):
        three_turns_radians = 6 * math.pi
        clip = RigClip(
            clip=Clip(
                name="spin_up",
                duration_seconds=1.0,
                tracks={
                    "spin.rotation": Track(
                        keyframes=(
                            Keyframe(time_seconds=0.0, value=0.0),
                            Keyframe(
                                time_seconds=1.0, value=three_turns_radians
                            ),
                        ),
                        minimum_value=-math.inf,
                        maximum_value=math.inf,
                    ),
                },
            ),
        )
        rig = mechanism_rig(
            joints={"pan": pan_joint(), "slide": slide_joint(),
                    "spin": self.spin_joint()},
            clips={"spin_up": clip},
        )
        pose = evaluate_pose(rig, "spin_up", 1.0)
        assert pose.dof_values["spin.rotation"] == three_turns_radians
        assert pose.limit_violations == ()

    def test_output_mapping_on_unlimited_dof_rejected(self):
        with pytest.raises(ValueError, match="unlimited"):
            mechanism_rig(
                joints={"pan": pan_joint(), "slide": slide_joint(),
                        "spin": self.spin_joint()},
                outputs=(
                    OutputMapping(
                        target="spin.rotation",
                        channel=0,
                        value_at_zero=-1.0,
                        value_at_one=1.0,
                    ),
                ),
            )


def four_joint_rig(
    relations: tuple[Relation, ...] = (),
    clips: dict | None = None,
    outputs: tuple[OutputMapping, ...] = (),
) -> Rig:
    """Two rotations (pan, roll) and two translations (slide, push)."""
    return Rig(
        identity=Identity(name="relations"),
        parts={
            "base": Part(name="base"),
            "carriage": Part(name="carriage", parent="base"),
            "slider": Part(name="slider", parent="base"),
            "wheel": Part(name="wheel", parent="base"),
            "pusher": Part(name="pusher", parent="base"),
        },
        joints={
            "pan": pan_joint(),
            "slide": Joint(
                name="slide",
                joint_type=JointType.PRISMATIC,
                parent_part="base",
                child_part="slider",
                dofs=(translation_dof(min_meters=-0.1, max_meters=0.1),),
            ),
            "roll": Joint(
                name="roll",
                joint_type=JointType.REVOLUTE,
                parent_part="base",
                child_part="wheel",
                dofs=(
                    rotation_dof(min_radians=-math.pi, max_radians=math.pi),
                ),
            ),
            "push": Joint(
                name="push",
                joint_type=JointType.PRISMATIC,
                parent_part="base",
                child_part="pusher",
                dofs=(translation_dof(min_meters=-0.2, max_meters=0.2),),
            ),
        },
        clips=clips or {},
        outputs=outputs,
        relations=relations,
    )


def pan_drive_clip(value_radians: float) -> RigClip:
    """Drive pan.rotation from 0 to ``value_radians`` over one second."""
    return RigClip(
        clip=Clip(
            name="drive",
            duration_seconds=1.0,
            tracks={
                "pan.rotation": Track(
                    keyframes=(
                        Keyframe(time_seconds=0.0, value=0.0),
                        Keyframe(time_seconds=1.0, value=value_radians),
                    ),
                    minimum_value=-PAN_RANGE_RADIANS,
                    maximum_value=PAN_RANGE_RADIANS,
                ),
            },
        ),
    )


class TestRelationValidation:
    def test_kind_pairing_table(self):
        assert RELATION_KIND_DOF_KINDS == {
            RelationKind.GEAR: (DofKind.ROTATION, DofKind.ROTATION),
            RelationKind.RACK_PINION: (
                DofKind.ROTATION, DofKind.TRANSLATION),
            RelationKind.SCREW: (DofKind.ROTATION, DofKind.TRANSLATION),
            RelationKind.LINEAR: (
                DofKind.TRANSLATION, DofKind.TRANSLATION),
        }

    @pytest.mark.parametrize(
        "kind,driver,driven",
        [
            (RelationKind.GEAR, "pan.rotation", "roll.rotation"),
            (RelationKind.RACK_PINION, "pan.rotation", "slide.translation"),
            (RelationKind.SCREW, "pan.rotation", "slide.translation"),
            (RelationKind.LINEAR, "slide.translation", "push.translation"),
        ],
    )
    def test_valid_pairing_accepted(self, kind, driver, driven):
        rig = four_joint_rig(relations=(
            Relation(kind=kind, driver=driver, driven=driven, ratio=0.5),
        ))
        assert rig.relations[0].kind is kind

    @pytest.mark.parametrize(
        "kind,driver,driven",
        [
            (RelationKind.GEAR, "pan.rotation", "slide.translation"),
            (RelationKind.GEAR, "slide.translation", "roll.rotation"),
            (RelationKind.RACK_PINION, "slide.translation",
             "push.translation"),
            (RelationKind.SCREW, "pan.rotation", "roll.rotation"),
            (RelationKind.LINEAR, "pan.rotation", "push.translation"),
            (RelationKind.LINEAR, "slide.translation", "roll.rotation"),
        ],
    )
    def test_wrong_pairing_rejected(self, kind, driver, driven):
        with pytest.raises(ValueError):
            four_joint_rig(relations=(
                Relation(kind=kind, driver=driver, driven=driven, ratio=0.5),
            ))

    def test_non_dof_path_rejected(self):
        with pytest.raises(ValueError):
            Relation(
                kind=RelationKind.GEAR,
                driver="pan",
                driven="roll.rotation",
                ratio=1.0,
            )

    def test_self_coupling_rejected(self):
        with pytest.raises(ValueError):
            Relation(
                kind=RelationKind.GEAR,
                driver="pan.rotation",
                driven="pan.rotation",
                ratio=1.0,
            )

    @pytest.mark.parametrize("ratio", [0.0, math.inf, math.nan])
    def test_bad_ratio_rejected(self, ratio):
        with pytest.raises(ValueError):
            Relation(
                kind=RelationKind.GEAR,
                driver="pan.rotation",
                driven="roll.rotation",
                ratio=ratio,
            )

    def test_display_field_for_wrong_kind_rejected(self):
        with pytest.raises(ValueError):
            Relation(
                kind=RelationKind.GEAR,
                driver="pan.rotation",
                driven="roll.rotation",
                ratio=0.5,
                display={"lead_mm_per_rev": 2.0},
            )

    def test_undeclared_dof_rejected(self):
        with pytest.raises(ValueError):
            four_joint_rig(relations=(
                Relation(
                    kind=RelationKind.GEAR,
                    driver="pan.rotation",
                    driven="ghost.rotation",
                    ratio=0.5,
                ),
            ))

    def test_double_driver_rejected(self):
        gear = Relation(
            kind=RelationKind.GEAR,
            driver="pan.rotation",
            driven="roll.rotation",
            ratio=0.5,
        )
        other_gear = Relation(
            kind=RelationKind.GEAR,
            driver="pan.rotation",
            driven="roll.rotation",
            ratio=-0.5,
        )
        with pytest.raises(ValueError, match="two relations"):
            four_joint_rig(relations=(gear, other_gear))

    def test_cycle_rejected(self):
        forward = Relation(
            kind=RelationKind.GEAR,
            driver="pan.rotation",
            driven="roll.rotation",
            ratio=0.5,
        )
        backward = Relation(
            kind=RelationKind.GEAR,
            driver="roll.rotation",
            driven="pan.rotation",
            ratio=2.0,
        )
        with pytest.raises(ValueError, match="cycle"):
            four_joint_rig(relations=(forward, backward))

    def test_animated_driven_dof_rejected(self):
        gear = Relation(
            kind=RelationKind.GEAR,
            driver="pan.rotation",
            driven="roll.rotation",
            ratio=0.5,
        )
        roll_clip = RigClip(
            clip=Clip(
                name="wiggle",
                duration_seconds=1.0,
                tracks={
                    "roll.rotation": Track(
                        keyframes=(Keyframe(time_seconds=0.0, value=0.0),),
                        minimum_value=-math.pi,
                        maximum_value=math.pi,
                    ),
                },
            ),
        )
        with pytest.raises(ValueError, match="source of truth"):
            four_joint_rig(relations=(gear,), clips={"wiggle": roll_clip})

    def test_dependency_order_resolves_chains(self):
        # Declared driven-first; the order puts the driver chain first.
        downstream = Relation(
            kind=RelationKind.LINEAR,
            driver="slide.translation",
            driven="push.translation",
            ratio=2.0,
        )
        upstream = Relation(
            kind=RelationKind.RACK_PINION,
            driver="pan.rotation",
            driven="slide.translation",
            ratio=0.1,
        )
        assert relations_in_dependency_order(
            (downstream, upstream)) == (upstream, downstream)


class TestRelationEvaluation:
    def test_gear_math_negative_ratio_and_offset(self):
        gear = Relation(
            kind=RelationKind.GEAR,
            driver="pan.rotation",
            driven="roll.rotation",
            ratio=-2.0,
            offset=0.1,
        )
        rig = four_joint_rig(
            relations=(gear,), clips={"drive": pan_drive_clip(0.3)}
        )
        pose = evaluate_pose(rig, "drive", 1.0)
        assert pose.dof_values["roll.rotation"] == pytest.approx(
            -2.0 * 0.3 + 0.1)
        assert pose.limit_violations == ()

    def test_neutral_pose_flows_through_relations(self):
        gear = Relation(
            kind=RelationKind.GEAR,
            driver="pan.rotation",
            driven="roll.rotation",
            ratio=0.5,
            offset=0.2,
        )
        pose = evaluate_pose(four_joint_rig(relations=(gear,)))
        assert pose.dof_values["roll.rotation"] == pytest.approx(0.2)

    def test_chain_evaluates_in_dependency_order(self):
        # Declared out of order on purpose: pan -> slide -> push.
        downstream = Relation(
            kind=RelationKind.LINEAR,
            driver="slide.translation",
            driven="push.translation",
            ratio=2.0,
        )
        upstream = Relation(
            kind=RelationKind.RACK_PINION,
            driver="pan.rotation",
            driven="slide.translation",
            ratio=0.1,
        )
        rig = four_joint_rig(
            relations=(downstream, upstream),
            clips={"drive": pan_drive_clip(0.4)},
        )
        pose = evaluate_pose(rig, "drive", 1.0)
        assert pose.dof_values["slide.translation"] == pytest.approx(0.04)
        assert pose.dof_values["push.translation"] == pytest.approx(0.08)
        assert pose.limit_violations == ()

    def violated_rig(self, outputs: tuple[OutputMapping, ...] = ()) -> Rig:
        # pan at 0.4 rad through ratio 10 pushes roll to 4.0 rad,
        # past its ±π limits.
        gear = Relation(
            kind=RelationKind.GEAR,
            driver="pan.rotation",
            driven="roll.rotation",
            ratio=10.0,
        )
        return four_joint_rig(
            relations=(gear,),
            clips={"drive": pan_drive_clip(0.4)},
            outputs=outputs,
        )

    def test_limit_violation_reported_not_clamped(self):
        pose = evaluate_pose(self.violated_rig(), "drive", 1.0)
        assert pose.dof_values["roll.rotation"] == pytest.approx(4.0)
        violation, = pose.limit_violations
        assert violation.dof_path == "roll.rotation"
        assert violation.value == pytest.approx(4.0)
        assert violation.min_value == pytest.approx(-math.pi)
        assert violation.max_value == pytest.approx(math.pi)

    def test_projection_of_mapped_violated_dof_raises(self):
        rig = self.violated_rig(outputs=(
            OutputMapping(
                target="roll.rotation",
                channel=0,
                value_at_zero=-math.pi,
                value_at_one=math.pi,
            ),
        ))
        pose = evaluate_pose(rig, "drive", 1.0)
        with pytest.raises(LimitViolationError, match="roll.rotation"):
            project_channels(rig, pose)
        # Back inside the limits the same rig projects again.
        assert project_channels(
            rig, evaluate_pose(rig, "drive", 0.0)
        )[0] == pytest.approx(0.5)

    def test_unmapped_violated_dof_does_not_block_other_channels(self):
        rig = self.violated_rig(outputs=(
            OutputMapping(
                target="pan.rotation",
                channel=0,
                value_at_zero=-PAN_RANGE_RADIANS,
                value_at_one=PAN_RANGE_RADIANS,
            ),
        ))
        pose = evaluate_pose(rig, "drive", 1.0)
        assert pose.limit_violations  # roll is violated but unmapped
        assert 0 in project_channels(rig, pose)

    def test_relation_streams_to_simulated_device(self):
        """Clip → relation → channel projection → FRM → simulated pulse."""
        gear = Relation(
            kind=RelationKind.GEAR,
            driver="pan.rotation",
            driven="roll.rotation",
            ratio=-1.0,
        )
        rig = four_joint_rig(
            relations=(gear,),
            clips={"drive": pan_drive_clip(math.radians(30.0))},
            outputs=(
                OutputMapping(
                    target="roll.rotation",
                    channel=0,
                    value_at_zero=math.radians(-45.0),
                    value_at_one=math.radians(45.0),
                ),
            ),
        )
        device = SimulatedDevice(channel_count=1)
        assert device.receive_line(
            "CFG,0,servo,pin=9,min_us=600,max_us=2400") == "OK"
        assert device.receive_line("EN,0,1") == "OK"
        channels = project_channels(rig, evaluate_pose(rig, "drive", 1.0))
        assert device.receive_line(f"FRM,0,0:{channels[0]:.3f}") == "OK"
        # pan +30 deg → roll -30 deg → (−30+45)/90 of the pulse span.
        expected_pulse_us = 600 + 1800 * (15.0 / 90.0)
        assert device.channel_pulse_us(0) == pytest.approx(
            expected_pulse_us, abs=1.0)


class TestProjectChannelsEndToEnd:
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
