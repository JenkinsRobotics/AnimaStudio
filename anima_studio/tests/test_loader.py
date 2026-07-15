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
from anima_studio.rig import evaluate_pose, project_channels
from anima_studio.sim import SimulatedDevice
from anima_studio.tracks import Interpolation
from anima_studio.wire import Ok, encode_frm, parse_reply

EXAMPLE_PATH = (
    Path(__file__).resolve().parents[2]
    / "examples"
    / "jp01_minimal.character.anima"
)

BASE_DOCUMENT = {
    "anima_version": "1.0",
    "type": "character",
    "identity": {"name": "testbot"},
    "blend_shapes": {"jawOpen": {"default": 0.0}},
    "bones": {
        "head_yaw": {"neutral_deg": 0.0, "range_deg": [-45, 45]},
    },
    "clips": {
        "turn": {
            "duration_s": 1.0,
            "tracks": {
                "bones": [
                    {"time": 0.0, "values": {"head_yaw": 0.0}},
                    {"time": 1.0, "values": {"head_yaw": 45.0}},
                ],
            },
        },
    },
    "physical": {
        "enabled": True,
        "bone_mapping": {
            "head_yaw": {"servo_channel": 0, "range": [-45, 45]},
        },
    },
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
        assert rig.joints["head_yaw"].max_radians == pytest.approx(
            math.radians(45))
        assert rig.blend_shapes["jawOpen"].neutral_value == 0.0
        assert rig.clips["turn"].clip.duration_seconds == 1.0
        assert rig.physical_enabled
        assert rig.servo_mappings[0].servo_channel == 0

    def test_sections_other_than_identity_are_optional(self):
        rig = parse({
            "anima_version": "1.0",
            "type": "character",
            "identity": {"name": "empty"},
        })
        assert rig.joints == {} and rig.clips == {}
        assert not rig.physical_enabled
        assert evaluate_pose(rig) is not None

    def test_bone_degrees_convert_to_radians(self):
        rig = parse(document())
        pose = evaluate_pose(rig, "turn", 1.0)
        assert pose.joint_angles_radians["head_yaw"] == pytest.approx(
            math.radians(45))

    def test_hold_interpolation_parses_and_holds(self):
        doc = document()
        doc["clips"]["turn"]["tracks"]["bones"] = [
            {"time": 0.0, "values": {"head_yaw": 30.0},
             "interpolation": "hold"},
            {"time": 1.0, "values": {"head_yaw": 0.0}},
        ]
        rig = parse(doc)
        track = rig.clips["turn"].clip.tracks["head_yaw"]
        assert track.keyframes[0].interpolation is Interpolation.HOLD
        pose = evaluate_pose(rig, "turn", 0.99)
        assert pose.joint_angles_radians["head_yaw"] == pytest.approx(
            math.radians(30))

    def test_sparse_entries_build_per_parameter_tracks(self):
        doc = document()
        doc["bones"]["head_pitch"] = {"range_deg": [-30, 30]}
        doc["clips"]["turn"]["tracks"]["bones"] = [
            {"time": 0.0, "values": {"head_yaw": 0.0, "head_pitch": 0.0}},
            {"time": 0.5, "values": {"head_pitch": -20.0}},
            {"time": 1.0, "values": {"head_yaw": 45.0}},
        ]
        rig = parse(doc)
        tracks = rig.clips["turn"].clip.tracks
        assert len(tracks["head_yaw"].keyframes) == 2
        assert len(tracks["head_pitch"].keyframes) == 2

    def test_loop_flag_parses(self):
        doc = document()
        doc["clips"]["turn"]["loop"] = True
        assert parse(doc).clips["turn"].loop


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

    def test_wrong_version(self):
        assert_rejects(document(anima_version="2.0"), "anima_version")

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

    def test_bone_missing_range(self):
        assert_rejects(
            document(bones={"j": {"neutral_deg": 0.0}}), "j.range_deg")

    def test_bone_descending_range(self):
        doc = document(clips={}, physical={"bone_mapping": {}})
        doc["bones"] = {"j": {"range_deg": [45, -45]}}
        assert_rejects(doc, "j.range_deg")

    def test_bone_neutral_outside_range(self):
        doc = document()
        doc["bones"]["head_yaw"]["neutral_deg"] = 90.0
        assert_rejects(doc, "head_yaw.neutral_deg")

    def test_bone_unknown_field(self):
        doc = document()
        doc["bones"]["head_yaw"]["stiffness"] = 1.0
        assert_rejects(doc, "head_yaw.stiffness")

    def test_blend_shape_default_outside_unit_range(self):
        doc = document()
        doc["blend_shapes"]["jawOpen"]["default"] = 1.5
        assert_rejects(doc, "jawOpen.default")

    def test_clip_missing_duration(self):
        doc = document()
        del doc["clips"]["turn"]["duration_s"]
        assert_rejects(doc, "turn.duration_s")

    def test_keyframe_past_clip_end(self):
        doc = document()
        doc["clips"]["turn"]["duration_s"] = 0.5
        assert_rejects(doc, "turn.tracks.bones[1].time")

    def test_non_increasing_entry_times(self):
        doc = document()
        doc["clips"]["turn"]["tracks"]["bones"][1]["time"] = 0.0
        assert_rejects(doc, "turn.tracks.bones[1].time")

    def test_negative_keyframe_time(self):
        doc = document()
        doc["clips"]["turn"]["tracks"]["bones"][0]["time"] = -0.1
        assert_rejects(doc, "turn.tracks.bones[0].time")

    def test_easing_rejected(self):
        doc = document()
        doc["clips"]["turn"]["tracks"]["easing"] = "sine_in_out"
        assert_rejects(doc, "turn.tracks.easing")

    def test_bad_interpolation_value(self):
        doc = document()
        doc["clips"]["turn"]["tracks"]["bones"][0]["interpolation"] = "bezier"
        assert_rejects(doc, "bones[0].interpolation")

    def test_undeclared_parameter_in_values(self):
        doc = document()
        doc["clips"]["turn"]["tracks"]["bones"][0]["values"]["tail"] = 0.0
        assert_rejects(doc, "values.tail")

    def test_bone_keyframe_value_outside_joint_range(self):
        doc = document()
        doc["clips"]["turn"]["tracks"]["bones"][1]["values"]["head_yaw"] = 90.0
        assert_rejects(doc, "values.head_yaw")

    def test_blend_shape_keyframe_value_outside_unit_range(self):
        doc = document()
        doc["clips"]["turn"]["tracks"]["blend_shapes"] = [
            {"time": 0.0, "values": {"jawOpen": 2.0}},
        ]
        assert_rejects(doc, "values.jawOpen")

    def test_unknown_track_group(self):
        doc = document()
        doc["clips"]["turn"]["tracks"]["leds"] = []
        assert_rejects(doc, "turn.tracks.leds")

    def test_blend_shape_mapping_rejected(self):
        doc = document()
        doc["physical"]["blend_shape_mapping"] = {
            "jawOpen": {"joint": "head_jaw", "range": [5, 40]},
        }
        assert_rejects(doc, "physical.blend_shape_mapping")

    def test_led_mapping_rejected(self):
        doc = document()
        doc["physical"]["led_mapping"] = {}
        assert_rejects(doc, "physical.led_mapping")

    def test_smoothing_rejected(self):
        doc = document()
        doc["physical"]["bone_mapping"]["head_yaw"]["smoothing"] = 0.05
        assert_rejects(doc, "head_yaw.smoothing")

    def test_mapping_missing_servo_channel(self):
        doc = document()
        del doc["physical"]["bone_mapping"]["head_yaw"]["servo_channel"]
        assert_rejects(doc, "head_yaw.servo_channel")

    def test_mapping_undeclared_bone(self):
        doc = document()
        doc["physical"]["bone_mapping"]["tail"] = {
            "servo_channel": 1, "range": [0, 10],
        }
        assert_rejects(doc, "bone_mapping.tail")

    def test_duplicate_servo_channel(self):
        doc = document()
        doc["bones"]["head_pitch"] = {"range_deg": [-30, 30]}
        doc["physical"]["bone_mapping"]["head_pitch"] = {
            "servo_channel": 0, "range": [-30, 30],
        }
        assert_rejects(doc, "servo_channel")

    def test_zero_span_mapping_range(self):
        doc = document()
        doc["physical"]["bone_mapping"]["head_yaw"]["range"] = [10, 10]
        assert_rejects(doc, "head_yaw.range")


class TestExampleEndToEnd:
    def test_example_file_loads(self):
        rig = load_character_file(EXAMPLE_PATH)
        assert rig.identity.name == "jp01_minimal"
        assert set(rig.joints) == {"head_yaw", "head_pitch", "head_roll"}
        assert set(rig.blend_shapes) == {"jawOpen"}
        assert set(rig.clips) == {"nod_and_talk"}
        assert len(rig.servo_mappings) == 3

    def test_clip_streams_to_simulated_servos(self):
        """Load the example character, evaluate its clip, project to
        channels, stream FRM lines into the simulator, assert servo
        values — including the unanimated joint resting at its
        projected neutral."""
        rig = load_character_file(EXAMPLE_PATH)
        device = SimulatedDevice(channel_count=3)
        for channel, pin in ((0, 9), (1, 10), (2, 11)):
            line = f"CFG,{channel},servo,pin={pin},min_us=600,max_us=2400"
            assert device.receive_line(line) == "OK"
            assert device.receive_line(f"EN,{channel},1") == "OK"

        for frame_index, time_seconds in enumerate((0.0, 0.3, 0.45, 0.8)):
            pose = evaluate_pose(rig, "nod_and_talk", time_seconds)
            targets = project_channels(rig, pose)
            device.tick(frame_index * 33)
            reply = device.receive_line(encode_frm(0, targets))
            assert isinstance(parse_reply(reply), Ok)

            # Yaw: ascending mapping [-45, 45] degrees.
            yaw_deg = math.degrees(pose.joint_angles_radians["head_yaw"])
            assert device.channel_value(0) == pytest.approx(
                (yaw_deg + 45) / 90, abs=1e-3)
            # Pitch: descending mapping [30, -30] degrees (inverted).
            pitch_deg = math.degrees(pose.joint_angles_radians["head_pitch"])
            assert device.channel_value(1) == pytest.approx(
                (30 - pitch_deg) / 60, abs=1e-3)
            # Roll is unanimated: neutral 5 deg over [-20, 20] → 0.625.
            assert device.channel_value(2) == pytest.approx(0.625, abs=1e-3)

        # Spot values: mid-hold pitch is -15 deg; the clip end is neutral.
        held = evaluate_pose(rig, "nod_and_talk", 0.45)
        assert held.joint_angles_radians["head_pitch"] == pytest.approx(
            math.radians(-15))
        # jawOpen: linear from (0.4, 1.0) to (0.8, 0.0), so 0.875 at 0.45.
        assert held.blend_shape_values["jawOpen"] == pytest.approx(0.875)
        end = evaluate_pose(rig, "nod_and_talk", 0.8)
        assert end.joint_angles_radians["head_pitch"] == pytest.approx(0.0)
        assert end.blend_shape_values["jawOpen"] == pytest.approx(0.0)
