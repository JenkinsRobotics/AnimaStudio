"""`.character.anima` loader: accepted subset, rejections, end-to-end."""

import copy
import math
from pathlib import Path

import pytest
import yaml

from anima_studio.loader import (
    CharacterFormatError,
    load_character_file,
    parse_character,
)
from anima_studio.rig import DofKind, JointType, evaluate_pose, project_channels
from anima_studio.sim import SimulatedDevice
from anima_studio.tracks import Interpolation
from anima_studio.wire import Ok, encode_frm, parse_reply

EXAMPLES_DIR = Path(__file__).resolve().parents[2] / "examples"
EXAMPLE_PATHS = sorted(EXAMPLES_DIR.glob("*.character.anima"))

BASE_DOCUMENT = {
    "anima_version": "2.0",
    "type": "character",
    "identity": {"name": "testbot"},
    "parts": {
        "base": None,
        "carriage": {"parent": "base", "model_node": "rig/carriage"},
    },
    "joints": {
        "pan": {
            "type": "revolute",
            "parent": "base",
            "child": "carriage",
            "dofs": {
                "rotation": {"min_deg": -45, "max_deg": 45, "neutral_deg": 0},
            },
        },
    },
    "parameters": {"glow": {"default": 0.0}},
    "clips": {
        "sweep": {
            "duration_s": 1.0,
            "tracks": [
                {"time": 0.0, "values": {"pan.rotation": 0.0, "glow": 0.0}},
                {"time": 1.0, "values": {"pan.rotation": 45.0, "glow": 1.0}},
            ],
        },
    },
    "outputs": [
        {"target": "pan.rotation", "channel": 0, "range_deg": [-45, 45]},
        {"target": "glow", "channel": 1, "range": [0.0, 1.0]},
    ],
}


def document(**overrides) -> dict:
    doc = copy.deepcopy(BASE_DOCUMENT)
    doc.update(overrides)
    return doc


def parse(doc: dict):
    return parse_character(yaml.safe_dump(doc))


def assert_rejects(doc: dict, path_fragment: str):
    with pytest.raises(CharacterFormatError) as excinfo:
        parse(doc)
    assert path_fragment in excinfo.value.path, excinfo.value


