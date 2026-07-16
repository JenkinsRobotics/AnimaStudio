"""`.character.anima` loader: accepted subset, rejections, end-to-end."""

import copy
import math
from pathlib import Path

import pytest
import yaml

from animacore.loader import (
    CharacterFormatError,
    load_character_file,
    parse_character,
)
from animacore.rig import (
    DofKind,
    JointType,
    LimitViolationError,
    RelationKind,
    RotationAxis,
    evaluate_pose,
    project_channels,
)
from animacore.sim import SimulatedDevice
from animacore.tracks import Interpolation
from animacore.wire import Ok, encode_frm, parse_reply

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
                "rotation": {
                    "limits": {"min_deg": -45, "max_deg": 45},
                    "neutral_deg": 0,
                },
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

    def test_part_model_file_reference_parses(self):
        # A multi-file assembly: each part points at its own mesh FILE
        # (opaque, relative to assets/). One part carries model without
        # model_node (single-mesh STL), another carries both (USD node).
        doc = document(clips={}, joints={}, outputs=[])
        doc["parts"] = {
            "base": {"model": "assets/base.stl"},
            "head": {
                "parent": "base",
                "model": "assets/robot.usdz",
                "model_node": "robot/head",
            },
        }
        rig = parse(doc)
        assert rig.parts["base"].model == "assets/base.stl"
        assert rig.parts["base"].model_node is None
        assert rig.parts["head"].model == "assets/robot.usdz"
        assert rig.parts["head"].model_node == "robot/head"

    def test_part_model_defaults_to_empty_when_absent(self):
        rig = parse(document())
        assert rig.parts["base"].model == ""

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
                "travel": {
                    "limits": {"min_m": 0.0, "max_m": 0.2},
                    "neutral_m": 0.05,
                },
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
             {"rotation": {"limits": {"min_deg": -45, "max_deg": 45}}}),
            ("prismatic",
             {"travel": {"limits": {"min_m": 0.0, "max_m": 0.1}}}),
            ("cylindrical",
             {"rotation": {"limits": {"min_deg": -90, "max_deg": 90}},
              "travel": {"limits": {"min_m": 0.0, "max_m": 0.1}}}),
            ("pin_slot",
             {"rotation": {"limits": {"min_deg": -90, "max_deg": 90}},
              "travel": {"limits": {"min_m": 0.0, "max_m": 0.1}}}),
            ("planar",
             {"slide_x": {"limits": {"min_m": -0.1, "max_m": 0.1}},
              "slide_y": {"limits": {"min_m": -0.1, "max_m": 0.1}},
              "rotation": {"limits": {"min_deg": -180, "max_deg": 180}}}),
            ("ball",
             {"rotation_x": {"limits": {"min_deg": -30, "max_deg": 30}},
              "rotation_y": {"limits": {"min_deg": -30, "max_deg": 30}},
              "rotation_z": {"limits": {"min_deg": -30, "max_deg": 30}}}),
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
            "swing": {"limits": {"min_deg": -45, "max_deg": 45}},
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

    def test_part_absolute_model_path_rejected(self):
        doc = document(clips={}, joints={}, outputs=[])
        doc["parts"]["base"] = {"model": "/etc/base.stl"}
        assert_rejects(doc, "parts.base.model")

    def test_part_model_path_traversal_rejected(self):
        doc = document(clips={}, joints={}, outputs=[])
        doc["parts"]["base"] = {"model": "../../secret.stl"}
        assert_rejects(doc, "parts.base.model")

    def test_part_model_path_empty_segment_rejected(self):
        doc = document(clips={}, joints={}, outputs=[])
        doc["parts"]["base"] = {"model": "assets//base.stl"}
        assert_rejects(doc, "parts.base.model")

    def test_revolute_with_extra_dof_rejected(self):
        doc = document(clips={}, outputs=[])
        doc["joints"]["pan"]["dofs"]["extra"] = {
            "limits": {"min_m": 0.0, "max_m": 0.1},
        }
        assert_rejects(doc, "joints.pan.dofs")

    def test_fastened_with_dofs_rejected(self):
        doc = document(clips={}, outputs=[])
        doc["joints"]["pan"] = {
            "type": "fastened",
            "parent": "base",
            "child": "carriage",
            "dofs": {
                "rotation": {"limits": {"min_deg": -45, "max_deg": 45}},
            },
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
            "dofs": {
                "travel": {"limits": {"min_deg": -45, "max_deg": 45}},
            },
        }
        assert_rejects(doc, "joints.pan.dofs")

    def test_mixed_unit_keys_in_one_dof_rejected(self):
        doc = document(clips={}, outputs=[])
        doc["joints"]["pan"]["dofs"]["rotation"] = {
            "limits": {"min_deg": -45, "max_m": 0.1},
        }
        assert_rejects(doc, "joints.pan.dofs.rotation")

    def test_flat_pre_limits_block_keys_rejected(self):
        # The pre-K2 flat spelling (min_deg beside neutral_deg) is not
        # silently accepted; limits live in their own block now.
        doc = document(clips={}, outputs=[])
        doc["joints"]["pan"]["dofs"]["rotation"] = {
            "min_deg": -45, "max_deg": 45, "neutral_deg": 0,
        }
        assert_rejects(doc, "rotation.max_deg")  # first flat key rejected

    def test_dof_missing_limit(self):
        doc = document(clips={}, outputs=[])
        del doc["joints"]["pan"]["dofs"]["rotation"]["limits"]["max_deg"]
        assert_rejects(doc, "rotation.limits.max_deg")

    def test_dof_descending_range(self):
        doc = document(clips={}, outputs=[])
        doc["joints"]["pan"]["dofs"]["rotation"] = {
            "limits": {"min_deg": 45, "max_deg": -45},
        }
        assert_rejects(doc, "rotation.limits.min_deg")

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
            "dofs": {"travel": {"limits": {"min_m": 0.0, "max_m": 0.1}}},
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
            "dofs": {"travel": {"limits": {"min_m": 0.0, "max_m": 0.1}}},
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


