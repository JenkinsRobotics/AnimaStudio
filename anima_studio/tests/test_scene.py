"""`.scene.anima` v1: schema, rig validation, executor semantics."""

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
