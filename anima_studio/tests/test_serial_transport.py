"""SerialWireOutput over a real pyserial ``loop://`` port.

The test port is genuine pyserial: host bytes travel through the
``loop://`` handler's buffer and come back out with real newline
framing. Because ``loop://`` is single-ended (one shared buffer), the
in-test responder runs inside ``write()``: it drains the host's line,
hands it to the REAL ``SimulatedDevice`` (zero protocol duplication),
and places the reply bytes on the loop for the host's next read.
Deterministic, no threads, no sleeps beyond pyserial's own timeouts.
"""

import pytest
import serial
import yaml

from anima_studio import serial_transport
from anima_studio.loader import parse_character
from anima_studio.outputs import ChannelConfig, OutputAdapter
from anima_studio.rig import evaluate_pose, project_channels
from anima_studio.serial_transport import (
    DeviceRejectedError,
    HandshakeError,
    ProtocolError,
    ReplyTimeoutError,
    SerialWireOutput,
)
from anima_studio.sim import SimulatedDevice
from anima_studio.wire import ERR_NOT_CONFIGURED

CHANNEL_CONFIGS = (
    ChannelConfig(channel=0, pin=9, min_us=600, max_us=2400),
    ChannelConfig(channel=1, pin=10, min_us=600, max_us=2400, neutral=0.0),
)

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


class RespondingLoopPort:
    """Real ``loop://`` serial with an in-test device on the far end.

    ``loop://`` is single-ended, so the responder runs inside
    ``write()``: the host's just-written line is drained back off the
    loop, handed to ``respond`` (a ``str -> bytes | None`` callable —
    ``None`` means stay silent), and the reply bytes go onto the loop
    for the host's subsequent ``read_until``.
    """

    def __init__(self, respond):
        self._loop = serial.serial_for_url("loop://", timeout=0.25)
        self._respond = respond
        self.lines_seen: list[str] = []

    @property
    def timeout(self):
        return self._loop.timeout

    @timeout.setter
    def timeout(self, value):
        self._loop.timeout = value

    def write(self, data: bytes) -> int:
        written = self._loop.write(data)
        line = self._loop.read_until(b"\n")
        self.lines_seen.append(line.decode("utf-8").rstrip("\n"))
        reply = self._respond(self.lines_seen[-1])
        if reply is not None:
            self._loop.write(reply)
        return written

    def read_until(self, expected=b"\n", size=None):
        return self._loop.read_until(expected, size)

    def close(self):
        self._loop.close()


def sim_responder(device: SimulatedDevice):
    def respond(line: str) -> bytes:
        return (device.receive_line(line) + "\n").encode("utf-8")

    return respond


def make_adapter(monkeypatch, respond, **kwargs):
    """Build a SerialWireOutput whose serial_for_url yields the loop port."""
    port = RespondingLoopPort(respond)
    captured = {}

    def fake_serial_for_url(url, **kw):
        captured["url"] = url
        captured.update(kw)
        return port

    monkeypatch.setattr(
        serial_transport.serial, "serial_for_url", fake_serial_for_url
    )
    kwargs.setdefault("handshake_timeout_s", 0.25)
    kwargs.setdefault("reply_timeout_s", 0.25)
    adapter = SerialWireOutput("loop://", **kwargs)
    return adapter, port, captured


def make_open_adapter(monkeypatch, channel_count: int = 4):
    device = SimulatedDevice(channel_count=channel_count)
    adapter, port, _ = make_adapter(monkeypatch, sim_responder(device))
    adapter.open(CHANNEL_CONFIGS)
    return adapter, port, device


class TestContract:
    def test_implements_the_output_adapter_protocol(self):
        assert issubclass(SerialWireOutput, OutputAdapter)


class TestOpen:
    def test_open_sends_exact_handshake_cfg_en_sequence(self, monkeypatch):
        _, port, device = make_open_adapter(monkeypatch)
        assert port.lines_seen == [
            "HELLO,0",
            "CFG,0,servo,pin=9,min_us=600,max_us=2400",
            "EN,0,1",
            "CFG,1,servo,pin=10,min_us=600,max_us=2400,neutral=0.000",
            "EN,1,1",
        ]
        for config in CHANNEL_CONFIGS:
            assert device.channel_enabled(config.channel)

    def test_open_passes_port_url_baudrate_and_timeout(self, monkeypatch):
        adapter, _, captured = make_adapter(
            monkeypatch, sim_responder(SimulatedDevice())
        )
        adapter.open(CHANNEL_CONFIGS)
        assert captured["url"] == "loop://"
        assert captured["baudrate"] == 115200
        assert captured["timeout"] == 0.25

    def test_open_records_the_device_hello(self, monkeypatch):
        adapter, _, device = make_open_adapter(monkeypatch)
        assert adapter.device_hello is not None
        assert adapter.device_hello.device_name == "anima-sim"
        assert adapter.device_hello.channel_count == 4

    def test_wrong_protocol_version_is_a_handshake_error(self, monkeypatch):
        adapter, _, _ = make_adapter(
            monkeypatch, lambda line: b"ANIMA,1,imposter,8\n"
        )
        with pytest.raises(HandshakeError, match="protocol v1"):
            adapter.open(CHANNEL_CONFIGS)

    def test_non_anima_reply_is_a_handshake_error(self, monkeypatch):
        adapter, _, _ = make_adapter(monkeypatch, lambda line: b"OK\n")
        with pytest.raises(HandshakeError, match="expected ANIMA"):
            adapter.open(CHANNEL_CONFIGS)

    def test_err_reply_to_hello_carries_the_device_code(self, monkeypatch):
        adapter, _, _ = make_adapter(
            monkeypatch, lambda line: b"ERR,3,bad-protocol-version\n"
        )
        with pytest.raises(DeviceRejectedError) as excinfo:
            adapter.open(CHANNEL_CONFIGS)
        assert excinfo.value.code == 3
        assert excinfo.value.device_message == "bad-protocol-version"