class TestOptionalLimitsLoading:
    def wheel_document(self) -> dict:
        doc = document(clips={}, outputs=[])
        doc["joints"]["spinner"] = {
            "type": "revolute",
            "parent": "base",
            "child": "carriage",
            "dofs": {"spin": {"neutral_deg": 0}},
        }
        return doc

    def test_unlimited_dof_loads(self):
        rig = parse(self.wheel_document())
        dof = rig.joints["spinner"].dofs[0]
        assert not dof.has_limits
        assert dof.min_radians is None and dof.max_radians is None
        assert dof.neutral_radians == 0.0

    def test_unlimited_dof_keyframes_evaluate_unclamped(self):
        doc = self.wheel_document()
        doc["clips"] = {
            "spin_up": {
                "duration_s": 1.0,
                "tracks": [
                    {"time": 0.0, "values": {"spinner.spin": 0.0}},
                    {"time": 1.0, "values": {"spinner.spin": 1080.0}},
                ],
            },
        }
        rig = parse(doc)
        pose = evaluate_pose(rig, "spin_up", 1.0)
        assert pose.dof_values["spinner.spin"] == pytest.approx(
            math.radians(1080))  # three full turns, no clamp
        assert pose.limit_violations == ()

    def test_unlimited_translation_dof_loads(self):
        doc = document(clips={}, outputs=[])
        doc["joints"]["feed"] = {
            "type": "prismatic",
            "parent": "base",
            "child": "carriage",
            "dofs": {"travel": {"neutral_m": 0.0}},
        }
        dof = parse(doc).joints["feed"].dofs[0]
        assert dof.kind is DofKind.TRANSLATION and not dof.has_limits

    def test_unlimited_dof_without_neutral_rejected(self):
        # No limits block and no neutral key = no unit family declared.
        doc = self.wheel_document()
        doc["joints"]["spinner"]["dofs"]["spin"] = {"axis": [0, 0, 1]}
        assert_rejects(doc, "spinner.dofs.spin")

    def test_output_mapping_on_unlimited_dof_rejected(self):
        doc = self.wheel_document()
        doc["outputs"] = [
            {"target": "spinner.spin", "channel": 0, "range_deg": [-45, 45]},
        ]
        assert_rejects(doc, "outputs[0].target")


