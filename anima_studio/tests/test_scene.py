"""`.scene.anima`: schema, rig validation, executor semantics.

Covers execution v1 (clip/pose/wait/wait_for/set/if/loop/parallel/
event) and the v2 scripting constructs (condition trees, select,
call/subroutines, inputs, wait_until, background monitors).
"""

from pathlib import Path

import pytest
import yaml

from anima_studio.loader import parse_character
from anima_studio.outputs import ChannelConfig, SimulatorOutput
from anima_studio.rig import LimitViolationError
from anima_studio.scene import (
    ClipAction,
    SceneFormatError,
    SceneResult,
    SceneRunner,
    SceneRuntimeError,
    TimeoutPolicy,
    load_scene_file,
    parse_scene,
    validate_scene,
)
from anima_studio.sim import SimulatedDevice

EXAMPLES_DIR = Path(__file__).resolve().parents[2] / "examples"

# Channel 0 maps pan.rotation over [-45, 45] deg, so ch0 = (deg+45)/90;
# channel 1 maps the glow parameter 1:1.
CHARACTER_DOCUMENT = {
    "anima_version": "2.0",
    "type": "character",
    "identity": {"name": "testbot"},
    "parts": {"base": None, "head": {"parent": "base"}},
    "joints": {
        "pan": {
            "type": "revolute",
            "parent": "base",
            "child": "head",
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
                {"time": 0.0, "values": {"pan.rotation": -45.0, "glow": 0.0}},
                {"time": 1.0, "values": {"pan.rotation": 45.0, "glow": 1.0}},
            ],
        },
        "nod": {
            "duration_s": 1.0,
            "loop": True,
            "tracks": [
                {"time": 0.0, "values": {"pan.rotation": 0.0}},
                {"time": 0.5, "values": {"pan.rotation": 10.0}},
                {"time": 1.0, "values": {"pan.rotation": 0.0}},
            ],
        },
    },
    "outputs": [
        {"target": "pan.rotation", "channel": 0, "range_deg": [-45, 45]},
        {"target": "glow", "channel": 1, "range": [0.0, 1.0]},
    ],
}

# A gear relation doubles pan into jaw (limits -30..30 deg), and jaw is
# the mapped channel — so posing pan past 15 deg violates jaw's limits.
RELATION_DOCUMENT = {
    "anima_version": "2.0",
    "type": "character",
    "identity": {"name": "geared"},
    "parts": {"base": None, "head": {"parent": "base"}, "jaw_part": None},
    "joints": {
        "pan": {
            "type": "revolute",
            "parent": "base",
            "child": "head",
            "dofs": {
                "rotation": {
                    "limits": {"min_deg": -45, "max_deg": 45},
                    "neutral_deg": 0,
                },
            },
        },
        "jaw": {
            "type": "revolute",
            "parent": "head",
            "child": "jaw_part",
            "dofs": {
                "rotation": {
                    "limits": {"min_deg": -30, "max_deg": 30},
                    "neutral_deg": 0,
                },
            },
        },
    },
    "relations": [
        {
            "kind": "gear",
            "driver": "pan.rotation",
            "driven": "jaw.rotation",
            "ratio": 2.0,
        },
    ],
    "outputs": [
        {"target": "jaw.rotation", "channel": 0, "range_deg": [-30, 30]},
    ],
}

RIG = parse_character(yaml.safe_dump(CHARACTER_DOCUMENT))
RELATION_RIG = parse_character(yaml.safe_dump(RELATION_DOCUMENT))


def scene_document(sequence, variables=None, **overrides):
    document = {
        "anima_version": "2.0",
        "type": "scene",
        "identity": {"name": "test_scene"},
        "character": "testbot.character.anima",
        "sequence": sequence,
    }
    if variables is not None:
        document["variables"] = variables
    document.update(overrides)
    return document


def make_scene(sequence, variables=None, **overrides):
    return parse_scene(
        yaml.safe_dump(scene_document(sequence, variables, **overrides))
    )


class RecordingAdapter:
    """Captures frames verbatim — no device interpolation in the way."""

    def __init__(self):
        self.frames: list[tuple[dict[int, float], int]] = []
        self.stopped = False

    def open(self, channel_configs):
        pass

    def send_frame(self, targets, duration_ms):
        self.frames.append((dict(targets), duration_ms))

    def stop(self):
        self.stopped = True

    def close(self):
        pass


def make_runner(sequence, variables=None, rig=RIG, **kwargs):
    adapter = RecordingAdapter()
    runner = SceneRunner(
        make_scene(sequence, variables), rig, adapter, **kwargs
    )
    return runner, adapter


def channel(adapter: RecordingAdapter, index: int) -> float:
    return adapter.frames[-1][0][index]


def event_log(runner: SceneRunner) -> list[tuple[str, float]]:
    return [
        (event.name, event.time_s) for event in runner.emitted_events
    ]


def error_path(build) -> str:
    with pytest.raises(SceneFormatError) as info:
        build()
    return info.value.path


class TestHeader:
    def test_minimal_scene_parses(self):
        scene = make_scene([])
        assert scene.identity.name == "test_scene"
        assert scene.character == "testbot.character.anima"
        assert scene.variables == {}
        assert scene.sequence == ()

    def test_missing_anima_version(self):
        text = yaml.safe_dump(
            {k: v for k, v in scene_document([]).items()
             if k != "anima_version"}
        )
        assert error_path(lambda: parse_scene(text)) == "anima_version"

    def test_wrong_anima_version(self):
        path = error_path(lambda: make_scene([], anima_version="1.0"))
        assert path == "anima_version"

    def test_wrong_type(self):
        assert error_path(lambda: make_scene([], type="character")) == "type"

    @pytest.mark.parametrize(
        "section", ["type", "identity", "character", "sequence"]
    )
    def test_missing_required_section(self, section):
        text = yaml.safe_dump(
            {k: v for k, v in scene_document([]).items() if k != section}
        )
        assert error_path(lambda: parse_scene(text)) == section

    def test_meta_section_is_superseded(self):
        path = error_path(lambda: make_scene([], meta={"name": "x"}))
        assert path == "meta"

    def test_unknown_top_level_field(self):
        assert error_path(lambda: make_scene([], overrides={})) == "overrides"

    def test_identity_requires_name(self):
        path = error_path(lambda: make_scene([], identity={}))
        assert path == "identity.name"

    def test_identity_rejects_unknown_field(self):
        path = error_path(
            lambda: make_scene([], identity={"name": "x", "voice": "a"})
        )
        assert path == "identity.voice"

    def test_character_must_be_a_string(self):
        # The draft-spec mapping form (character: {file: ...}) is out.
        path = error_path(
            lambda: make_scene([], character={"file": "x.character.anima"})
        )
        assert path == "character"

    def test_character_must_not_be_empty(self):
        assert error_path(lambda: make_scene([], character="")) == "character"

    def test_document_must_be_a_mapping(self):
        assert error_path(lambda: parse_scene("[]")) == "<document>"

    def test_invalid_yaml(self):
        assert error_path(lambda: parse_scene(": [")) == "<document>"


class TestVariables:
    def test_scalar_variable_types_accepted(self):
        scene = make_scene(
            [], variables={"a": True, "b": 3, "c": 1.5, "d": "text"}
        )
        assert scene.variables == {"a": True, "b": 3, "c": 1.5, "d": "text"}

    def test_null_variable_rejected(self):
        path = error_path(lambda: make_scene([], variables={"a": None}))
        assert path == "variables.a"

    def test_list_variable_rejected(self):
        path = error_path(lambda: make_scene([], variables={"a": [1]}))
        assert path == "variables.a"


