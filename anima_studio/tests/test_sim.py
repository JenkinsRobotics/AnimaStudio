"""Simulated device: protocol handling, motion, failsafe, and the
end-to-end clip → wire → servo loop."""

import pytest

from anima_studio.clips import Clip, Interpolation, Keyframe, Track, evaluate_clip
from anima_studio.sim import SimulatedDevice
from anima_studio.wire import (
    ERR_BAD_CHANNEL,
    ERR_BAD_VALUE,
    ERR_NOT_CONFIGURED,
    ERR_PARSE,
    Err,
    Hello,
    Ok,
    encode_cfg,
    encode_en,
    encode_frm,
    encode_hello,
    encode_ping,
    encode_stop,
    parse_reply,
)

CFG_LINE = "CFG,0,servo,pin=9,min_us=600,max_us=2400,neutral=0.500"


def make_device(**kwargs) -> SimulatedDevice:
    return SimulatedDevice(channel_count=4, **kwargs)


def make_configured_device() -> SimulatedDevice:
    device = make_device()
    assert device.receive_line(CFG_LINE) == "OK"
    assert device.receive_line("EN,0,1") == "OK"
    return device


def assert_err(reply: str, code: int) -> None:
    parsed = parse_reply(reply)
    assert isinstance(parsed, Err)
    assert parsed.code == code


class TestHandshakeAndPing:
    def test_hello(self):
        device = make_device(device_name="testbot")
        reply = parse_reply(device.receive_line(encode_hello()))
        assert reply == Hello(protocol_version=0, device_name="testbot",
                              channel_count=4)

    def test_hello_wrong_version(self):
        assert_err(make_device().receive_line("HELLO,9"), ERR_BAD_VALUE)

    def test_ping(self):
        assert make_device().receive_line(encode_ping()) == "PONG"


class TestCfg:
    def test_sets_value_to_neutral_and_starts_disabled(self):
        device = make_device()
        assert device.receive_line(CFG_LINE) == "OK"
        assert device.channel_value(0) == 0.5
        assert not device.channel_enabled(0)

    def test_default_neutral_is_center(self):
        device = make_device()
        device.receive_line("CFG,0,servo,pin=9,min_us=600,max_us=2400")
        assert device.channel_value(0) == 0.5

    def test_bad_channel(self):
        assert_err(make_device().receive_line(
            "CFG,4,servo,pin=9,min_us=600,max_us=2400"), ERR_BAD_CHANNEL)

    def test_unparsable_channel(self):
        assert_err(make_device().receive_line(
            "CFG,x,servo,pin=9,min_us=600,max_us=2400"), ERR_PARSE)

    def test_unknown_type(self):
        assert_err(make_device().receive_line(
            "CFG,0,stepper,pin=9,min_us=600,max_us=2400"), ERR_BAD_VALUE)

    def test_missing_required_key(self):
        assert_err(make_device().receive_line(
            "CFG,0,servo,min_us=600,max_us=2400"), ERR_PARSE)

    def test_unknown_key(self):
        assert_err(make_device().receive_line(
            "CFG,0,servo,pin=9,min_us=600,max_us=2400,bogus=1"), ERR_PARSE)

    def test_neutral_out_of_range(self):
        assert_err(make_device().receive_line(
            "CFG,0,servo,pin=9,min_us=600,max_us=2400,neutral=1.5"), ERR_BAD_VALUE)

    def test_pulse_width_and_invert(self):
        device = make_device()
        device.receive_line("CFG,0,servo,pin=9,min_us=600,max_us=2400")
        device.receive_line("CFG,1,servo,pin=10,min_us=600,max_us=2400,invert=1")
        assert device.channel_pulse_us(0) == 1500.0
        device.receive_line("FRM,0,0:1.000,1:1.000")
        assert device.channel_pulse_us(0) == 2400.0
        assert device.channel_pulse_us(1) == 600.0


class TestFrm:
    def test_not_configured(self):
        assert_err(make_device().receive_line("FRM,33,0:0.500"),
                   ERR_NOT_CONFIGURED)

    def test_bad_channel(self):
        assert_err(make_configured_device().receive_line("FRM,33,4:0.500"),
                   ERR_BAD_CHANNEL)

    def test_value_out_of_range(self):
        assert_err(make_configured_device().receive_line("FRM,33,0:1.500"),
                   ERR_BAD_VALUE)

    def test_negative_duration(self):
        assert_err(make_configured_device().receive_line("FRM,-1,0:0.500"),
                   ERR_BAD_VALUE)

    def test_garbage(self):
        assert_err(make_configured_device().receive_line("FRM,33,0=0.500"),
                   ERR_PARSE)

    def test_zero_duration_jumps_now(self):
        device = make_configured_device()
        assert device.receive_line("FRM,0,0:0.900") == "OK"
        assert device.channel_value(0) == 0.9

    def test_linear_interpolation_toward_target(self):
        device = make_configured_device()
        device.receive_line("FRM,100,0:1.000")  # from neutral 0.5
        assert device.channel_value(0) == 0.5
        device.tick(50)
        assert device.channel_value(0) == pytest.approx(0.75)
        device.tick(100)
        assert device.channel_value(0) == 1.0
        device.tick(150)
        assert device.channel_value(0) == 1.0  # holds at target

    def test_retarget_starts_from_current_value(self):
        device = make_configured_device()
        device.receive_line("FRM,100,0:1.000")
        device.tick(50)  # at 0.75
        device.receive_line("FRM,100,0:0.750")  # already there
        device.tick(150)
        assert device.channel_value(0) == pytest.approx(0.75)

    def test_frame_is_atomic(self):
        device = make_configured_device()
        # Channel 1 unconfigured: the whole frame is rejected, 0 must not move.
        assert_err(device.receive_line("FRM,0,0:0.900,1:0.100"),
                   ERR_NOT_CONFIGURED)
        assert device.channel_value(0) == 0.5