class TestAccepts:
    def test_base_document_loads(self):
        rig = parse(document())
        assert rig.identity.name == "testbot"
        assert rig.parts["carriage"].parent == "base"
        assert rig.parts["carriage"].model_node == "rig/carriage"
        pan = rig.joints["pan"]
        assert pan.joint_type is JointType.REVOLUTE
        assert pan.parent_part == "base" and pan.child_part == "carriage"
        assert pan.dofs[0].max_radians == pytest.approx(math.radians(45))
        assert rig.parameters["glow"].neutral_value == 0.0
        assert rig.clips["sweep"].clip.duration_seconds == 1.0
        assert rig.outputs[0].channel == 0

    def test_sections_other_than_identity_are_optional(self):
        rig = parse({
            "anima_version": "2.0",
            "type": "character",
            "identity": {"name": "empty"},
        })
        assert rig.parts == {} and rig.joints == {} and rig.clips == {}
        assert evaluate_pose(rig) is not None

    def test_rotation_degrees_convert_to_radians(self):
        rig = parse(document())
        pose = evaluate_pose(rig, "sweep", 1.0)
        assert pose.dof_values["pan.rotation"] == pytest.approx(
            math.radians(45))

    def test_translation_meters_stay_meters(self):
        doc = document(clips={}, outputs=[])
        doc["joints"]["lift"] = {
            "type": "prismatic",
            "parent": "base",
            "child": "carriage",
            "dofs": {
                "travel": {"min_m": 0.0, "max_m": 0.2, "neutral_m": 0.05},
            },
        }
        rig = parse(doc)
        dof = rig.joints["lift"].dofs[0]
        assert dof.kind is DofKind.TRANSLATION
        assert dof.neutral_meters == 0.05
        assert evaluate_pose(rig).dof_values["lift.travel"] == 0.05

    @pytest.mark.parametrize(
        "joint_type,dofs",
        [
            ("fastened", None),
            ("revolute",
             {"rotation": {"min_deg": -45, "max_deg": 45}}),
            ("prismatic",
             {"travel": {"min_m": 0.0, "max_m": 0.1}}),
            ("cylindrical",
             {"rotation": {"min_deg": -90, "max_deg": 90},
              "travel": {"min_m": 0.0, "max_m": 0.1}}),
            ("pin_slot",
             {"rotation": {"min_deg": -90, "max_deg": 90},
              "travel": {"min_m": 0.0, "max_m": 0.1}}),
            ("planar",
             {"slide_x": {"min_m": -0.1, "max_m": 0.1},
              "slide_y": {"min_m": -0.1, "max_m": 0.1},
              "rotation": {"min_deg": -180, "max_deg": 180}}),
            ("ball",
             {"rotation_x": {"min_deg": -30, "max_deg": 30},
              "rotation_y": {"min_deg": -30, "max_deg": 30},
              "rotation_z": {"min_deg": -30, "max_deg": 30}}),
        ],
    )
    def test_every_joint_type_parses(self, joint_type, dofs):
        doc = document(clips={}, outputs=[])
        entry = {"type": joint_type, "parent": "base", "child": "carriage"}
        if dofs is not None:
            entry["dofs"] = dofs
        doc["joints"] = {"j": entry}
        rig = parse(doc)
        assert rig.joints["j"].joint_type is JointType(joint_type)
        expected = 0 if dofs is None else len(dofs)
        assert len(rig.joints["j"].dofs) == expected

    def test_custom_dof_name_is_addressable(self):
        doc = document(clips={}, outputs=[])
        doc["joints"]["pan"]["dofs"] = {
            "swing": {"min_deg": -45, "max_deg": 45},
        }
        rig = parse(doc)
        assert "pan.swing" in rig.dof_paths()

    def test_dof_axis_parses(self):
        doc = document()
        doc["joints"]["pan"]["dofs"]["rotation"]["axis"] = [0, 0, 1]
        rig = parse(doc)
        assert rig.joints["pan"].dofs[0].axis == (0.0, 0.0, 1.0)

    def test_hold_interpolation_parses_and_holds(self):
        doc = document()
        doc["clips"]["sweep"]["tracks"] = [
            {"time": 0.0, "values": {"pan.rotation": 30.0},
             "interpolation": "hold"},
            {"time": 1.0, "values": {"pan.rotation": 0.0}},
        ]
        rig = parse(doc)
        track = rig.clips["sweep"].clip.tracks["pan.rotation"]
        assert track.keyframes[0].interpolation is Interpolation.HOLD
        pose = evaluate_pose(rig, "sweep", 0.99)
        assert pose.dof_values["pan.rotation"] == pytest.approx(
            math.radians(30))

    def test_sparse_entries_build_per_target_tracks(self):
        doc = document()
        doc["clips"]["sweep"]["tracks"] = [
            {"time": 0.0, "values": {"pan.rotation": 0.0, "glow": 0.0}},
            {"time": 0.5, "values": {"glow": 1.0}},
            {"time": 1.0, "values": {"pan.rotation": 45.0}},
        ]
        rig = parse(doc)
        tracks = rig.clips["sweep"].clip.tracks
        assert len(tracks["pan.rotation"].keyframes) == 2
        assert len(tracks["glow"].keyframes) == 2

    def test_loop_flag_parses(self):
        doc = document()
        doc["clips"]["sweep"]["loop"] = True
        assert parse(doc).clips["sweep"].loop

    def test_descending_output_range_inverts(self):
        doc = document()
        doc["outputs"][0]["range_deg"] = [45, -45]
        rig = parse(doc)
        channels = project_channels(rig, evaluate_pose(rig, "sweep", 1.0))
        assert channels[0] == 0.0  # pan at +45 deg on an inverted channel