class TestActionParsing:
    @pytest.mark.parametrize(
        "deferred",
        ["speak", "expression", "blend_shapes", "lights", "ai_response",
         "goto", "label"],
    )
    def test_deferred_spec_actions_are_rejected(self, deferred):
        with pytest.raises(SceneFormatError) as info:
            make_scene([{deferred: "anything"}])
        assert info.value.path == f"sequence[0].{deferred}"
        assert "deferred" in info.value.message

    def test_unknown_action(self):
        path = error_path(lambda: make_scene([{"dance": "x"}]))
        assert path == "sequence[0].dance"

    def test_two_actions_in_one_entry(self):
        path = error_path(
            lambda: make_scene(
                [{"clip": "sweep", "wait_for": {"event": "x"}}]
            )
        )
        assert path == "sequence[0]"

    def test_clip_defaults(self):
        scene = make_scene([{"clip": "sweep"}])
        action = scene.sequence[0]
        assert isinstance(action, ClipAction)
        assert action.speed == 1.0
        assert action.wait is True
        assert action.duration_s is None

    @pytest.mark.parametrize("speed", [0, -1.0])
    def test_clip_speed_must_be_positive(self, speed):
        path = error_path(
            lambda: make_scene([{"clip": "sweep", "speed": speed}])
        )
        assert path == "sequence[0].speed"

    def test_clip_duration_must_be_positive(self):
        path = error_path(
            lambda: make_scene([{"clip": "sweep", "duration_s": 0}])
        )
        assert path == "sequence[0].duration_s"

    def test_clip_wait_must_be_boolean(self):
        path = error_path(
            lambda: make_scene([{"clip": "sweep", "wait": "no"}])
        )
        assert path == "sequence[0].wait"

    def test_clip_rejects_draft_spec_option(self):
        path = error_path(
            lambda: make_scene(
                [{"clip": "sweep", "wait_for_completion": True}]
            )
        )
        assert path == "sequence[0].wait_for_completion"

    def test_pose_requires_duration(self):
        path = error_path(
            lambda: make_scene([{"pose": {"pan.rotation": 10.0}}])
        )
        assert path == "sequence[0].duration_s"

    def test_pose_requires_a_target(self):
        path = error_path(
            lambda: make_scene([{"pose": {}, "duration_s": 1.0}])
        )
        assert path == "sequence[0].pose"

    def test_pose_duration_inside_targets_is_named(self):
        path = error_path(
            lambda: make_scene(
                [{"pose": {"pan.rotation": 1.0, "duration_s": 0.5}}]
            )
        )
        assert path == "sequence[0].pose.duration_s"

    def test_pose_duration_must_not_be_negative(self):
        path = error_path(
            lambda: make_scene(
                [{"pose": {"pan.rotation": 1.0}, "duration_s": -0.1}]
            )
        )
        assert path == "sequence[0].duration_s"

    def test_wait_requires_a_mapping(self):
        # The draft-spec scalar form (wait: 1.5) is out.
        assert error_path(
            lambda: make_scene([{"wait": 1.5}])
        ) == "sequence[0].wait"

    def test_wait_requires_seconds(self):
        path = error_path(lambda: make_scene([{"wait": {}}]))
        assert path == "sequence[0].wait.seconds"

    def test_wait_seconds_must_not_be_negative(self):
        path = error_path(
            lambda: make_scene([{"wait": {"seconds": -1.0}}])
        )
        assert path == "sequence[0].wait.seconds"

    def test_wait_for_requires_event(self):
        path = error_path(
            lambda: make_scene([{"wait_for": {"timeout_s": 1.0}}])
        )
        assert path == "sequence[0].wait_for.event"

    def test_wait_for_timeout_must_be_positive(self):
        path = error_path(
            lambda: make_scene(
                [{"wait_for": {"event": "go", "timeout_s": 0}}]
            )
        )
        assert path == "sequence[0].wait_for.timeout_s"

    def test_on_timeout_requires_a_timeout(self):
        path = error_path(
            lambda: make_scene(
                [{"wait_for": {"event": "go", "on_timeout": "skip"}}]
            )
        )
        assert path == "sequence[0].wait_for.on_timeout"

    def test_on_timeout_value_is_closed(self):
        path = error_path(
            lambda: make_scene(
                [{"wait_for": {"event": "go", "timeout_s": 1.0,
                               "on_timeout": "goto"}}]
            )
        )
        assert path == "sequence[0].wait_for.on_timeout"

    def test_wait_for_defaults(self):
        scene = make_scene([{"wait_for": {"event": "go"}}])
        action = scene.sequence[0]
        assert action.timeout_s is None
        assert action.on_timeout is TimeoutPolicy.SKIP

    @pytest.mark.parametrize("missing", ["var", "value"])
    def test_set_requires_var_and_value(self, missing):
        block = {"var": "x", "value": 1}
        del block[missing]
        path = error_path(lambda: make_scene([{"set": block}]))
        assert path == f"sequence[0].set.{missing}"

    def test_set_value_must_be_scalar(self):
        path = error_path(
            lambda: make_scene([{"set": {"var": "x", "value": [1]}}])
        )
        assert path == "sequence[0].set.value"

    @pytest.mark.parametrize("missing", ["var", "equals", "then"])
    def test_if_required_fields(self, missing):
        block = {"var": "x", "equals": 1, "then": []}
        del block[missing]
        path = error_path(lambda: make_scene([{"if": block}]))
        assert path == f"sequence[0].if.{missing}"

    def test_if_else_is_optional(self):
        scene = make_scene(
            [{"if": {"var": "x", "equals": 1, "then": []}}],
            variables={"x": 1},
        )
        assert scene.sequence[0].orelse == ()

    def test_loop_requires_exactly_one_bound(self):
        base = {"body": [{"wait": {"seconds": 1.0}}]}
        for block in (base, {**base, "count": 1, "while_var": "x"}):
            path = error_path(lambda b=block: make_scene([{"loop": b}]))
            assert path == "sequence[0].loop"

    def test_loop_requires_a_body(self):
        path = error_path(lambda: make_scene([{"loop": {"count": 1}}]))
        assert path == "sequence[0].loop.body"

    def test_loop_body_must_not_be_empty(self):
        path = error_path(
            lambda: make_scene([{"loop": {"count": 1, "body": []}}])
        )
        assert path == "sequence[0].loop.body"

    def test_loop_count_must_be_an_integer(self):
        path = error_path(
            lambda: make_scene(
                [{"loop": {"count": "forever",
                           "body": [{"wait": {"seconds": 1.0}}]}}]
            )
        )
        assert path == "sequence[0].loop.count"

    def test_loop_count_must_not_be_negative(self):
        path = error_path(
            lambda: make_scene(
                [{"loop": {"count": -1,
                           "body": [{"wait": {"seconds": 1.0}}]}}]
            )
        )
        assert path == "sequence[0].loop.count"

    def test_parallel_requires_tracks(self):
        path = error_path(lambda: make_scene([{"parallel": {}}]))
        assert path == "sequence[0].parallel.tracks"

    def test_parallel_tracks_must_not_be_empty(self):
        path = error_path(
            lambda: make_scene([{"parallel": {"tracks": []}}])
        )
        assert path == "sequence[0].parallel.tracks"

    def test_parallel_nested_errors_carry_the_track_path(self):
        path = error_path(
            lambda: make_scene(
                [{"parallel": {"tracks": [[], [{"dance": 1}]]}}]
            )
        )
        assert path == "sequence[0].parallel.tracks[1][0].dance"

    def test_event_requires_emit(self):
        path = error_path(lambda: make_scene([{"event": {}}]))
        assert path == "sequence[0].event.emit"


class TestRigValidation:
    def test_unknown_clip(self):
        scene = make_scene([{"clip": "moonwalk"}])
        with pytest.raises(SceneFormatError) as info:
            validate_scene(scene, RIG)
        assert info.value.path == "sequence[0].clip"
        assert "moonwalk" in info.value.message

    def test_looping_clip_requires_duration(self):
        scene = make_scene([{"clip": "nod"}])
        with pytest.raises(SceneFormatError) as info:
            validate_scene(scene, RIG)
        assert info.value.path == "sequence[0].duration_s"

    def test_looping_clip_with_duration_is_valid(self):
        scene = make_scene([{"clip": "nod", "duration_s": 2.0}])
        validate_scene(scene, RIG)

    def test_pose_undeclared_target(self):
        scene = make_scene(
            [{"pose": {"tail.rotation": 1.0}, "duration_s": 1.0}]
        )
        with pytest.raises(SceneFormatError) as info:
            validate_scene(scene, RIG)
        assert info.value.path == "sequence[0].pose.tail.rotation"

    def test_pose_value_outside_dof_limits(self):
        scene = make_scene(
            [{"pose": {"pan.rotation": 50.0}, "duration_s": 1.0}]
        )
        with pytest.raises(SceneFormatError) as info:
            validate_scene(scene, RIG)
        assert info.value.path == "sequence[0].pose.pan.rotation"

    def test_pose_parameter_outside_unit_range(self):
        scene = make_scene([{"pose": {"glow": 1.5}, "duration_s": 1.0}])
        with pytest.raises(SceneFormatError) as info:
            validate_scene(scene, RIG)
        assert info.value.path == "sequence[0].pose.glow"

    def test_pose_on_relation_driven_dof(self):
        scene = make_scene(
            [{"pose": {"jaw.rotation": 10.0}, "duration_s": 1.0}]
        )
        with pytest.raises(SceneFormatError) as info:
            validate_scene(scene, RELATION_RIG)
        assert info.value.path == "sequence[0].pose.jaw.rotation"
        assert "driven" in info.value.message

    @pytest.mark.parametrize(
        ("sequence", "path"),
        [
            (
                [{"set": {"var": "ghost", "value": 1}}],
                "sequence[0].set.var",
            ),
            (
                [{"if": {"var": "ghost", "equals": 1, "then": []}}],
                "sequence[0].if.var",
            ),
            (
                [{"loop": {"while_var": "ghost",
                           "body": [{"wait": {"seconds": 1.0}}]}}],
                "sequence[0].loop.while_var",
            ),
        ],
    )
    def test_undeclared_variable_references(self, sequence, path):
        scene = make_scene(sequence)
        with pytest.raises(SceneFormatError) as info:
            validate_scene(scene, RIG)
        assert info.value.path == path

    def test_validation_reaches_nested_sequences(self):
        scene = make_scene(
            [{"parallel": {"tracks": [[], [{"clip": "moonwalk"}]]}}]
        )
        with pytest.raises(SceneFormatError) as info:
            validate_scene(scene, RIG)
        assert info.value.path == "sequence[0].parallel.tracks[1][0].clip"


class TestLoadSceneFile:
    def write_scene(self, directory, character="chars/testbot.character.anima"):
        (directory / "chars").mkdir(exist_ok=True)
        (directory / "chars" / "testbot.character.anima").write_text(
            yaml.safe_dump(CHARACTER_DOCUMENT), encoding="utf-8"
        )
        scene_path = directory / "show.scene.anima"
        scene_path.write_text(
            yaml.safe_dump(
                scene_document([{"clip": "sweep"}], character=character)
            ),
            encoding="utf-8",
        )
        return scene_path

    def test_resolves_character_relative_to_the_scene_file(self, tmp_path):
        scene, rig = load_scene_file(self.write_scene(tmp_path))
        assert scene.identity.name == "test_scene"
        assert rig.identity.name == "testbot"

    def test_missing_character_file(self, tmp_path):
        scene_path = self.write_scene(tmp_path, character="nowhere.anima")
        with pytest.raises(SceneFormatError) as info:
            load_scene_file(scene_path)
        assert info.value.path == "character"
        assert "not found" in info.value.message

    def test_broken_character_file_is_wrapped(self, tmp_path):
        scene_path = self.write_scene(tmp_path)
        (tmp_path / "chars" / "testbot.character.anima").write_text(
            "anima_version: '2.0'\ntype: character\n", encoding="utf-8"
        )
        with pytest.raises(SceneFormatError) as info:
            load_scene_file(scene_path)
        assert info.value.path == "character"

    def test_rig_validation_runs_at_load(self, tmp_path):
        scene_path = tmp_path / "show.scene.anima"
        (tmp_path / "testbot.character.anima").write_text(
            yaml.safe_dump(CHARACTER_DOCUMENT), encoding="utf-8"
        )
        scene_path.write_text(
            yaml.safe_dump(scene_document([{"clip": "moonwalk"}])),
            encoding="utf-8",
        )
        with pytest.raises(SceneFormatError) as info:
            load_scene_file(scene_path)
        assert info.value.path == "sequence[0].clip"