class TestMateControlsLoading:
    def test_offset_block_round_trips(self):
        doc = document(clips={}, outputs=[])
        doc["joints"]["pan"]["offset"] = {
            "enabled": True,
            "translation_m": [0.01, 0.0, -0.002],
            "rotate_about": "z",
            "angle_deg": 15.0,
        }
        offset = parse(doc).joints["pan"].controls.offset
        assert offset.enabled is True
        assert offset.translation_m == (0.01, 0.0, -0.002)
        assert offset.rotation_axis is RotationAxis.Z
        assert offset.rotation_radians == pytest.approx(math.radians(15.0))

    def test_absent_controls_is_none(self):
        assert parse(document()).joints["pan"].controls is None

    def test_id_round_trips_verbatim(self):
        doc = document(clips={}, outputs=[])
        doc["joints"]["pan"]["id"] = "Revolute 7"
        assert parse(doc).joints["pan"].id == "Revolute 7"

    def test_absent_id_is_empty_string(self):
        assert parse(document()).joints["pan"].id == ""

    def test_connectors_round_trip(self):
        doc = document(clips={}, outputs=[])
        doc["joints"]["pan"]["connectors"] = {
            "a": {
                "part": "base",
                "origin_m": [0.0, 0.0, 0.05],
                "primary_axis": [0, 0, 1],
                "secondary_axis": [1, 0, 0],
                "feature": "base/top",
            },
            "b": {"part": "carriage"},
        }
        controls = parse(doc).joints["pan"].controls
        assert controls.connector_a.part == "base"
        assert controls.connector_a.origin_m == (0.0, 0.0, 0.05)
        assert controls.connector_a.feature == "base/top"
        assert controls.connector_b.part == "carriage"

    def test_flip_and_secondary_and_simulation_round_trip(self):
        doc = document(clips={}, outputs=[])
        doc["joints"]["pan"]["flip_primary_axis"] = True
        doc["joints"]["pan"]["secondary_axis_rotation_deg"] = 270
        doc["joints"]["pan"]["simulation_connection"] = False
        controls = parse(doc).joints["pan"].controls
        assert controls.flip_primary_axis is True
        assert controls.secondary_axis_rotation_deg == 270
        assert controls.simulation_connection is False

    def test_simulation_connection_defaults_true_when_controls_present(self):
        doc = document(clips={}, outputs=[])
        doc["joints"]["pan"]["flip_primary_axis"] = True
        assert parse(doc).joints["pan"].controls.simulation_connection is True

    def test_offset_does_not_change_runtime_output(self):
        # The headless runtime computes DOF values and channel
        # projections, not spatial part transforms; the offset is a
        # round-trip carry Studio consumes spatially.
        doc = document()
        doc["joints"]["pan"]["offset"] = {"enabled": True, "angle_deg": 15.0}
        with_offset = parse(doc)
        plain = parse(document())
        assert evaluate_pose(with_offset, "sweep", 0.5) == evaluate_pose(
            plain, "sweep", 0.5)

    def test_offset_bad_translation_shape_rejected(self):
        doc = document(clips={}, outputs=[])
        doc["joints"]["pan"]["offset"] = {"translation_m": [0.01, 0.0]}
        assert_rejects(doc, "offset.translation_m")

    def test_offset_unknown_field_rejected(self):
        doc = document(clips={}, outputs=[])
        doc["joints"]["pan"]["offset"] = {"scale": 2.0}
        assert_rejects(doc, "offset.scale")

    def test_offset_bad_rotate_about_rejected(self):
        doc = document(clips={}, outputs=[])
        doc["joints"]["pan"]["offset"] = {"rotate_about": "w"}
        assert_rejects(doc, "offset.rotate_about")

    def test_secondary_axis_rotation_bad_step_rejected(self):
        doc = document(clips={}, outputs=[])
        doc["joints"]["pan"]["secondary_axis_rotation_deg"] = 45
        assert_rejects(doc, "secondary_axis_rotation_deg")

    def test_connector_missing_part_rejected(self):
        doc = document(clips={}, outputs=[])
        doc["joints"]["pan"]["connectors"] = {"a": {"origin_m": [0, 0, 0]}}
        assert_rejects(doc, "connectors.a.part")

    def test_connector_undeclared_part_rejected(self):
        doc = document(clips={}, outputs=[])
        doc["joints"]["pan"]["connectors"] = {"a": {"part": "ghost"}}
        assert_rejects(doc, "connectors.a.part")

    def test_connector_parallel_axes_rejected(self):
        doc = document(clips={}, outputs=[])
        doc["joints"]["pan"]["connectors"] = {
            "a": {
                "part": "base",
                "primary_axis": [0, 0, 1],
                "secondary_axis": [0, 0, 2],
            }
        }
        assert_rejects(doc, "connectors.a")

    def test_connector_unknown_field_rejected(self):
        doc = document(clips={}, outputs=[])
        doc["joints"]["pan"]["connectors"] = {
            "a": {"part": "base", "scale": 2.0}
        }
        assert_rejects(doc, "connectors.a.scale")

    def test_connectors_unknown_side_rejected(self):
        doc = document(clips={}, outputs=[])
        doc["joints"]["pan"]["connectors"] = {"c": {"part": "base"}}
        assert_rejects(doc, "connectors.c")