class TestRejects:
    def test_corrupt_yaml(self):
        with pytest.raises(CharacterFormatError):
            parse_character("clips: [unclosed")

    def test_non_mapping_document(self):
        with pytest.raises(CharacterFormatError):
            parse_character("- just\n- a\n- list\n")

    def test_missing_version(self):
        doc = document()
        del doc["anima_version"]
        assert_rejects(doc, "anima_version")

    def test_old_version_rejected(self):
        assert_rejects(document(anima_version="1.0"), "anima_version")

    def test_wrong_type(self):
        assert_rejects(document(type="scene"), "type")

    def test_missing_identity(self):
        doc = document()
        del doc["identity"]
        assert_rejects(doc, "identity")

    def test_missing_identity_name(self):
        assert_rejects(document(identity={}), "identity.name")

    def test_unknown_top_level_field(self):
        assert_rejects(document(bogus={}), "bogus")

    @pytest.mark.parametrize(
        "section", ["expressions", "lip_sync", "digital", "voice"])
    def test_unsupported_spec_sections_reject_loudly(self, section):
        assert_rejects(document(**{section: {}}), section)

    @pytest.mark.parametrize(
        "section", ["bones", "blend_shapes", "physical"])
    def test_superseded_format_1_sections_rejected(self, section):
        assert_rejects(document(**{section: {}}), section)

    def test_unknown_joint_type(self):
        doc = document(clips={}, outputs=[])
        doc["joints"]["pan"]["type"] = "hinge"
        assert_rejects(doc, "joints.pan.type")

    @pytest.mark.parametrize("field", ["type", "parent", "child"])
    def test_joint_missing_required_field(self, field):
        doc = document(clips={}, outputs=[])
        del doc["joints"]["pan"][field]
        assert_rejects(doc, f"joints.pan.{field}")

    def test_joint_referencing_undeclared_part(self):
        doc = document(clips={}, outputs=[])
        doc["joints"]["pan"]["child"] = "ghost"
        assert_rejects(doc, "joints.pan.child")

    def test_part_parent_undeclared(self):
        doc = document(clips={}, joints={}, outputs=[])
        doc["parts"]["carriage"] = {"parent": "ghost"}
        assert_rejects(doc, "parts.carriage.parent")

    def test_part_self_parent(self):
        doc = document(clips={}, joints={}, outputs=[])
        doc["parts"]["base"] = {"parent": "base"}
        assert_rejects(doc, "parts.base")

    def test_part_unknown_field(self):
        doc = document()
        doc["parts"]["base"] = {"mass_kg": 1.0}
        assert_rejects(doc, "parts.base.mass_kg")

    def test_revolute_with_extra_dof_rejected(self):
        doc = document(clips={}, outputs=[])
        doc["joints"]["pan"]["dofs"]["extra"] = {"min_m": 0.0, "max_m": 0.1}
        assert_rejects(doc, "joints.pan.dofs")

    def test_fastened_with_dofs_rejected(self):
        doc = document(clips={}, outputs=[])
        doc["joints"]["pan"] = {
            "type": "fastened",
            "parent": "base",
            "child": "carriage",
            "dofs": {"rotation": {"min_deg": -45, "max_deg": 45}},
        }
        assert_rejects(doc, "joints.pan.dofs")

    def test_wrong_unit_keys_for_dof_kind_rejected(self):
        # The joint type defines the DOF kind, so degree limits on a
        # prismatic joint's DOF cannot re-kind it — they are rejected.
        doc = document(clips={}, outputs=[])
        doc["joints"]["pan"] = {
            "type": "prismatic",
            "parent": "base",
            "child": "carriage",
            "dofs": {"travel": {"min_deg": -45, "max_deg": 45}},
        }
        assert_rejects(doc, "joints.pan.dofs")

    def test_mixed_unit_keys_in_one_dof_rejected(self):
        doc = document(clips={}, outputs=[])
        doc["joints"]["pan"]["dofs"]["rotation"] = {
            "min_deg": -45, "max_m": 0.1,
        }
        assert_rejects(doc, "joints.pan.dofs.rotation")

    def test_dof_missing_limit(self):
        doc = document(clips={}, outputs=[])
        del doc["joints"]["pan"]["dofs"]["rotation"]["max_deg"]
        assert_rejects(doc, "rotation.max_deg")

    def test_dof_descending_range(self):
        doc = document(clips={}, outputs=[])
        doc["joints"]["pan"]["dofs"]["rotation"] = {
            "min_deg": 45, "max_deg": -45,
        }
        assert_rejects(doc, "rotation.min_deg")

    def test_dof_neutral_outside_range(self):
        doc = document(clips={}, outputs=[])
        doc["joints"]["pan"]["dofs"]["rotation"]["neutral_deg"] = 90.0
        assert_rejects(doc, "rotation.neutral_deg")

    def test_dof_bad_axis(self):
        doc = document(clips={}, outputs=[])
        doc["joints"]["pan"]["dofs"]["rotation"]["axis"] = [0, 1]
        assert_rejects(doc, "rotation.axis")

    def test_dof_unknown_field(self):
        doc = document(clips={}, outputs=[])
        doc["joints"]["pan"]["dofs"]["rotation"]["stiffness"] = 1.0
        assert_rejects(doc, "rotation.stiffness")

    def test_parameter_default_outside_unit_range(self):
        doc = document(clips={}, outputs=[])
        doc["parameters"]["glow"]["default"] = 1.5
        assert_rejects(doc, "parameters.glow.default")

    def test_parameter_name_with_dot(self):
        doc = document(clips={}, outputs=[])
        doc["parameters"]["a.b"] = {"default": 0.0}
        assert_rejects(doc, "parameters.a.b")

    def test_clip_missing_duration(self):
        doc = document()
        del doc["clips"]["sweep"]["duration_s"]
        assert_rejects(doc, "sweep.duration_s")

    def test_keyframe_past_clip_end(self):
        doc = document()
        doc["clips"]["sweep"]["duration_s"] = 0.5
        assert_rejects(doc, "sweep.tracks[1].time")

    def test_non_increasing_entry_times(self):
        doc = document()
        doc["clips"]["sweep"]["tracks"][1]["time"] = 0.0
        assert_rejects(doc, "sweep.tracks[1].time")

    def test_negative_keyframe_time(self):
        doc = document()
        doc["clips"]["sweep"]["tracks"][0]["time"] = -0.1
        assert_rejects(doc, "sweep.tracks[0].time")

    def test_tracks_must_be_a_list(self):
        doc = document()
        doc["clips"]["sweep"]["tracks"] = {"easing": "sine_in_out"}
        assert_rejects(doc, "sweep.tracks")

    def test_bad_interpolation_value(self):
        doc = document()
        doc["clips"]["sweep"]["tracks"][0]["interpolation"] = "bezier"
        assert_rejects(doc, "tracks[0].interpolation")

    def test_undeclared_track_target(self):
        doc = document()
        doc["clips"]["sweep"]["tracks"][0]["values"]["tail.rotation"] = 0.0
        assert_rejects(doc, "values.tail.rotation")

    def test_track_targeting_fastened_joint(self):
        doc = document(outputs=[])
        doc["joints"]["lock"] = {
            "type": "fastened", "parent": "base", "child": "carriage",
        }
        doc["clips"]["sweep"]["tracks"][0]["values"]["lock.rotation"] = 0.0
        assert_rejects(doc, "values.lock.rotation")

    def test_rotation_value_outside_dof_range(self):
        doc = document()
        doc["clips"]["sweep"]["tracks"][1]["values"]["pan.rotation"] = 90.0
        assert_rejects(doc, "values.pan.rotation")

    def test_translation_value_outside_dof_range(self):
        doc = document(outputs=[])
        doc["joints"]["lift"] = {
            "type": "prismatic",
            "parent": "base",
            "child": "carriage",
            "dofs": {"travel": {"min_m": 0.0, "max_m": 0.1}},
        }
        doc["clips"]["sweep"]["tracks"][0]["values"]["lift.travel"] = 0.5
        assert_rejects(doc, "values.lift.travel")

    def test_parameter_value_outside_unit_range(self):
        doc = document()
        doc["clips"]["sweep"]["tracks"][0]["values"]["glow"] = 2.0
        assert_rejects(doc, "values.glow")

    def test_outputs_must_be_a_list(self):
        assert_rejects(document(outputs={}), "outputs")

    @pytest.mark.parametrize("field", ["target", "channel"])
    def test_output_missing_required_field(self, field):
        doc = document()
        del doc["outputs"][0][field]
        assert_rejects(doc, f"outputs[0].{field}")

    def test_output_undeclared_target(self):
        doc = document()
        doc["outputs"][0]["target"] = "tail.rotation"
        assert_rejects(doc, "outputs[0].target")

    def test_output_wrong_range_key_for_dof(self):
        doc = document()
        del doc["outputs"][0]["range_deg"]
        doc["outputs"][0]["range"] = [0.0, 1.0]
        assert_rejects(doc, "outputs[0].range")

    def test_output_wrong_range_key_for_parameter(self):
        doc = document()
        del doc["outputs"][1]["range"]
        doc["outputs"][1]["range_deg"] = [-45, 45]
        assert_rejects(doc, "outputs[1].range_deg")

    def test_output_translation_target_requires_range_m(self):
        doc = document(clips={})
        doc["joints"]["lift"] = {
            "type": "prismatic",
            "parent": "base",
            "child": "carriage",
            "dofs": {"travel": {"min_m": 0.0, "max_m": 0.1}},
        }
        doc["outputs"] = [
            {"target": "lift.travel", "channel": 0, "range_deg": [0, 45]},
        ]
        assert_rejects(doc, "outputs[0]")

    def test_output_duplicate_channel(self):
        doc = document()
        doc["outputs"][1]["channel"] = 0
        assert_rejects(doc, "outputs[1].channel")

    def test_output_negative_channel(self):
        doc = document()
        doc["outputs"][0]["channel"] = -1
        assert_rejects(doc, "outputs[0].channel")

    def test_output_zero_span_range(self):
        doc = document()
        doc["outputs"][0]["range_deg"] = [10, 10]
        assert_rejects(doc, "outputs[0].range_deg")