class TestClipSemantics:
    def test_exact_frame_values_during_playback(self):
        runner, adapter = make_runner([{"clip": "sweep"}])
        for time_s in (0.0, 0.25, 0.5, 1.0):
            runner.advance(time_s)
            assert channel(adapter, 0) == pytest.approx(time_s)
            assert channel(adapter, 1) == pytest.approx(time_s)
        assert runner.result is SceneResult.FINISHED

    def test_speed_ratio_scales_playback(self):
        runner, adapter = make_runner([{"clip": "sweep", "speed": 2.0}])
        runner.advance(0.25)
        assert channel(adapter, 0) == pytest.approx(0.5)
        assert runner.advance(0.5) is SceneResult.FINISHED
        assert channel(adapter, 0) == pytest.approx(1.0)

    def test_background_clip_outlives_the_sequence(self):
        runner, _ = make_runner(
            [{"clip": "sweep", "wait": False}, {"event": {"emit": "on"}}]
        )
        assert runner.advance(0.2) is None  # clip still playing
        assert event_log(runner) == [("on", 0.0)]
        assert runner.advance(1.0) is SceneResult.FINISHED

    def test_looping_clip_wraps_time_modulo_its_duration(self):
        runner, adapter = make_runner([{"clip": "nod", "duration_s": 2.25}])
        runner.advance(1.75)  # local 0.75 -> 5 deg
        assert channel(adapter, 0) == pytest.approx(50.0 / 90.0)
        assert runner.advance(2.25) is SceneResult.FINISHED
        assert channel(adapter, 0) == pytest.approx(50.0 / 90.0)  # local .25

    def test_duration_longer_than_the_clip_holds_its_end(self):
        runner, adapter = make_runner(
            [{"clip": "sweep", "duration_s": 2.0}]
        )
        assert runner.advance(1.5) is None
        assert channel(adapter, 0) == pytest.approx(1.0)
        assert runner.advance(2.0) is SceneResult.FINISHED

    def test_finished_clip_values_hold(self):
        runner, adapter = make_runner(
            [{"clip": "sweep"}, {"wait": {"seconds": 1.0}}]
        )
        runner.advance(1.5)
        assert channel(adapter, 0) == pytest.approx(1.0)
        assert channel(adapter, 1) == pytest.approx(1.0)


class TestPoseSemantics:
    def test_pose_interpolates_from_neutral(self):
        runner, adapter = make_runner(
            [{"pose": {"pan.rotation": 45.0}, "duration_s": 1.0}]
        )
        runner.advance(0.5)
        assert channel(adapter, 0) == pytest.approx(0.75)  # 22.5 deg
        assert runner.advance(1.0) is SceneResult.FINISHED
        assert channel(adapter, 0) == pytest.approx(1.0)

    def test_pose_captures_start_from_prior_motion(self):
        runner, adapter = make_runner(
            [
                {"clip": "sweep"},
                {"pose": {"pan.rotation": 0.0}, "duration_s": 1.0},
            ]
        )
        runner.advance(1.5)  # pose runs 45 -> 0 deg from the clip end
        assert channel(adapter, 0) == pytest.approx(0.75)  # 22.5 deg

    def test_zero_duration_pose_jumps(self):
        runner, adapter = make_runner(
            [{"pose": {"pan.rotation": -45.0}, "duration_s": 0.0}]
        )
        assert runner.advance(0.0) is SceneResult.FINISHED
        assert channel(adapter, 0) == pytest.approx(0.0)

    def test_pose_drives_parameters(self):
        runner, adapter = make_runner(
            [{"pose": {"glow": 0.8}, "duration_s": 1.0}]
        )
        runner.advance(0.5)
        assert channel(adapter, 1) == pytest.approx(0.4)

    def test_later_started_source_wins_while_active(self):
        runner, adapter = make_runner(
            [
                {"parallel": {"tracks": [
                    [{"pose": {"pan.rotation": 45.0}, "duration_s": 2.0}],
                    [
                        {"wait": {"seconds": 0.5}},
                        {"pose": {"pan.rotation": -45.0},
                         "duration_s": 0.5},
                    ],
                ]}},
            ]
        )
        # Track 2's pose captures 11.25 deg at 0.5 and overrides while
        # active; the longer track-1 pose reasserts after it settles.
        runner.advance(0.75)
        assert channel(adapter, 0) == pytest.approx((45.0 - 16.875) / 90.0)
        runner.advance(1.5)
        assert channel(adapter, 0) == pytest.approx((45.0 + 33.75) / 90.0)
        assert runner.advance(2.0) is SceneResult.FINISHED


class TestWaitAndGates:
    def test_wait_holds_the_pose(self):
        runner, adapter = make_runner(
            [
                {"pose": {"pan.rotation": 45.0}, "duration_s": 1.0},
                {"wait": {"seconds": 1.0}},
                {"event": {"emit": "done"}},
            ]
        )
        runner.advance(1.5)
        assert channel(adapter, 0) == pytest.approx(1.0)
        assert runner.advance(2.0) is SceneResult.FINISHED
        assert event_log(runner) == [("done", 2.0)]

    def test_gate_resumes_at_the_post_time(self):
        runner, _ = make_runner(
            [{"wait_for": {"event": "go"}}, {"event": {"emit": "resumed"}}]
        )
        assert runner.advance(1.0) is None
        runner.post_event("go")
        assert runner.advance(2.0) is SceneResult.FINISHED
        assert event_log(runner) == [("resumed", 1.0)]

    def test_gate_without_timeout_waits_indefinitely(self):
        runner, _ = make_runner([{"wait_for": {"event": "go"}}])
        assert runner.advance(100.0) is None

    def test_timeout_skip_continues_at_the_deadline(self):
        runner, _ = make_runner(
            [
                {"wait_for": {"event": "go", "timeout_s": 1.0}},
                {"event": {"emit": "after"}},
            ]
        )
        assert runner.advance(2.0) is SceneResult.FINISHED
        assert event_log(runner) == [("after", 1.0)]

    def test_timeout_end_ends_the_scene(self):
        runner, adapter = make_runner(
            [
                {"wait_for": {"event": "go", "timeout_s": 1.0,
                              "on_timeout": "end"}},
                {"event": {"emit": "never"}},
            ]
        )
        assert runner.advance(0.5) is None
        frames_before = len(adapter.frames)
        assert runner.advance(2.0) is SceneResult.ENDED_BY_GATE_TIMEOUT
        assert len(adapter.frames) == frames_before  # ending sends no frame
        assert event_log(runner) == []
        assert runner.advance(3.0) is SceneResult.ENDED_BY_GATE_TIMEOUT

    def test_timeout_end_in_a_parallel_track_ends_everything(self):
        runner, _ = make_runner(
            [{"parallel": {"tracks": [
                [{"wait_for": {"event": "go", "timeout_s": 1.0,
                               "on_timeout": "end"}}],
                [{"wait": {"seconds": 5.0}}],
            ]}}]
        )
        assert runner.advance(2.0) is SceneResult.ENDED_BY_GATE_TIMEOUT

    def test_events_are_edge_triggered(self):
        runner, _ = make_runner(
            [
                {"wait_for": {"event": "go", "timeout_s": 1.0}},
                {"event": {"emit": "after"}},
            ]
        )
        runner.post_event("go")  # nothing is waiting yet: dropped
        runner.advance(2.0)
        assert event_log(runner) == [("after", 1.0)]  # the timeout path

    def test_event_without_a_listener_is_dropped(self):
        runner, _ = make_runner([{"wait": {"seconds": 1.0}}])
        runner.post_event("nobody-cares")
        assert runner.advance(1.0) is SceneResult.FINISHED

    def test_one_event_releases_every_waiting_gate(self):
        runner, _ = make_runner(
            [{"parallel": {"tracks": [
                [{"wait_for": {"event": "go"}}, {"event": {"emit": "a"}}],
                [{"wait_for": {"event": "go"}}, {"event": {"emit": "b"}}],
            ]}}]
        )
        runner.advance(1.0)
        runner.post_event("go")
        assert runner.advance(2.0) is SceneResult.FINISHED
        assert event_log(runner) == [("a", 1.0), ("b", 1.0)]


class TestVariablesAndLogic:
    def test_set_then_if_takes_the_then_branch(self):
        runner, _ = make_runner(
            [
                {"set": {"var": "mood", "value": "happy"}},
                {"if": {"var": "mood", "equals": "happy",
                        "then": [{"event": {"emit": "yes"}}],
                        "else": [{"event": {"emit": "no"}}]}},
            ],
            variables={"mood": "sad"},
        )
        runner.advance(0.0)
        assert event_log(runner) == [("yes", 0.0)]

    def test_if_takes_the_else_branch(self):
        runner, _ = make_runner(
            [{"if": {"var": "mood", "equals": "happy",
                     "then": [{"event": {"emit": "yes"}}],
                     "else": [{"event": {"emit": "no"}}]}}],
            variables={"mood": "sad"},
        )
        runner.advance(0.0)
        assert event_log(runner) == [("no", 0.0)]

    def test_set_copies_another_variable(self):
        runner, _ = make_runner(
            [
                {"set": {"var": "b", "value": "a"}},
                {"if": {"var": "b", "equals": 5,
                        "then": [{"event": {"emit": "copied"}}]}},
            ],
            variables={"a": 5, "b": 0},
        )
        runner.advance(0.0)
        assert event_log(runner) == [("copied", 0.0)]
        assert runner.variables["b"] == 5

    def test_set_string_not_naming_a_variable_is_a_literal(self):
        runner, _ = make_runner(
            [{"set": {"var": "msg", "value": "hello"}}],
            variables={"msg": "x"},
        )
        runner.advance(0.0)
        assert runner.variables["msg"] == "hello"

    def test_bool_true_does_not_equal_int_one(self):
        runner, _ = make_runner(
            [{"if": {"var": "flag", "equals": 1,
                     "then": [{"event": {"emit": "int"}}],
                     "else": [{"event": {"emit": "bool"}}]}}],
            variables={"flag": True},
        )
        runner.advance(0.0)
        assert event_log(runner) == [("bool", 0.0)]

    def test_counted_loop_repeats_with_exact_timing(self):
        runner, _ = make_runner(
            [{"loop": {"count": 3, "body": [
                {"wait": {"seconds": 0.5}},
                {"event": {"emit": "tick"}},
            ]}}]
        )
        assert runner.advance(1.5) is SceneResult.FINISHED
        assert event_log(runner) == [
            ("tick", 0.5), ("tick", 1.0), ("tick", 1.5)
        ]

    def test_zero_count_loop_is_skipped(self):
        runner, _ = make_runner(
            [
                {"loop": {"count": 0,
                          "body": [{"event": {"emit": "never"}}]}},
                {"event": {"emit": "after"}},
            ]
        )
        assert runner.advance(0.0) is SceneResult.FINISHED
        assert event_log(runner) == [("after", 0.0)]

    def test_while_loop_gated_by_a_parallel_track(self):
        runner, _ = make_runner(
            [
                {"parallel": {"tracks": [
                    [
                        {"wait_for": {"event": "halt", "timeout_s": 10.0}},
                        {"set": {"var": "run", "value": False}},
                    ],
                    [{"loop": {"while_var": "run",
                               "body": [{"wait": {"seconds": 1.0}}]}}],
                ]}},
                {"event": {"emit": "done"}},
            ],
            variables={"run": True},
        )
        runner.advance(0.5)
        runner.post_event("halt")  # stops the loop at its next check
        assert runner.advance(1.0) is SceneResult.FINISHED
        assert event_log(runner) == [("done", 1.0)]
        assert runner.variables["run"] is False

    def test_zero_time_while_iteration_is_a_runtime_error(self):
        runner, _ = make_runner(
            [{"loop": {"while_var": "spin",
                       "body": [{"set": {"var": "spin", "value": True}}]}}],
            variables={"spin": True},
        )
        with pytest.raises(SceneRuntimeError, match="no time"):
            runner.advance(0.0)

    def test_while_var_must_hold_a_boolean(self):
        runner, _ = make_runner(
            [{"loop": {"while_var": "n",
                       "body": [{"wait": {"seconds": 1.0}}]}}],
            variables={"n": 3},
        )
        with pytest.raises(SceneRuntimeError, match="boolean"):
            runner.advance(0.0)