def rack_document(**relation_overrides) -> dict:
    """BASE_DOCUMENT plus a prismatic rack driven by pan.rotation."""
    doc = document(clips={}, outputs=[])
    doc["parts"]["rack_body"] = {"parent": "base"}
    doc["joints"]["rack"] = {
        "type": "prismatic",
        "parent": "base",
        "child": "rack_body",
        "dofs": {
            "travel": {
                "limits": {"min_m": -0.02, "max_m": 0.02},
                "neutral_m": 0.0,
            },
        },
    }
    relation = {
        "kind": "rack_pinion",
        "driver": "pan.rotation",
        "driven": "rack.travel",
        "ratio": 0.02,
    }
    relation.update(relation_overrides)
    doc["relations"] = [relation]
    return doc


class TestRelationsLoading:
    def test_relation_parses(self):
        rig = parse(rack_document())
        relation = rig.relations[0]
        assert relation.kind is RelationKind.RACK_PINION
        assert relation.driver == "pan.rotation"
        assert relation.driven == "rack.travel"
        assert relation.ratio == 0.02
        assert relation.offset == 0.0
        assert relation.display == {}

    def test_relation_drives_evaluation(self):
        doc = rack_document()
        doc["clips"] = {
            "steer": {
                "duration_s": 1.0,
                "tracks": [
                    {"time": 0.0, "values": {"pan.rotation": 0.0}},
                    {"time": 1.0, "values": {"pan.rotation": 30.0}},
                ],
            },
        }
        pose = evaluate_pose(parse(doc), "steer", 1.0)
        assert pose.dof_values["rack.travel"] == pytest.approx(
            0.02 * math.radians(30))
        assert pose.limit_violations == ()

    def test_translation_offset_key_stays_meters(self):
        rig = parse(rack_document(offset_m=0.005))
        assert rig.relations[0].offset == 0.005

    def test_rotation_offset_key_converts_to_radians(self):
        doc = document(clips={}, outputs=[])
        doc["parts"]["gear_body"] = {"parent": "base"}
        doc["joints"]["gear"] = {
            "type": "revolute",
            "parent": "base",
            "child": "gear_body",
            "dofs": {
                "rotation": {
                    "limits": {"min_deg": -180, "max_deg": 180},
                },
            },
        }
        doc["relations"] = [{
            "kind": "gear",
            "driver": "pan.rotation",
            "driven": "gear.rotation",
            "ratio": -0.5,
            "offset_deg": 10.0,
            "display": {"driver_teeth": 20, "driven_teeth": 40},
        }]
        relation = parse(doc).relations[0]
        assert relation.offset == pytest.approx(math.radians(10.0))
        assert relation.display == {"driver_teeth": 20.0,
                                    "driven_teeth": 40.0}

    def test_relations_must_be_a_list(self):
        doc = document(clips={}, outputs=[])
        doc["relations"] = {"kind": "gear"}
        assert_rejects(doc, "relations")

    @pytest.mark.parametrize(
        "field", ["kind", "driver", "driven", "ratio"])
    def test_relation_missing_required_field(self, field):
        doc = rack_document()
        del doc["relations"][0][field]
        assert_rejects(doc, f"relations[0].{field}")

    def test_relation_unknown_kind(self):
        assert_rejects(rack_document(kind="belt"), "relations[0].kind")

    def test_relation_undeclared_driver(self):
        assert_rejects(
            rack_document(driver="ghost.rotation"), "relations[0].driver")

    def test_relation_wrong_dof_kind_pairing(self):
        # rack_pinion requires a translation driven DOF; pan.rotation
        # driving pan.rotation-kind (rotation) target is rejected.
        doc = rack_document(driven="pan.rotation")
        assert_rejects(doc, "relations[0].driven")

    def test_relation_wrong_offset_unit_key(self):
        # The offset key must match the driven DOF's unit family.
        assert_rejects(
            rack_document(offset_deg=5.0), "relations[0].offset_deg")

    def test_relation_zero_ratio_rejected(self):
        assert_rejects(rack_document(ratio=0.0), "relations[0].ratio")

    def test_relation_unknown_display_field(self):
        doc = rack_document(display={"lead_mm_per_rev": 2.0})
        assert_rejects(doc, "relations[0].display.lead_mm_per_rev")

    def test_relation_non_positive_display_value(self):
        doc = rack_document(display={"pinion_diameter_mm": 0})
        assert_rejects(doc, "relations[0].display.pinion_diameter_mm")

    def test_animated_driven_dof_rejected(self):
        doc = rack_document()
        doc["clips"] = {
            "push": {
                "duration_s": 1.0,
                "tracks": [
                    {"time": 0.0, "values": {"rack.travel": 0.0}},
                    {"time": 1.0, "values": {"rack.travel": 0.01}},
                ],
            },
        }
        with pytest.raises(CharacterFormatError, match="source of truth"):
            parse(doc)

    def test_relation_cycle_rejected(self):
        doc = document(clips={}, outputs=[])
        doc["parts"]["gear_body"] = {"parent": "base"}
        doc["joints"]["gear"] = {
            "type": "revolute",
            "parent": "base",
            "child": "gear_body",
            "dofs": {
                "rotation": {"limits": {"min_deg": -180, "max_deg": 180}},
            },
        }
        doc["relations"] = [
            {"kind": "gear", "driver": "pan.rotation",
             "driven": "gear.rotation", "ratio": 0.5},
            {"kind": "gear", "driver": "gear.rotation",
             "driven": "pan.rotation", "ratio": 2.0},
        ]
        with pytest.raises(CharacterFormatError, match="cycle"):
            parse(doc)

    def test_double_driven_dof_rejected(self):
        doc = rack_document()
        doc["relations"].append({
            "kind": "screw",
            "driver": "pan.rotation",
            "driven": "rack.travel",
            "ratio": 0.001,
        })
        with pytest.raises(CharacterFormatError, match="two relations"):
            parse(doc)

    def test_driven_limit_violation_reported_not_clamped(self):
        # pan at 45 deg drives the rack to 0.0157 m, past 0.005 m —
        # the value is reported, never clamped, and projecting a
        # mapped violated DOF raises so hardware refuses to arm.
        doc = rack_document()
        doc["joints"]["rack"]["dofs"]["travel"]["limits"] = {
            "min_m": -0.005, "max_m": 0.005,
        }
        doc["clips"] = {
            "steer": {
                "duration_s": 1.0,
                "tracks": [
                    {"time": 0.0, "values": {"pan.rotation": 0.0}},
                    {"time": 1.0, "values": {"pan.rotation": 45.0}},
                ],
            },
        }
        doc["outputs"] = [
            {"target": "rack.travel", "channel": 0,
             "range_m": [-0.005, 0.005]},
        ]
        rig = parse(doc)
        pose = evaluate_pose(rig, "steer", 1.0)
        expected = 0.02 * math.radians(45)
        assert pose.dof_values["rack.travel"] == pytest.approx(expected)
        violation, = pose.limit_violations
        assert violation.dof_path == "rack.travel"
        assert violation.value == pytest.approx(expected)
        assert violation.max_value == 0.005
        with pytest.raises(LimitViolationError, match="rack.travel"):
            project_channels(rig, pose)
        # Back inside the limits, projection works again.
        safe = evaluate_pose(rig, "steer", 0.0)
        assert safe.limit_violations == ()
        assert project_channels(rig, safe)[0] == pytest.approx(0.5)


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

    def test_rc_car_relation_and_unlimited_wheel(self):
        rig = load_character_file(EXAMPLES_DIR / "rc_car.character.anima")
        relation, = rig.relations
        assert relation.kind is RelationKind.RACK_PINION
        steering_offset = rig.joints["steering"].controls.offset
        assert steering_offset.enabled is True
        assert steering_offset.rotation_radians == pytest.approx(
            math.radians(2.5)
        )
        assert not rig.joints["drive"].dofs[0].has_limits
        # Steering at -25 deg drives the rack through the relation.
        pose = evaluate_pose(rig, "launch_and_swerve", 1.0)
        expected_travel_meters = 0.02 * math.radians(-25.0)
        assert pose.dof_values["rack.travel"] == pytest.approx(
            expected_travel_meters)
        channels = project_channels(rig, pose)
        assert channels[2] == pytest.approx(
            (expected_travel_meters + 0.011) / 0.022)
        # The unlimited wheel passes three full turns without clamping.
        end = evaluate_pose(rig, "launch_and_swerve", 2.0)
        assert end.dof_values["drive.spin"] == pytest.approx(
            math.radians(1080))
        assert end.limit_violations == ()

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