class TestExamplesEndToEnd:
    def test_example_files_exist(self):
        names = {path.name for path in EXAMPLE_PATHS}
        assert {"six_axis_arm.character.anima",
                "rc_car.character.anima",
                "walle_style.character.anima"} <= names

    @pytest.mark.parametrize(
        "example_path", EXAMPLE_PATHS, ids=lambda p: p.name)
    def test_every_example_streams_to_the_simulator(self, example_path):
        """Load each example, evaluate every clip across its duration,
        project channels, and stream FRM lines into the simulator."""
        rig = load_character_file(example_path)
        assert rig.clips and rig.outputs
        device = SimulatedDevice(channel_count=16)
        for mapping in rig.outputs:
            line = (
                f"CFG,{mapping.channel},servo,"
                f"pin={9 + mapping.channel},min_us=600,max_us=2400"
            )
            assert device.receive_line(line) == "OK"
            assert device.receive_line(f"EN,{mapping.channel},1") == "OK"
        for clip_name, rig_clip in rig.clips.items():
            duration = rig_clip.clip.duration_seconds
            for frame_index in range(5):
                time_seconds = duration * frame_index / 4
                pose = evaluate_pose(rig, clip_name, time_seconds)
                targets = project_channels(rig, pose)
                assert set(targets) == {m.channel for m in rig.outputs}
                device.tick(frame_index * 33)
                reply = device.receive_line(encode_frm(0, targets))
                assert isinstance(parse_reply(reply), Ok)

    def test_six_axis_arm_is_six_revolute_dof(self):
        rig = load_character_file(
            EXAMPLES_DIR / "six_axis_arm.character.anima")
        assert len(rig.joints) == 6
        assert all(
            joint.joint_type is JointType.REVOLUTE
            for joint in rig.joints.values()
        )
        assert len(rig.dof_paths()) == 6
        assert len(rig.outputs) == 6

    def test_six_axis_arm_neutral_and_inverted_channel(self):
        rig = load_character_file(
            EXAMPLES_DIR / "six_axis_arm.character.anima")
        pose = evaluate_pose(rig, "pick", 0.0)
        # wrist_yaw is unanimated: neutral 0 deg over [-170, 170] → 0.5.
        channels = project_channels(rig, pose)
        assert channels[5] == pytest.approx(0.5, abs=1e-6)
        # shoulder_pitch channel is descending [90, -90]: 0 deg → 0.5,
        # and +35 deg (at t=1.0) lands below 0.5.
        assert channels[1] == pytest.approx(0.5, abs=1e-6)
        mid = project_channels(rig, evaluate_pose(rig, "pick", 1.0))
        assert mid[1] == pytest.approx((90 - 35) / 180, abs=1e-3)

    def test_rc_car_parameter_channel(self):
        rig = load_character_file(EXAMPLES_DIR / "rc_car.character.anima")
        assert set(rig.parameters) == {"throttle"}
        pose = evaluate_pose(rig, "launch_and_swerve", 0.5)
        channels = project_channels(rig, pose)
        assert channels[1] == pytest.approx(0.8)  # throttle keyframe

    def test_walle_style_translation_units_project(self):
        rig = load_character_file(
            EXAMPLES_DIR / "walle_style.character.anima")
        assert rig.joints["neck_extend"].joint_type is JointType.PRISMATIC
        pose = evaluate_pose(rig, "curious_look", 0.8)
        assert pose.dof_values["neck_extend.extension"] == pytest.approx(0.1)
        channels = project_channels(rig, pose)
        # 0.1 m over the [0.0, 0.12] m output range.
        assert channels[1] == pytest.approx(0.1 / 0.12, abs=1e-6)
        assert channels[2] == pytest.approx(1.0)  # eye lamp parameter