class TestParallel:
    def test_completes_when_the_longest_track_finishes(self):
        runner, _ = make_runner(
            [
                {"parallel": {"tracks": [
                    [{"wait": {"seconds": 1.0}}],
                    [{"wait": {"seconds": 2.0}}],
                ]}},
                {"event": {"emit": "joined"}},
            ]
        )
        assert runner.advance(1.5) is None
        assert runner.advance(2.0) is SceneResult.FINISHED
        assert event_log(runner) == [("joined", 2.0)]

    def test_same_timestamp_writes_apply_in_track_order(self):
        runner, _ = make_runner(
            [
                {"parallel": {"tracks": [
                    [{"set": {"var": "x", "value": "first"}}],
                    [{"set": {"var": "x", "value": "second"}}],
                ]}},
            ],
            variables={"x": "none"},
        )
        runner.advance(0.0)
        assert runner.variables["x"] == "second"

    def test_interleaving_is_ordered_by_timestamp_then_track(self):
        runner, _ = make_runner(
            [{"parallel": {"tracks": [
                [{"wait": {"seconds": 0.5}}, {"event": {"emit": "a"}}],
                [
                    {"event": {"emit": "b"}},
                    {"wait": {"seconds": 1.0}},
                    {"event": {"emit": "c"}},
                ],
            ]}}]
        )
        runner.advance(2.0)
        assert event_log(runner) == [
            ("b", 0.0), ("a", 0.5), ("c", 1.0)
        ]


class TestRunnerLifecycle:
    def test_time_must_not_go_backwards(self):
        runner, _ = make_runner([{"wait": {"seconds": 5.0}}])
        runner.advance(1.0)
        with pytest.raises(SceneRuntimeError, match="backwards"):
            runner.advance(0.5)

    def test_repeating_the_same_time_is_legal(self):
        runner, adapter = make_runner([{"wait": {"seconds": 5.0}}])
        runner.advance(1.0)
        runner.advance(1.0)
        assert len(adapter.frames) == 2

    def test_frame_interval_is_the_frame_duration(self):
        runner, adapter = make_runner([{"wait": {"seconds": 1.0}}])
        runner.advance(0.0)
        assert adapter.frames[-1][1] == 33
        runner, adapter = make_runner(
            [{"wait": {"seconds": 1.0}}], frame_interval_ms=20
        )
        runner.advance(0.0)
        assert adapter.frames[-1][1] == 20

    def test_frame_interval_must_be_positive(self):
        with pytest.raises(ValueError, match="frame interval"):
            make_runner([], frame_interval_ms=0)

    def test_stop_is_an_e_stop_and_marks_the_run(self):
        runner, adapter = make_runner([{"wait": {"seconds": 5.0}}])
        runner.advance(1.0)
        frames = len(adapter.frames)
        runner.stop()
        assert adapter.stopped
        assert runner.result is SceneResult.STOPPED
        assert runner.advance(2.0) is SceneResult.STOPPED
        assert len(adapter.frames) == frames

    def test_stop_after_finish_keeps_the_finished_result(self):
        runner, adapter = make_runner([])
        runner.advance(0.0)
        runner.stop()
        assert adapter.stopped
        assert runner.result is SceneResult.FINISHED

    def test_no_frames_after_finishing(self):
        runner, adapter = make_runner([])
        assert runner.advance(0.0) is SceneResult.FINISHED
        assert channel(adapter, 0) == pytest.approx(0.5)  # neutral frame
        frames = len(adapter.frames)
        runner.advance(1.0)
        assert len(adapter.frames) == frames

    def test_on_event_callback_fires_in_order(self):
        calls: list[tuple[str, float]] = []
        adapter = RecordingAdapter()
        runner = SceneRunner(
            make_scene(
                [
                    {"event": {"emit": "first"}},
                    {"wait": {"seconds": 1.0}},
                    {"event": {"emit": "second"}},
                ]
            ),
            RIG,
            adapter,
            on_event=lambda name, time_s: calls.append((name, time_s)),
        )
        runner.advance(1.0)
        assert calls == [("first", 0.0), ("second", 1.0)]

    def test_relation_driven_channel_projects_within_limits(self):
        runner, adapter = make_runner(
            [{"pose": {"pan.rotation": 10.0}, "duration_s": 1.0}],
            rig=RELATION_RIG,
        )
        runner.advance(1.0)  # jaw = 2 * 10 = 20 deg over [-30, 30]
        assert channel(adapter, 0) == pytest.approx(50.0 / 60.0)

    def test_limit_violation_refuses_to_send(self):
        runner, _ = make_runner(
            [{"pose": {"pan.rotation": 20.0}, "duration_s": 1.0}],
            rig=RELATION_RIG,
        )
        runner.advance(0.5)  # jaw = 20 deg: still legal
        with pytest.raises(LimitViolationError):
            runner.advance(1.0)  # jaw = 40 deg: outside [-30, 30]


class TestPickAndWaveExample:
    """End-to-end: the shipped example through the simulator adapter."""

    SCENE_PATH = EXAMPLES_DIR / "pick_and_wave.scene.anima"

    def make_runner(self):
        scene, rig = load_scene_file(self.SCENE_PATH)
        adapter = SimulatorOutput(SimulatedDevice(channel_count=8))
        adapter.open(
            [
                ChannelConfig(
                    channel=index,
                    pin=2 + index,
                    min_us=600,
                    max_us=2400,
                    failsafe_ms=60_000,
                )
                for index in range(6)
            ]
        )
        return SceneRunner(scene, rig, adapter), adapter

    @staticmethod
    def drive(runner, adapter, time_s):
        """Advance the scene, then land the simulated servos on the
        frame target (frames span 33 ms on the device clock)."""
        result = runner.advance(time_s)
        adapter.device.tick(int(round(time_s * 1000)) + 33)
        return result

    def test_scene_and_character_load(self):
        scene, rig = load_scene_file(self.SCENE_PATH)
        assert scene.identity.name == "pick_and_wave"
        assert rig.identity.name == "six_axis_arm"
        assert scene.variables == {"keep_scanning": True, "finale": "wave"}

    def test_show_without_a_visitor_runs_the_full_scan(self):
        runner, adapter = self.make_runner()
        base_yaw = adapter.device.channel_value  # ch0: (deg+170)/340

        # Mid pick gesture: base_yaw keyframed to 60 deg at 1.0 s.
        assert self.drive(runner, adapter, 1.0) is None
        assert base_yaw(0) == pytest.approx(230.0 / 340.0, abs=1e-3)

        # First scan sweep: 0 -> 40 deg over 3.0..4.0 s.
        assert self.drive(runner, adapter, 3.5) is None
        assert base_yaw(0) == pytest.approx(190.0 / 340.0, abs=1e-3)

        # The gate times out at 8.5 s; the sweep 8..9 s is mid-return.
        assert self.drive(runner, adapter, 8.5) is None
        assert base_yaw(0) == pytest.approx(0.5, abs=1e-3)
        assert runner.variables["keep_scanning"] is False

        # Double-speed pick reprise starts at 9.0 s: local 1.5 s -> 45.
        assert self.drive(runner, adapter, 9.75) is None
        assert base_yaw(0) == pytest.approx(215.0 / 340.0, abs=1e-3)

        # Wrist flicks, wait, and park: finished just past 13.1 s.
        assert self.drive(runner, adapter, 13.2) is SceneResult.FINISHED
        assert base_yaw(0) == pytest.approx(0.5, abs=1e-3)   # base parked
        assert base_yaw(4) == pytest.approx(0.5, abs=1e-3)   # wrist_roll 0
        assert base_yaw(2) == pytest.approx(30.0 / 155.0, abs=1e-3)

        events = [(event.name, event.time_s) for event in
                  runner.emitted_events]
        assert events[0] == ("scene_started", 0.0)
        assert events[-1][0] == "scene_finished"
        assert events[-1][1] == pytest.approx(13.1)

    def test_visitor_event_cuts_the_scan_short(self):
        runner, adapter = self.make_runner()
        assert self.drive(runner, adapter, 4.2) is None
        runner.post_event("visitor_detected")

        # Scan stops at the 5.0 s sweep boundary; the reprise runs
        # 5.0..6.5 s, so local time at 5.5 s is 1.0 s -> 60 deg.
        assert self.drive(runner, adapter, 5.5) is None
        assert runner.variables["keep_scanning"] is False
        assert adapter.device.channel_value(0) == pytest.approx(
            230.0 / 340.0, abs=1e-3
        )

        assert self.drive(runner, adapter, 9.2) is SceneResult.FINISHED
        finished = runner.emitted_events[-1]
        assert finished.name == "scene_finished"
        assert finished.time_s == pytest.approx(9.1)


class TestEditorBlock:
    """N1 (Node_Graph.md): the runtime tolerates and preserves an
    opaque `editor:` block — node-canvas layout is never interpreted."""

    def test_editor_block_accepted_and_preserved(self):
        layout = {"layout": {"nodes": {"start": {"x": 0, "y": 0}}}}
        scene = make_scene([{"wait": {"seconds": 0.1}}], editor=layout)
        assert scene.editor == layout

    def test_editor_absent_is_none(self):
        assert make_scene([{"wait": {"seconds": 0.1}}]).editor is None

    def test_editor_non_mapping_rejected(self):
        path = error_path(
            lambda: make_scene([{"wait": {"seconds": 0.1}}], editor=12)
        )
        assert path == "editor"