def _geo_doc(joint_entry: dict, joint_name: str = "geo") -> dict:
    """A minimal 2.0 document carrying one geometry-constraint joint."""
    return {
        "anima_version": "2.0",
        "type": "character",
        "identity": {"name": "geo"},
        "parts": {"base": None, "carriage": {"parent": "base"}},
        "joints": {joint_name: joint_entry},
    }


_WIDTH_JOINT = {
    "type": "width",
    "parent": "base",
    "child": "carriage",
    "connectors": {"a": {"part": "base"}, "b": {"part": "carriage"}},
}

_TANGENT_JOINT = {
    "type": "tangent",
    "parent": "base",
    "child": "carriage",
    "tangent": {
        "selection_a": "base/face",
        "selection_b": "carriage/face",
        "propagation": True,
    },
}


class TestWidthMateLoading:
    def test_width_loads_with_connectors_and_no_offset(self):
        joint = parse(_geo_doc(copy.deepcopy(_WIDTH_JOINT))).joints["geo"]
        assert joint.joint_type is JointType.WIDTH
        assert joint.dofs == ()
        assert joint.tangent is None
        assert joint.controls.connector_a.part == "base"
        assert joint.controls.connector_b.part == "carriage"
        assert joint.controls.offset.enabled is False

    def test_width_id_round_trips(self):
        entry = copy.deepcopy(_WIDTH_JOINT)
        entry["id"] = "Width 5"
        assert parse(_geo_doc(entry)).joints["geo"].id == "Width 5"

    def test_width_rejects_offset(self):
        entry = copy.deepcopy(_WIDTH_JOINT)
        entry["offset"] = {"enabled": True, "translation_m": [0.0, 0.0, 0.01]}
        assert_rejects(_geo_doc(entry), "offset")

    def test_width_rejects_dofs(self):
        entry = copy.deepcopy(_WIDTH_JOINT)
        entry["dofs"] = {"rotation": {"neutral_deg": 0}}
        assert_rejects(_geo_doc(entry), "dofs")

    def test_width_rejects_secondary_axis_rotation(self):
        entry = copy.deepcopy(_WIDTH_JOINT)
        entry["secondary_axis_rotation_deg"] = 90
        assert_rejects(_geo_doc(entry), "secondary_axis_rotation_deg")

    def test_width_allows_flip_and_simulation(self):
        entry = copy.deepcopy(_WIDTH_JOINT)
        entry["flip_primary_axis"] = True
        entry["simulation_connection"] = False
        controls = parse(_geo_doc(entry)).joints["geo"].controls
        assert controls.flip_primary_axis is True
        assert controls.simulation_connection is False