class TestEnAndStop:
    def test_en_not_configured(self):
        assert_err(make_device().receive_line("EN,0,1"), ERR_NOT_CONFIGURED)

    def test_en_bad_flag(self):
        assert_err(make_configured_device().receive_line("EN,0,2"),
                   ERR_BAD_VALUE)

    def test_disable_cancels_motion(self):
        device = make_configured_device()
        device.receive_line("FRM,100,0:1.000")
        device.tick(50)
        device.receive_line("EN,0,0")
        device.tick(200)
        assert not device.channel_enabled(0)
        assert device.channel_value(0) == pytest.approx(0.75)  # frozen

    def test_stop_disables_every_output(self):
        device = make_device()
        device.receive_line(CFG_LINE)
        device.receive_line("CFG,1,servo,pin=10,min_us=600,max_us=2400")
        device.receive_line("EN,0,1")
        device.receive_line("EN,1,1")
        device.receive_line("FRM,100,0:1.000,1:0.000")
        assert device.receive_line(encode_stop()) == "OK"
        device.tick(200)
        assert not device.channel_enabled(0)
        assert not device.channel_enabled(1)
        assert device.channel_value(0) == 0.5  # motion cancelled


class TestFailsafe:
    def test_silence_disables_outputs(self):
        device = make_configured_device()
        device.tick(1999)
        assert device.channel_enabled(0)
        device.tick(2000)
        assert not device.channel_enabled(0)

    def test_any_traffic_resets_the_timer(self):
        device = make_configured_device()
        device.tick(1500)
        device.receive_line(encode_ping())
        device.tick(3000)  # only 1500ms since the PING
        assert device.channel_enabled(0)
        device.tick(3500)
        assert not device.channel_enabled(0)

    def test_custom_failsafe_ms(self):
        device = make_device()
        device.receive_line(
            "CFG,0,servo,pin=9,min_us=600,max_us=2400,failsafe_ms=500")
        device.receive_line("EN,0,1")
        device.tick(500)
        assert not device.channel_enabled(0)


class TestLines:
    def test_unknown_command(self):
        assert_err(make_device().receive_line("WAT,1"), ERR_PARSE)

    def test_time_going_backwards_raises(self):
        device = make_device(now_ms=100)
        with pytest.raises(ValueError):
            device.tick(50)

    def test_unconfigured_channel_query_raises(self):
        with pytest.raises(KeyError):
            make_device().channel_value(0)


class TestEndToEnd:
    def test_clip_streams_to_simulated_servos_then_failsafe(self):
        """Evaluate a 2-track clip at 30 Hz, stream FRM lines into the
        simulator, assert the servos follow the clip, then go silent and
        assert the failsafe disables the outputs."""
        clip = Clip(
            name="wave",
            duration_seconds=1.0,
            tracks={
                0: Track(keyframes=(
                    Keyframe(time_seconds=0.0, value=0.1),
                    Keyframe(time_seconds=1.0, value=0.9),
                )),
                1: Track(keyframes=(
                    Keyframe(time_seconds=0.0, value=1.0),
                    Keyframe(time_seconds=0.5, value=0.0,
                             interpolation=Interpolation.HOLD),
                    Keyframe(time_seconds=1.0, value=0.4),
                )),
            },
        )

        device = SimulatedDevice(channel_count=2)
        hello = parse_reply(device.receive_line(encode_hello()))
        assert isinstance(hello, Hello) and hello.channel_count == 2
        for channel, pin in ((0, 9), (1, 10)):
            line = encode_cfg(channel, pin=pin, min_us=600, max_us=2400)
            assert isinstance(parse_reply(device.receive_line(line)), Ok)
            assert isinstance(
                parse_reply(device.receive_line(encode_en(channel, True))), Ok)

        frame_interval_ms = 33  # ~30 Hz
        frame_count = 31  # covers 0..990 ms of the 1 s clip
        for frame_index in range(frame_count):
            now_ms = frame_index * frame_interval_ms
            device.tick(now_ms)
            if frame_index > 0:
                # The previous frame's motion has completed: the servos sit
                # exactly on the clip values from one frame ago (within the
                # 3-decimal wire quantization).
                previous_seconds = (now_ms - frame_interval_ms) / 1000
                for channel, expected in evaluate_clip(
                        clip, previous_seconds).items():
                    assert device.channel_value(channel) == pytest.approx(
                        expected, abs=1e-3)
            targets = evaluate_clip(clip, now_ms / 1000)
            reply = device.receive_line(encode_frm(frame_interval_ms, targets))
            assert isinstance(parse_reply(reply), Ok)

        # The hold segment actually held: channel 1 sat at 0.0 mid-clip.
        assert evaluate_clip(clip, 0.75)[1] == 0.0

        # Silence: failsafe disables every output 2000 ms after the last line.
        last_line_ms = (frame_count - 1) * frame_interval_ms
        device.tick(last_line_ms + 1999)
        assert device.channel_enabled(0) and device.channel_enabled(1)
        device.tick(last_line_ms + 2000)
        assert not device.channel_enabled(0) and not device.channel_enabled(1)