# v2 — the FANUC-inspired scripting constructs -----------------------------------


def make_v2_runner(sequence, variables=None, rig=RIG, **scene_overrides):
    adapter = RecordingAdapter()
    runner = SceneRunner(
        make_scene(sequence, variables, **scene_overrides), rig, adapter
    )
    return runner, adapter


def validate_error(sequence, variables=None, rig=RIG, **overrides):
    scene = make_scene(sequence, variables, **overrides)
    with pytest.raises(SceneFormatError) as info:
        validate_scene(scene, rig)
    return info.value


class TestConditionParsing:
    """Condition trees are structured data — closed schema, pathed."""

    def parse_when(self, when):
        return make_scene([{"wait_until": {"when": when}}])

    WHEN = "sequence[0].wait_until.when"

    @pytest.mark.parametrize("op", ["eq", "ne", "lt", "le", "gt", "ge"])
    def test_every_comparison_operator_parses(self, op):
        self.parse_when({"var": "x", "op": op, "value": 1})

    def test_unknown_operator(self):
        path = error_path(
            lambda: self.parse_when(
                {"var": "x", "op": "contains", "value": 1}
            )
        )
        assert path == f"{self.WHEN}.op"

    @pytest.mark.parametrize("missing", ["op", "value"])
    def test_leaf_requires_op_and_value(self, missing):
        leaf = {"var": "x", "op": "eq", "value": 1}
        del leaf[missing]
        path = error_path(lambda: self.parse_when(leaf))
        assert path == f"{self.WHEN}.{missing}"

    @pytest.mark.parametrize(
        "leaf",
        [
            {"op": "eq", "value": 1},  # neither operand name
            {"var": "x", "input": "y", "op": "eq", "value": 1},  # both
        ],
    )
    def test_leaf_names_exactly_one_of_var_or_input(self, leaf):
        with pytest.raises(SceneFormatError) as info:
            self.parse_when(leaf)
        assert info.value.path == self.WHEN
        assert "exactly one" in info.value.message

    def test_leaf_rejects_unknown_field(self):
        path = error_path(
            lambda: self.parse_when(
                {"var": "x", "op": "eq", "value": 1, "hysteresis": 2}
            )
        )
        assert path == f"{self.WHEN}.hysteresis"

    def test_leaf_value_must_be_scalar(self):
        path = error_path(
            lambda: self.parse_when({"var": "x", "op": "eq", "value": [1]})
        )
        assert path == f"{self.WHEN}.value"

    @pytest.mark.parametrize("operand", ["var", "input"])
    def test_leaf_operand_name_must_not_be_empty(self, operand):
        path = error_path(
            lambda: self.parse_when({operand: "", "op": "eq", "value": 1})
        )
        assert path == f"{self.WHEN}.{operand}"

    @pytest.mark.parametrize("combinator", ["all", "any"])
    def test_combinator_requires_a_list(self, combinator):
        path = error_path(lambda: self.parse_when({combinator: 5}))
        assert path == f"{self.WHEN}.{combinator}"

    @pytest.mark.parametrize("combinator", ["all", "any"])
    def test_combinator_requires_at_least_one_condition(self, combinator):
        path = error_path(lambda: self.parse_when({combinator: []}))
        assert path == f"{self.WHEN}.{combinator}"

    @pytest.mark.parametrize("count", [0, 1, 3])
    def test_xor_takes_exactly_two_operands(self, count):
        leaf = {"var": "x", "op": "eq", "value": 1}
        with pytest.raises(SceneFormatError) as info:
            self.parse_when({"xor": [dict(leaf) for _ in range(count)]})
        assert info.value.path == f"{self.WHEN}.xor"
        assert "exactly two" in info.value.message

    def test_not_operand_must_be_a_mapping(self):
        path = error_path(lambda: self.parse_when({"not": "x"}))
        assert path == f"{self.WHEN}.not"

    def test_two_combinators_in_one_node(self):
        with pytest.raises(SceneFormatError) as info:
            self.parse_when({"all": [], "any": []})
        assert info.value.path == self.WHEN
        assert "more than one combinator" in info.value.message

    def test_combinator_rejects_sibling_leaf_keys(self):
        leaf = {"var": "x", "op": "eq", "value": 1}
        path = error_path(
            lambda: self.parse_when({"all": [leaf], "var": "x"})
        )
        assert path == f"{self.WHEN}.var"

    def test_nested_tree_parses_and_errors_carry_deep_paths(self):
        leaf = {"var": "x", "op": "eq", "value": 1}
        self.parse_when(
            {"all": [
                {"any": [dict(leaf), {"not": dict(leaf)}]},
                {"xor": [dict(leaf), dict(leaf)]},
            ]}
        )
        path = error_path(
            lambda: self.parse_when(
                {"all": [{"any": [{"not": {"var": "x", "op": "??",
                                           "value": 1}}]}]}
            )
        )
        assert path == f"{self.WHEN}.all[0].any[0].not.op"


class TestIfWhen:
    """`if:` gains a `when:` condition tree — exactly one guard form."""

    LEAF = {"var": "mood", "op": "eq", "value": "happy"}

    @pytest.mark.parametrize(
        "block",
        [
            {"then": []},  # no guard at all
            {"var": "x", "equals": 1,
             "when": {"var": "x", "op": "eq", "value": 1}, "then": []},
            {"var": "x",
             "when": {"var": "x", "op": "eq", "value": 1}, "then": []},
            {"equals": 1,
             "when": {"var": "x", "op": "eq", "value": 1}, "then": []},
        ],
    )
    def test_exactly_one_guard_form(self, block):
        with pytest.raises(SceneFormatError) as info:
            make_scene([{"if": block}])
        assert info.value.path == "sequence[0].if"
        assert "exactly one guard" in info.value.message

    def test_when_true_takes_then(self):
        runner, _ = make_v2_runner(
            [{"if": {"when": dict(self.LEAF),
                     "then": [{"event": {"emit": "yes"}}],
                     "else": [{"event": {"emit": "no"}}]}}],
            variables={"mood": "happy"},
        )
        runner.advance(0.0)
        assert event_log(runner) == [("yes", 0.0)]

    def test_when_false_takes_else(self):
        runner, _ = make_v2_runner(
            [{"if": {"when": dict(self.LEAF),
                     "then": [{"event": {"emit": "yes"}}],
                     "else": [{"event": {"emit": "no"}}]}}],
            variables={"mood": "sad"},
        )
        runner.advance(0.0)
        assert event_log(runner) == [("no", 0.0)]

    def test_when_condition_variables_are_validated(self):
        error = validate_error(
            [{"if": {"when": {"var": "ghost", "op": "eq", "value": 1},
                     "then": []}}]
        )
        assert error.path == "sequence[0].if.when.var"


class TestConditionSemantics:
    """Typed comparison discipline, evaluated through `if: {when}`."""

    def holds(self, when, variables=None, inputs=None):
        overrides = {} if inputs is None else {"inputs": inputs}
        runner, _ = make_v2_runner(
            [{"if": {"when": when,
                     "then": [{"event": {"emit": "yes"}}],
                     "else": [{"event": {"emit": "no"}}]}}],
            variables,
            **overrides,
        )
        runner.advance(0.0)
        return event_log(runner) == [("yes", 0.0)]

    def test_numbers_compare_numerically_across_int_and_float(self):
        assert self.holds(
            {"var": "n", "op": "eq", "value": 1.0}, {"n": 1}
        )

    def test_bool_true_does_not_equal_int_one(self):
        assert not self.holds(
            {"var": "flag", "op": "eq", "value": 1}, {"flag": True}
        )
        assert self.holds(
            {"var": "flag", "op": "ne", "value": 1}, {"flag": True}
        )

    def test_mismatched_kinds_are_simply_unequal(self):
        assert not self.holds(
            {"var": "s", "op": "eq", "value": 3}, {"s": "3"}
        )
        assert self.holds(
            {"var": "s", "op": "ne", "value": 3}, {"s": "3"}
        )

    @pytest.mark.parametrize(
        ("op", "value", "expected"),
        [
            ("lt", 3, True), ("lt", 2, False),
            ("le", 2, True), ("gt", 1, True),
            ("ge", 2, True), ("ge", 3, False),
        ],
    )
    def test_ordering_operators_on_numbers(self, op, value, expected):
        held = self.holds({"var": "n", "op": op, "value": value}, {"n": 2})
        assert held is expected

    @pytest.mark.parametrize(
        ("variables", "value"),
        [
            ({"x": "text"}, 3),     # string left operand
            ({"x": 3}, "text"),     # string right operand
            ({"x": True}, 1),       # bool is not a number here
        ],
    )
    def test_ordering_on_non_numbers_is_a_typed_runtime_error(
        self, variables, value
    ):
        runner, _ = make_v2_runner(
            [{"if": {"when": {"var": "x", "op": "lt", "value": value},
                     "then": []}}],
            variables,
        )
        with pytest.raises(SceneRuntimeError, match="requires numbers"):
            runner.advance(0.0)

    def test_value_naming_a_variable_copies_it(self):
        assert self.holds(
            {"var": "b", "op": "lt", "value": "a"}, {"a": 5, "b": 1}
        )

    def test_value_string_not_naming_a_variable_is_a_literal(self):
        assert self.holds(
            {"var": "s", "op": "eq", "value": "hello"}, {"s": "hello"}
        )

    def test_input_leaf_reads_the_input_namespace(self):
        assert self.holds(
            {"input": "sensor", "op": "ge", "value": 2},
            inputs={"sensor": 3},
        )

    @pytest.mark.parametrize(
        ("first", "second", "expected"),
        [(True, True, False), (True, False, True),
         (False, True, True), (False, False, False)],
    )
    def test_xor_is_exactly_one(self, first, second, expected):
        when = {"xor": [
            {"var": "a", "op": "eq", "value": True},
            {"var": "b", "op": "eq", "value": True},
        ]}
        assert self.holds(when, {"a": first, "b": second}) is expected

    def test_not_inverts(self):
        when = {"not": {"var": "a", "op": "eq", "value": True}}
        assert self.holds(when, {"a": False})
        assert not self.holds(when, {"a": True})

    def test_nested_all_any_tree(self):
        when = {"all": [
            {"var": "armed", "op": "eq", "value": True},
            {"any": [
                {"var": "zone", "op": "eq", "value": 1},
                {"var": "zone", "op": "ge", "value": 2},
            ]},
        ]}
        assert self.holds(when, {"armed": True, "zone": 2})
        assert not self.holds(when, {"armed": True, "zone": 0})
        assert not self.holds(when, {"armed": False, "zone": 1})