class TestTangentMateLoading:
    def test_tangent_loads_with_tangent_block(self):
        joint = parse(_geo_doc(copy.deepcopy(_TANGENT_JOINT))).joints["geo"]
        assert joint.joint_type is JointType.TANGENT
        assert joint.dofs == ()
        assert joint.controls is None
        assert joint.tangent.selection_a == "base/face"
        assert joint.tangent.selection_b == "carriage/face"
        assert joint.tangent.propagation is True

    def test_tangent_propagation_defaults_true(self):
        entry = copy.deepcopy(_TANGENT_JOINT)
        del entry["tangent"]["propagation"]
        assert parse(_geo_doc(entry)).joints["geo"].tangent.propagation is True

    def test_tangent_rejects_connectors(self):
        entry = copy.deepcopy(_TANGENT_JOINT)
        entry["connectors"] = {"a": {"part": "base"}, "b": {"part": "carriage"}}
        assert_rejects(_geo_doc(entry), "connectors")

    def test_tangent_rejects_offset(self):
        entry = copy.deepcopy(_TANGENT_JOINT)
        entry["offset"] = {"enabled": True}
        assert_rejects(_geo_doc(entry), "offset")

    def test_tangent_rejects_dofs(self):
        entry = copy.deepcopy(_TANGENT_JOINT)
        entry["dofs"] = {"rotation": {"neutral_deg": 0}}
        assert_rejects(_geo_doc(entry), "dofs")

    def test_tangent_requires_tangent_block(self):
        entry = copy.deepcopy(_TANGENT_JOINT)
        del entry["tangent"]
        assert_rejects(_geo_doc(entry), "tangent")

    def test_tangent_rejects_missing_selection(self):
        entry = copy.deepcopy(_TANGENT_JOINT)
        del entry["tangent"]["selection_b"]
        assert_rejects(_geo_doc(entry), "tangent.selection_b")


class TestGeometryConstraintExample:
    def test_demo_example_loads_and_drives_only_the_revolute(self):
        rig = load_character_file(
            EXAMPLES_DIR / "geometry_mates_demo.character.anima"
        )
        assert rig.joints["center_tab"].joint_type is JointType.WIDTH
        assert rig.joints["cam_contact"].joint_type is JointType.TANGENT
        assert rig.joints["cam_contact"].tangent.selection_a == (
            "cam/lobe_surface"
        )
        # The driven revolute still evaluates; linear -45 -> 45 over 2 s.
        pose = evaluate_pose(rig, "sweep", 1.0)
        assert pose.dof_values["aim.rotation"] == pytest.approx(0.0)


