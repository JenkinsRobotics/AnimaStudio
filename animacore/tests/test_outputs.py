"""OutputAdapter contract and the built-in SimulatorOutput consumer."""

import pytest
import yaml

from animacore.loader import parse_character
from animacore.outputs import ChannelConfig, OutputAdapter, SimulatorOutput
from animacore.rig import evaluate_pose, project_channels
from animacore.sim import SimulatedDevice
from animacore.wire import WireError

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
    },
    "outputs": [
        {"target": "pan.rotation", "channel": 0, "range_deg": [-45, 45]},
        {"target": "glow", "channel": 1, "range": [0.0, 1.0]},
    ],
}

CHANNEL_CONFIGS = (
    ChannelConfig(channel=0, pin=9, min_us=600, max_us=2400),
    ChannelConfig(channel=1, pin=10, min_us=600, max_us=2400, neutral=0.0),
)


def make_open_adapter() -> SimulatorOutput:
    adapter = SimulatorOutput(SimulatedDevice(channel_count=4))
    adapter.open(CHANNEL_CONFIGS)
    return adapter


class TestContract:
    def test_simulator_output_implements_the_protocol(self):
        assert issubclass(SimulatorOutput, OutputAdapter)

    def test_partial_class_does_not_implement_the_protocol(self):
        class Half:
            def open(self, channel_configs):
                pass

            def close(self):
                pass

        assert not issubclass(Half, OutputAdapter)

    def test_channel_config_defaults(self):
        config = ChannelConfig(channel=0, pin=9, min_us=600, max_us=2400)
        assert not config.invert
        assert config.neutral is None
        assert config.failsafe_ms is None


class TestSimulatorOutput:
    def test_open_configures_and_arms_every_channel(self):
        adapter = make_open_adapter()
        for config in CHANNEL_CONFIGS:
            assert adapter.device.channel_enabled(config.channel)
        assert adapter.device.channel_value(0) == 0.5  # default neutral
        assert adapter.device.channel_value(1) == 0.0  # explicit neutral

    def test_send_frame_moves_the_simulated_servos(self):
        adapter = make_open_adapter()
        adapter.send_frame({0: 0.25, 1: 1.0}, duration_ms=0)
        assert adapter.device.channel_value(0) == 0.25
        assert adapter.device.channel_value(1) == 1.0

    def test_send_frame_interpolates_on_the_device_clock(self):
        adapter = make_open_adapter()
        adapter.send_frame({0: 1.0}, duration_ms=100)  # from neutral 0.5
        adapter.device.tick(50)
        assert adapter.device.channel_value(0) == pytest.approx(0.75)

    def test_stop_disables_every_output(self):
        adapter = make_open_adapter()
        adapter.send_frame({0: 1.0}, duration_ms=100)
        adapter.stop()
        for config in CHANNEL_CONFIGS:
            assert not adapter.device.channel_enabled(config.channel)

    def test_rejected_line_raises_wire_error(self):
        adapter = make_open_adapter()
        with pytest.raises(WireError):
            adapter.send_frame({3: 0.5}, duration_ms=0)  # not configured

    def test_bad_config_raises_before_reaching_the_device(self):
        adapter = SimulatorOutput()
        bad = ChannelConfig(channel=0, pin=9, min_us=2400, max_us=600)
        with pytest.raises(WireError):
            adapter.open([bad])

    def test_close_is_a_no_op_for_the_in_process_device(self):
        adapter = make_open_adapter()
        adapter.close()
        assert adapter.device.channel_enabled(0)  # close is not stop

    def test_rig_evaluation_streams_through_the_adapter(self):
        """rig evaluate → project_channels → send_frame → servo values."""
        rig = parse_character(yaml.safe_dump(CHARACTER_DOCUMENT))
        adapter = make_open_adapter()
        for time_seconds, expected_pan, expected_glow in (
            (0.0, 0.0, 0.0),
            (0.5, 0.5, 0.5),
            (1.0, 1.0, 1.0),
        ):
            pose = evaluate_pose(rig, "sweep", time_seconds)
            channels = project_channels(rig, pose)
            adapter.send_frame(channels, duration_ms=0)
            assert adapter.device.channel_value(0) == pytest.approx(
                expected_pan, abs=1e-3
            )
            assert adapter.device.channel_value(1) == pytest.approx(
                expected_glow, abs=1e-3
            )
        adapter.stop()
        assert not adapter.device.channel_enabled(0)
        assert not adapter.device.channel_enabled(1)