class TestSelectParsing:
    def case(self, equals, emit):
        return {"equals": equals, "then": [{"event": {"emit": emit}}]}

    @pytest.mark.parametrize("missing", ["var", "cases"])
    def test_select_requires_var_and_cases(self, missing):
        block = {"var": "x", "cases": [self.case(1, "a")]}
        del block[missing]
        path = error_path(lambda: make_scene([{"select": block}]))
        assert path == f"sequence[0].select.{missing}"

    @pytest.mark.parametrize("cases", [{}, []])
    def test_cases_must_be_a_non_empty_list(self, cases):
        path = error_path(
            lambda: make_scene([{"select": {"var": "x", "cases": cases}}])
        )
        assert path == "sequence[0].select.cases"

    @pytest.mark.parametrize("missing", ["equals", "then"])
    def test_case_requires_equals_and_then(self, missing):
        case = self.case(1, "a")
        del case[missing]
        path = error_path(
            lambda: make_scene([{"select": {"var": "x", "cases": [case]}}])
        )
        assert path == f"sequence[0].select.cases[0].{missing}"

    def test_case_rejects_unknown_field(self):
        case = {**self.case(1, "a"), "fallthrough": True}
        path = error_path(
            lambda: make_scene([{"select": {"var": "x", "cases": [case]}}])
        )
        assert path == "sequence[0].select.cases[0].fallthrough"

    def test_duplicate_case_literals_are_rejected(self):
        with pytest.raises(SceneFormatError) as info:
            make_scene(
                [{"select": {"var": "x",
                             "cases": [self.case(1, "a"),
                                       self.case(1, "b")]}}]
            )
        assert info.value.path == "sequence[0].select.cases[1].equals"
        assert "duplicate" in info.value.message

    def test_int_and_float_case_literals_are_duplicates(self):
        # Numbers compare numerically, so 1.0 could never run after 1.
        path = error_path(
            lambda: make_scene(
                [{"select": {"var": "x",
                             "cases": [self.case(1, "a"),
                                       self.case(1.0, "b")]}}]
            )
        )
        assert path == "sequence[0].select.cases[1].equals"

    def test_bool_and_int_case_literals_are_distinct(self):
        # true != 1: both cases are reachable, this must parse.
        make_scene(
            [{"select": {"var": "x",
                         "cases": [self.case(True, "a"),
                                   self.case(1, "b")]}}]
        )

    def test_select_rejects_unknown_field(self):
        path = error_path(
            lambda: make_scene(
                [{"select": {"var": "x", "cases": [self.case(1, "a")],
                             "otherwise": []}}]
            )
        )
        assert path == "sequence[0].select.otherwise"

    def test_select_var_must_be_declared(self):
        error = validate_error(
            [{"select": {"var": "ghost", "cases": [self.case(1, "a")]}}]
        )
        assert error.path == "sequence[0].select.var"

    def test_validation_reaches_case_and_default_bodies(self):
        error = validate_error(
            [{"select": {"var": "x",
                         "cases": [{"equals": 1,
                                    "then": [{"clip": "moonwalk"}]}]}}],
            variables={"x": 1},
        )
        assert error.path == "sequence[0].select.cases[0].then[0].clip"


class TestSelectSemantics:
    def run_select(self, variables, cases, default=None):
        block = {"var": "mode", "cases": cases}
        if default is not None:
            block["default"] = default
        runner, _ = make_v2_runner(
            [{"select": block}, {"event": {"emit": "after"}}], variables
        )
        runner.advance(0.0)
        return event_log(runner)

    def case(self, equals, emit):
        return {"equals": equals, "then": [{"event": {"emit": emit}}]}

    def test_first_matching_case_runs_no_fallthrough(self):
        events = self.run_select(
            {"mode": "b"},
            [self.case("a", "took_a"), self.case("b", "took_b")],
            default=[{"event": {"emit": "took_default"}}],
        )
        assert events == [("took_b", 0.0), ("after", 0.0)]

    def test_default_runs_when_nothing_matches(self):
        events = self.run_select(
            {"mode": "z"},
            [self.case("a", "took_a")],
            default=[{"event": {"emit": "took_default"}}],
        )
        assert events == [("took_default", 0.0), ("after", 0.0)]

    def test_no_match_and_no_default_skips(self):
        events = self.run_select({"mode": "z"}, [self.case("a", "took_a")])
        assert events == [("after", 0.0)]

    def test_bool_variable_matches_the_bool_case_not_int(self):
        events = self.run_select(
            {"mode": True},
            [self.case(1, "took_int"), self.case(True, "took_bool")],
        )
        assert events == [("took_bool", 0.0), ("after", 0.0)]

    def test_numeric_match_across_int_and_float(self):
        events = self.run_select({"mode": 1}, [self.case(1.0, "took_num")])
        assert events == [("took_num", 0.0), ("after", 0.0)]


class TestSubroutineParsing:
    def test_unknown_call_target_from_the_sequence(self):
        with pytest.raises(SceneFormatError) as info:
            make_scene([{"call": "ghost"}], subroutines={})
        assert info.value.path == "sequence[0].call"
        assert "unknown subroutine" in info.value.message

    def test_unknown_call_target_from_a_subroutine(self):
        path = error_path(
            lambda: make_scene(
                [], subroutines={"a": [{"call": "ghost"}]}
            )
        )
        assert path == "subroutines.a[0].call"

    def test_direct_recursion_names_the_cycle(self):
        with pytest.raises(SceneFormatError) as info:
            make_scene([], subroutines={"a": [{"call": "a"}]})
        assert info.value.path == "subroutines.a[0].call"
        assert "a -> a" in info.value.message

    def test_indirect_recursion_names_the_cycle_path(self):
        with pytest.raises(SceneFormatError) as info:
            make_scene(
                [{"call": "a"}],
                subroutines={
                    "a": [{"call": "b"}],
                    "b": [{"wait": {"seconds": 1.0}}, {"call": "a"}],
                },
            )
        assert info.value.path == "subroutines.b[1].call"
        assert "a -> b -> a" in info.value.message

    def test_recursion_hidden_in_a_branch_is_found(self):
        with pytest.raises(SceneFormatError) as info:
            make_scene(
                [],
                subroutines={
                    "a": [{"if": {"var": "x", "equals": 1,
                                  "then": [{"call": "a"}]}}],
                },
            )
        assert "a -> a" in info.value.message

    def test_call_must_be_a_non_empty_string(self):
        assert error_path(
            lambda: make_scene([{"call": 5}], subroutines={})
        ) == "sequence[0].call"
        assert error_path(
            lambda: make_scene([{"call": ""}], subroutines={})
        ) == "sequence[0].call"

    def test_subroutines_must_be_a_mapping(self):
        path = error_path(lambda: make_scene([], subroutines=[1]))
        assert path == "subroutines"

    def test_subroutine_name_must_be_non_empty(self):
        path = error_path(lambda: make_scene([], subroutines={"": []}))
        assert path == "subroutines."

    def test_subroutine_body_errors_carry_the_path(self):
        path = error_path(
            lambda: make_scene([], subroutines={"a": [{"dance": 1}]})
        )
        assert path == "subroutines.a[0].dance"

    def test_end_scene_is_rejected_inside_a_subroutine(self):
        with pytest.raises(SceneFormatError) as info:
            make_scene(
                [],
                subroutines={"a": [{"end_scene": {"result": "x"}}]},
            )
        assert info.value.path == "subroutines.a[0].end_scene"
        assert "only inside" in info.value.message

    def test_end_scene_is_rejected_in_the_main_sequence(self):
        with pytest.raises(SceneFormatError) as info:
            make_scene([{"end_scene": {"result": "x"}}])
        assert info.value.path == "sequence[0].end_scene"
        assert "only inside" in info.value.message

    def test_rig_validation_reaches_subroutines(self):
        error = validate_error(
            [{"call": "a"}], subroutines={"a": [{"clip": "moonwalk"}]}
        )
        assert error.path == "subroutines.a[0].clip"


class TestSubroutineSemantics:
    BEEP = {"beep": [{"wait": {"seconds": 0.5}},
                     {"event": {"emit": "beep"}}]}

    def test_call_runs_the_body_then_resumes(self):
        runner, _ = make_v2_runner(
            [{"call": "beep"}, {"event": {"emit": "after"}}],
            subroutines=self.BEEP,
        )
        assert runner.advance(1.0) is SceneResult.FINISHED
        assert event_log(runner) == [("beep", 0.5), ("after", 0.5)]

    def test_two_call_sites_run_independently(self):
        runner, _ = make_v2_runner(
            [{"call": "beep"}, {"call": "beep"}], subroutines=self.BEEP
        )
        assert runner.advance(1.0) is SceneResult.FINISHED
        assert event_log(runner) == [("beep", 0.5), ("beep", 1.0)]

    def test_nested_calls_resume_in_order(self):
        runner, _ = make_v2_runner(
            [{"call": "outer"}, {"event": {"emit": "all"}}],
            subroutines={
                "outer": [{"call": "inner"},
                          {"event": {"emit": "outer_done"}}],
                "inner": [{"wait": {"seconds": 0.5}},
                          {"event": {"emit": "inner_done"}}],
            },
        )
        assert runner.advance(1.0) is SceneResult.FINISHED
        assert event_log(runner) == [
            ("inner_done", 0.5), ("outer_done", 0.5), ("all", 0.5)
        ]

    def test_subroutines_share_the_scene_variable_scope(self):
        runner, _ = make_v2_runner(
            [
                {"call": "bump"},
                {"if": {"var": "n", "equals": 5,
                        "then": [{"event": {"emit": "shared"}}]}},
            ],
            variables={"n": 0},
            subroutines={"bump": [{"set": {"var": "n", "value": 5}}]},
        )
        runner.advance(0.0)
        assert event_log(runner) == [("shared", 0.0)]
        assert runner.variables["n"] == 5

    def test_subroutine_motion_drives_channels(self):
        runner, adapter = make_v2_runner(
            [{"call": "point"}],
            subroutines={
                "point": [{"pose": {"pan.rotation": 45.0},
                           "duration_s": 1.0}]
            },
        )
        assert runner.advance(1.0) is SceneResult.FINISHED
        assert channel(adapter, 0) == pytest.approx(1.0)