class TestSendFrame:
    def test_frame_moves_the_simulated_servos(self, monkeypatch):
        adapter, port, device = make_open_adapter(monkeypatch)
        adapter.send_frame({0: 0.25, 1: 1.0}, duration_ms=0)
        assert port.lines_seen[-1] == "FRM,0,0:0.250,1:1.000"
        assert device.channel_value(0) == 0.25
        assert device.channel_value(1) == 1.0

    def test_frame_interpolates_on_the_device_clock(self, monkeypatch):
        adapter, _, device = make_open_adapter(monkeypatch)
        adapter.send_frame({0: 1.0}, duration_ms=100)  # from neutral 0.5
        device.tick(50)
        assert device.channel_value(0) == pytest.approx(0.75)

    def test_err_reply_raises_with_the_device_code(self, monkeypatch):
        adapter, _, _ = make_open_adapter(monkeypatch)
        with pytest.raises(DeviceRejectedError) as excinfo:
            adapter.send_frame({3: 0.5}, duration_ms=0)  # not configured
        assert excinfo.value.code == ERR_NOT_CONFIGURED
        assert excinfo.value.device_message == "not-configured"
        assert excinfo.value.command.startswith("FRM,")


class TestBadReplies:
    def test_silent_device_is_a_reply_timeout(self, monkeypatch):
        adapter, _, _ = make_adapter(
            monkeypatch,
            lambda line: None,
            handshake_timeout_s=0.05,
            reply_timeout_s=0.05,
        )
        with pytest.raises(ReplyTimeoutError, match="HELLO"):
            adapter.open(CHANNEL_CONFIGS)

    def test_undecodable_reply_is_a_protocol_error(self, monkeypatch):
        adapter, _, _ = make_adapter(monkeypatch, lambda line: b"\xff\xfe\n")
        with pytest.raises(ProtocolError, match="undecodable"):
            adapter.open(CHANNEL_CONFIGS)

    def test_unparseable_reply_is_a_protocol_error(self, monkeypatch):
        adapter, _, _ = make_adapter(monkeypatch, lambda line: b"BOGUS\n")
        with pytest.raises(ProtocolError, match="unparseable"):
            adapter.open(CHANNEL_CONFIGS)

    def test_oversized_garbage_is_a_protocol_error(self, monkeypatch):
        adapter, _, _ = make_adapter(monkeypatch, lambda line: b"X" * 600)
        with pytest.raises(ProtocolError, match="oversized"):
            adapter.open(CHANNEL_CONFIGS)

    def test_wrong_reply_type_to_a_command_is_a_protocol_error(
        self, monkeypatch
    ):
        device = SimulatedDevice()

        def respond(line: str):
            if line.startswith("HELLO"):
                return (device.receive_line(line) + "\n").encode()
            return b"PONG\n"

        adapter, _, _ = make_adapter(monkeypatch, respond)
        with pytest.raises(ProtocolError, match="expected OK"):
            adapter.open(CHANNEL_CONFIGS)


class TestStopAndClose:
    def test_stop_before_open_is_a_quiet_no_op(self, monkeypatch):
        adapter, _, _ = make_adapter(
            monkeypatch, sim_responder(SimulatedDevice())
        )
        adapter.stop()
        assert adapter.last_error is None

    def test_stop_disables_every_output_and_is_idempotent(self, monkeypatch):
        adapter, port, device = make_open_adapter(monkeypatch)
        adapter.stop()
        adapter.stop()
        assert port.lines_seen[-2:] == ["STOP", "STOP"]
        assert adapter.last_error is None
        for config in CHANNEL_CONFIGS:
            assert not device.channel_enabled(config.channel)

    def test_stop_after_close_swallows_and_records_the_error(
        self, monkeypatch
    ):
        adapter, _, _ = make_open_adapter(monkeypatch)
        adapter.close()
        adapter.stop()  # dead port during e-stop must not raise
        assert isinstance(adapter.last_error, Exception)

    def test_close_is_not_stop(self, monkeypatch):
        adapter, _, device = make_open_adapter(monkeypatch)
        adapter.close()
        assert device.channel_enabled(0)  # failsafe's job, not close's


class TestEndToEnd:
    def test_rig_evaluation_streams_over_the_wire_to_servos(
        self, monkeypatch
    ):
        """rig evaluate → project_channels → serial bytes → sim servos."""
        rig = parse_character(yaml.safe_dump(CHARACTER_DOCUMENT))
        adapter, _, device = make_open_adapter(monkeypatch)
        for time_seconds, expected_pan, expected_glow in (
            (0.0, 0.0, 0.0),
            (0.5, 0.5, 0.5),
            (1.0, 1.0, 1.0),
        ):
            pose = evaluate_pose(rig, "sweep", time_seconds)
            channels = project_channels(rig, pose)
            adapter.send_frame(channels, duration_ms=0)
            assert device.channel_value(0) == pytest.approx(
                expected_pan, abs=1e-3
            )
            assert device.channel_value(1) == pytest.approx(
                expected_glow, abs=1e-3
            )
        adapter.stop()
        assert not device.channel_enabled(0)
        assert not device.channel_enabled(1)