class TestInputs:
    def test_input_scalars_accepted(self):
        scene = make_scene(
            [], inputs={"a": True, "b": 3, "c": 1.5, "d": "text"}
        )
        assert scene.inputs == {"a": True, "b": 3, "c": 1.5, "d": "text"}

    @pytest.mark.parametrize("value", [None, [1]])
    def test_non_scalar_input_rejected(self, value):
        path = error_path(lambda: make_scene([], inputs={"a": value}))
        assert path == "inputs.a"

    def test_set_targeting_an_input_is_rejected(self):
        error = validate_error(
            [{"set": {"var": "door", "value": True}}],
            inputs={"door": False},
        )
        assert error.path == "sequence[0].set.var"
        assert "read-only" in error.message

    def test_name_in_both_namespaces_sets_the_variable(self):
        # Namespaces are distinct and every reference is explicit, so
        # an overlapping name is legal; `set` targets the variable.
        runner, _ = make_v2_runner(
            [{"set": {"var": "door", "value": "opened"}}],
            variables={"door": "closed"},
            inputs={"door": False},
        )
        runner.advance(0.0)
        assert runner.variables["door"] == "opened"
        assert runner.inputs["door"] is False

    def test_condition_input_must_be_declared(self):
        error = validate_error(
            [{"if": {"when": {"input": "ghost", "op": "eq", "value": 1},
                     "then": []}}]
        )
        assert error.path == "sequence[0].if.when.input"
        assert "undeclared input" in error.message

    def test_condition_var_never_resolves_to_an_input(self):
        # `var:` reads variables only — an input needs an input: leaf.
        error = validate_error(
            [{"if": {"when": {"var": "door", "op": "eq", "value": 1},
                     "then": []}}],
            inputs={"door": False},
        )
        assert error.path == "sequence[0].if.when.var"

    def test_set_input_unknown_name_is_a_typed_error(self):
        runner, _ = make_v2_runner([], inputs={"door": False})
        with pytest.raises(SceneRuntimeError, match="unknown input"):
            runner.set_input("ghost", True)

    def test_set_input_value_must_be_scalar(self):
        runner, _ = make_v2_runner([], inputs={"door": False})
        with pytest.raises(SceneRuntimeError, match="boolean, number"):
            runner.set_input("door", [1])

    def test_set_input_applies_at_the_next_tick_boundary(self):
        runner, _ = make_v2_runner(
            [
                {"wait_until": {"when": {"input": "go", "op": "eq",
                                         "value": True}}},
                {"event": {"emit": "passed"}},
            ],
            inputs={"go": False},
        )
        assert runner.advance(1.0) is None
        runner.set_input("go", True)
        assert runner.inputs["go"] is False  # pending until the tick
        assert runner.advance(2.0) is SceneResult.FINISHED
        assert event_log(runner) == [("passed", 2.0)]
        assert runner.inputs["go"] is True

    def test_last_set_input_before_the_tick_wins(self):
        runner, _ = make_v2_runner(
            [{"wait": {"seconds": 5.0}}], inputs={"zone": 0}
        )
        runner.advance(0.0)
        runner.set_input("zone", 1)
        runner.set_input("zone", 2)
        runner.advance(1.0)
        assert runner.inputs["zone"] == 2


class TestWaitUntil:
    GO = {"input": "go", "op": "eq", "value": True}

    def test_requires_when(self):
        path = error_path(lambda: make_scene([{"wait_until": {}}]))
        assert path == "sequence[0].wait_until.when"

    def test_timeout_must_be_positive(self):
        path = error_path(
            lambda: make_scene(
                [{"wait_until": {"when": dict(self.GO), "timeout_s": 0}}]
            )
        )
        assert path == "sequence[0].wait_until.timeout_s"

    def test_on_timeout_requires_a_timeout(self):
        path = error_path(
            lambda: make_scene(
                [{"wait_until": {"when": dict(self.GO),
                                 "on_timeout": "skip"}}]
            )
        )
        assert path == "sequence[0].wait_until.on_timeout"

    def test_on_timeout_value_is_closed(self):
        path = error_path(
            lambda: make_scene(
                [{"wait_until": {"when": dict(self.GO), "timeout_s": 1.0,
                                 "on_timeout": "retry"}}]
            )
        )
        assert path == "sequence[0].wait_until.on_timeout"

    def test_rejects_unknown_field(self):
        path = error_path(
            lambda: make_scene(
                [{"wait_until": {"when": dict(self.GO), "event": "go"}}]
            )
        )
        assert path == "sequence[0].wait_until.event"

    def test_already_true_condition_never_waits(self):
        # Level-triggered: unlike wait_for's edge-triggered events, a
        # condition that already holds passes the moment it is reached.
        runner, _ = make_v2_runner(
            [
                {"wait": {"seconds": 0.5}},
                {"wait_until": {"when": dict(self.GO)}},
                {"event": {"emit": "passed"}},
            ],
            inputs={"go": True},
        )
        assert runner.advance(0.5) is SceneResult.FINISHED
        assert event_log(runner) == [("passed", 0.5)]

    def test_passes_at_the_tick_where_the_condition_holds(self):
        runner, _ = make_v2_runner(
            [{"parallel": {"tracks": [
                [{"wait": {"seconds": 0.5}},
                 {"set": {"var": "flag", "value": True}}],
                [{"wait_until": {"when": {"var": "flag", "op": "eq",
                                          "value": True}}},
                 {"event": {"emit": "woke"}}],
            ]}}],
            variables={"flag": False},
        )
        assert runner.advance(0.5) is SceneResult.FINISHED
        assert event_log(runner) == [("woke", 0.5)]

    def test_coarse_tick_samples_at_the_tick_time(self):
        # The condition became true at 0.5 scene time, but conditions
        # are sampled per tick: a single coarse advance observes it at
        # the tick's time (documented ceiling).
        runner, _ = make_v2_runner(
            [{"parallel": {"tracks": [
                [{"wait": {"seconds": 0.5}},
                 {"set": {"var": "flag", "value": True}}],
                [{"wait_until": {"when": {"var": "flag", "op": "eq",
                                          "value": True}}},
                 {"event": {"emit": "woke"}}],
            ]}}],
            variables={"flag": False},
        )
        assert runner.advance(2.0) is SceneResult.FINISHED
        assert event_log(runner) == [("woke", 2.0)]

    def test_without_timeout_waits_indefinitely(self):
        runner, _ = make_v2_runner(
            [{"wait_until": {"when": dict(self.GO)}}],
            inputs={"go": False},
        )
        assert runner.advance(100.0) is None

    def test_timeout_skip_continues_at_the_deadline(self):
        runner, _ = make_v2_runner(
            [
                {"wait_until": {"when": dict(self.GO), "timeout_s": 1.0}},
                {"event": {"emit": "after"}},
            ],
            inputs={"go": False},
        )
        assert runner.advance(2.0) is SceneResult.FINISHED
        assert event_log(runner) == [("after", 1.0)]

    def test_timeout_end_ends_the_scene(self):
        runner, _ = make_v2_runner(
            [{"wait_until": {"when": dict(self.GO), "timeout_s": 1.0,
                             "on_timeout": "end"}}],
            inputs={"go": False},
        )
        assert runner.advance(0.5) is None
        assert runner.advance(2.0) is SceneResult.ENDED_BY_GATE_TIMEOUT

    def test_deadline_that_passed_earlier_beats_a_late_condition(self):
        # The deadline (1.0) precedes the tick (2.0) where the input
        # change is first observable — the timeout wins.
        runner, _ = make_v2_runner(
            [{"wait_until": {"when": dict(self.GO), "timeout_s": 1.0,
                             "on_timeout": "end"}}],
            inputs={"go": False},
        )
        assert runner.advance(0.5) is None
        runner.set_input("go", True)
        assert runner.advance(2.0) is SceneResult.ENDED_BY_GATE_TIMEOUT

    def test_condition_wins_a_tie_with_the_deadline(self):
        runner, _ = make_v2_runner(
            [
                {"wait_until": {"when": dict(self.GO), "timeout_s": 1.0,
                                "on_timeout": "end"}},
                {"event": {"emit": "passed"}},
            ],
            inputs={"go": False},
        )
        assert runner.advance(0.5) is None
        runner.set_input("go", True)
        assert runner.advance(1.0) is SceneResult.FINISHED
        assert event_log(runner) == [("passed", 1.0)]


class TestMonitorParsing:
    def monitor(self, **overrides):
        entry = {
            "name": "estop",
            "when": {"input": "estop", "op": "eq", "value": True},
            "do": [{"set": {"var": "x", "value": 1}}],
        }
        entry.update(overrides)
        return entry

    def build(self, monitors, sequence=(), **overrides):
        return make_scene(list(sequence), monitors=monitors, **overrides)

    def test_monitors_must_be_a_list(self):
        assert error_path(lambda: self.build({})) == "monitors"

    @pytest.mark.parametrize("missing", ["name", "when", "do"])
    def test_monitor_required_fields(self, missing):
        entry = self.monitor()
        del entry[missing]
        path = error_path(lambda: self.build([entry]))
        assert path == f"monitors[0].{missing}"

    def test_monitor_rejects_unknown_field(self):
        path = error_path(
            lambda: self.build([self.monitor(priority=1)])
        )
        assert path == "monitors[0].priority"

    def test_monitor_do_must_not_be_empty(self):
        path = error_path(lambda: self.build([self.monitor(do=[])]))
        assert path == "monitors[0].do"

    def test_duplicate_monitor_names_rejected(self):
        with pytest.raises(SceneFormatError) as info:
            self.build([self.monitor(), self.monitor()])
        assert info.value.path == "monitors[1].name"
        assert "duplicate" in info.value.message

    @pytest.mark.parametrize(
        "action",
        [
            {"clip": "sweep"},
            {"pose": {"pan.rotation": 1.0}, "duration_s": 1.0},
            {"wait": {"seconds": 1.0}},
            {"wait_for": {"event": "go"}},
            {"wait_until": {"when": {"var": "x", "op": "eq", "value": 1}}},
            {"if": {"var": "x", "equals": 1, "then": []}},
            {"select": {"var": "x", "cases": [{"equals": 1, "then": []}]}},
            {"loop": {"count": 1, "body": [{"wait": {"seconds": 1.0}}]}},
            {"parallel": {"tracks": [[]]}},
            {"call": "wave"},
        ],
    )
    def test_motion_and_flow_actions_rejected_in_monitor_bodies(
        self, action
    ):
        key = next(iter(action))
        with pytest.raises(SceneFormatError) as info:
            self.build([self.monitor(do=[action])])
        assert info.value.path == f"monitors[0].do[0].{key}"
        assert "not allowed in a monitor body" in info.value.message
        assert "PLC" in info.value.message

    def test_deferred_actions_also_named_in_monitor_bodies(self):
        path = error_path(
            lambda: self.build([self.monitor(do=[{"speak": "hi"}])])
        )
        assert path == "monitors[0].do[0].speak"

    def test_unknown_action_in_monitor_body(self):
        with pytest.raises(SceneFormatError) as info:
            self.build([self.monitor(do=[{"dance": 1}])])
        assert info.value.path == "monitors[0].do[0].dance"
        assert "monitor bodies allow" in info.value.message

    def test_two_actions_in_one_monitor_entry(self):
        path = error_path(
            lambda: self.build(
                [self.monitor(do=[{"set": {"var": "x", "value": 1},
                                   "event": {"emit": "y"}}])]
            )
        )
        assert path == "monitors[0].do[0]"

    def test_end_scene_requires_a_non_empty_result_string(self):
        for block in ({}, {"result": ""}, {"result": 5}):
            path = error_path(
                lambda b=block: self.build(
                    [self.monitor(do=[{"end_scene": b}])]
                )
            )
            assert path == "monitors[0].do[0].end_scene.result"

    def test_monitor_condition_and_set_are_validated(self):
        error = validate_error(
            [],
            monitors=[{
                "name": "m",
                "when": {"var": "ghost", "op": "eq", "value": 1},
                "do": [{"set": {"var": "x", "value": 1}}],
            }],
        )
        assert error.path == "monitors[0].when.var"
        error = validate_error(
            [],
            inputs={"estop": False},
            monitors=[{
                "name": "m",
                "when": {"input": "estop", "op": "eq", "value": True},
                "do": [{"set": {"var": "estop", "value": 1}}],
            }],
        )
        assert error.path == "monitors[0].do[0].set.var"
        assert "read-only" in error.message


class TestMonitorSemantics:
    def alarm_runner(self, do, sequence=None, variables=None):
        return make_v2_runner(
            sequence if sequence is not None
            else [{"wait": {"seconds": 100.0}}],
            variables,
            inputs={"alarm": False},
            monitors=[{
                "name": "watch",
                "when": {"input": "alarm", "op": "eq", "value": True},
                "do": do,
            }],
        )

    def test_edge_trigger_fires_once_then_rearms(self):
        runner, _ = self.alarm_runner([{"event": {"emit": "ding"}}])
        runner.advance(1.0)
        assert event_log(runner) == []
        runner.set_input("alarm", True)
        runner.advance(2.0)
        runner.advance(3.0)  # still true: no refire
        assert event_log(runner) == [("ding", 2.0)]
        runner.set_input("alarm", False)
        runner.advance(4.0)  # goes false: re-arms
        runner.set_input("alarm", True)
        runner.advance(5.0)
        assert event_log(runner) == [("ding", 2.0), ("ding", 5.0)]

    def test_condition_true_at_the_first_tick_fires(self):
        runner, _ = make_v2_runner(
            [{"wait": {"seconds": 1.0}}],
            inputs={"alarm": True},
            monitors=[{
                "name": "watch",
                "when": {"input": "alarm", "op": "eq", "value": True},
                "do": [{"event": {"emit": "ding"}}],
            }],
        )
        runner.advance(0.0)
        assert event_log(runner) == [("ding", 0.0)]

    def test_monitor_set_applies_before_the_main_sequence(self):
        # The monitor clears the loop variable at the top of the tick,
        # so the loop's 1.0 s boundary check already sees it.
        runner, _ = self.alarm_runner(
            [{"set": {"var": "run", "value": False}}],
            sequence=[
                {"loop": {"while_var": "run",
                          "body": [{"wait": {"seconds": 1.0}}]}},
                {"event": {"emit": "done"}},
            ],
            variables={"run": True},
        )
        assert runner.advance(0.5) is None
        runner.set_input("alarm", True)
        assert runner.advance(1.0) is SceneResult.FINISHED
        assert event_log(runner) == [("done", 1.0)]
        assert runner.variables["run"] is False

    def test_end_scene_stops_motion_mid_clip(self):
        runner, adapter = self.alarm_runner(
            [{"event": {"emit": "bang"}},
             {"end_scene": {"result": "estop"}}],
            sequence=[{"clip": "sweep"}],
        )
        assert runner.advance(0.25) is None
        assert not adapter.stopped
        frames = len(adapter.frames)
        runner.set_input("alarm", True)
        assert runner.advance(0.5) == "estop"
        assert runner.result == "estop"
        assert adapter.stopped
        assert len(adapter.frames) == frames  # ending sends no frame
        assert event_log(runner) == [("bang", 0.5)]
        assert runner.advance(1.0) == "estop"  # sticky, still no frames
        assert len(adapter.frames) == frames

    def test_actions_after_end_scene_do_not_run(self):
        runner, _ = self.alarm_runner(
            [{"end_scene": {"result": "estop"}},
             {"event": {"emit": "never"}}]
        )
        runner.set_input("alarm", True)
        assert runner.advance(0.0) == "estop"
        assert event_log(runner) == []

    def test_monitors_do_not_keep_the_scene_alive(self):
        runner, _ = self.alarm_runner([{"event": {"emit": "ding"}}],
                                      sequence=[])
        assert runner.advance(0.0) is SceneResult.FINISHED

    def test_monitor_events_reach_the_on_event_callback(self):
        calls: list[tuple[str, float]] = []
        adapter = RecordingAdapter()
        runner = SceneRunner(
            make_scene(
                [{"wait": {"seconds": 5.0}}],
                inputs={"alarm": False},
                monitors=[{
                    "name": "watch",
                    "when": {"input": "alarm", "op": "eq", "value": True},
                    "do": [{"event": {"emit": "ding"}}],
                }],
            ),
            RIG,
            adapter,
            on_event=lambda name, time_s: calls.append((name, time_s)),
        )
        runner.set_input("alarm", True)
        runner.advance(1.0)
        assert calls == [("ding", 1.0)]


class TestPatrolAndGreetExample:
    """End-to-end: the v2 example through the simulator adapter."""

    SCENE_PATH = EXAMPLES_DIR / "patrol_and_greet.scene.anima"

    def make_runner(self):
        scene, rig = load_scene_file(self.SCENE_PATH)
        adapter = SimulatorOutput(SimulatedDevice(channel_count=8))
        adapter.open(
            [
                ChannelConfig(
                    channel=index,
                    pin=2 + index,
                    min_us=600,
                    max_us=2400,
                    failsafe_ms=60_000,
                )
                for index in range(6)
            ]
        )
        return SceneRunner(scene, rig, adapter), adapter

    @staticmethod
    def drive(runner, adapter, time_s):
        result = runner.advance(time_s)
        adapter.device.tick(int(round(time_s * 1000)) + 33)
        return result

    def test_scene_and_character_load(self):
        scene, rig = load_scene_file(self.SCENE_PATH)
        assert scene.identity.name == "patrol_and_greet"
        assert rig.identity.name == "six_axis_arm"
        assert scene.variables == {"mode": "wave"}
        assert scene.inputs == {
            "door_open": False, "visitor_zone": 0, "estop": False
        }
        assert set(scene.subroutines) == {"wave", "park"}
        assert [monitor.name for monitor in scene.monitors] == ["estop"]

    def test_no_visitor_runs_the_show_after_the_gate_timeout(self):
        runner, adapter = self.make_runner()
        wrist = adapter.device.channel_value  # ch4: (deg+180)/360

        assert self.drive(runner, adapter, 5.0) is None  # still gated
        assert wrist(4) == pytest.approx(0.5, abs=1e-3)

        # The gate times out (skip) at 6.0; the first wave call's
        # first pose peaks at 45 deg at 6.25.
        assert self.drive(runner, adapter, 6.25) is None
        assert wrist(4) == pytest.approx(225.0 / 360.0, abs=1e-3)

        # The second call site's first peak: 7.0 + 0.25.
        assert self.drive(runner, adapter, 7.25) is None
        assert wrist(4) == pytest.approx(225.0 / 360.0, abs=1e-3)

        # Park (0.5 s from 8.0) finishes the show at 8.5.
        assert self.drive(runner, adapter, 8.5) is SceneResult.FINISHED
        assert wrist(4) == pytest.approx(0.5, abs=1e-3)
        assert adapter.device.channel_value(0) == pytest.approx(
            0.5, abs=1e-3
        )
        events = [(event.name, event.time_s)
                  for event in runner.emitted_events]
        assert events == [("scene_started", 0.0), ("scene_finished", 8.5)]

    def test_visitor_inputs_open_the_gate(self):
        runner, adapter = self.make_runner()
        assert self.drive(runner, adapter, 1.0) is None
        runner.set_input("door_open", True)
        runner.set_input("visitor_zone", 2)

        # Inputs apply at the 2.0 tick; the level-triggered gate
        # passes there and the first wave peak lands at 2.25.
        assert self.drive(runner, adapter, 2.0) is None
        assert self.drive(runner, adapter, 2.25) is None
        assert adapter.device.channel_value(4) == pytest.approx(
            225.0 / 360.0, abs=1e-3
        )

        # wave (2.0-3.0) + wave (3.0-4.0) + park (4.0-4.5).
        assert self.drive(runner, adapter, 4.5) is SceneResult.FINISHED
        finished = runner.emitted_events[-1]
        assert finished.name == "scene_finished"
        assert finished.time_s == pytest.approx(4.5)

    def test_estop_monitor_ends_the_show(self):
        runner, adapter = self.make_runner()
        assert self.drive(runner, adapter, 1.0) is None
        runner.set_input("estop", True)
        assert runner.advance(1.5) == "estop"
        assert runner.result == "estop"
        events = [(event.name, event.time_s)
                  for event in runner.emitted_events]
        assert events == [("scene_started", 0.0), ("estop_tripped", 1.5)]
        assert runner.advance(2.0) == "estop"
