"""Anima Wire Protocol v0 host: encoding and reply parsing."""

import pytest

from anima_studio.wire import (
    Err,
    Hello,
    Ok,
    Pong,
    WireError,
    encode_cfg,
    encode_en,
    encode_frm,
    encode_hello,
    encode_ping,
    encode_stop,
    format_value,
    parse_reply,
)


class TestFormatValue:
    def test_three_decimal_places(self):
        assert format_value(0.5) == "0.500"
        assert format_value(0.0) == "0.000"
        assert format_value(1.0) == "1.000"
        assert format_value(0.12345) == "0.123"

    @pytest.mark.parametrize("value", [-0.001, 1.001, float("nan")])
    def test_out_of_range_rejected(self, value):
        with pytest.raises(WireError):
            format_value(value)


class TestEncode:
    def test_hello(self):
        assert encode_hello() == "HELLO,0"

    def test_cfg_matches_spec_example(self):
        line = encode_cfg(0, pin=9, min_us=600, max_us=2400, neutral=0.5)
        assert line == "CFG,0,servo,pin=9,min_us=600,max_us=2400,neutral=0.500"

    def test_cfg_optional_keys(self):
        line = encode_cfg(3, pin=5, min_us=500, max_us=2500, invert=True,
                          failsafe_ms=1000)
        assert line == (
            "CFG,3,servo,pin=5,min_us=500,max_us=2500,invert=1,failsafe_ms=1000"
        )

    def test_cfg_rejects_bad_pulse_range(self):
        with pytest.raises(WireError):
            encode_cfg(0, pin=9, min_us=2400, max_us=600)

    def test_frm_matches_spec_example(self):
        assert encode_frm(33, {0: 0.5, 1: 0.25}) == "FRM,33,0:0.500,1:0.250"

    def test_frm_sorts_channels(self):
        assert encode_frm(0, {2: 1.0, 0: 0.0}) == "FRM,0,0:0.000,2:1.000"

    def test_frm_rejects_empty_targets(self):
        with pytest.raises(WireError):
            encode_frm(33, {})

    def test_frm_rejects_negative_duration(self):
        with pytest.raises(WireError):
            encode_frm(-1, {0: 0.5})

    def test_frm_rejects_out_of_range_value(self):
        with pytest.raises(WireError):
            encode_frm(33, {0: 1.5})

    def test_frm_rejects_negative_channel(self):
        with pytest.raises(WireError):
            encode_frm(33, {-1: 0.5})

    def test_en_stop_ping(self):
        assert encode_en(2, True) == "EN,2,1"
        assert encode_en(2, False) == "EN,2,0"
        assert encode_stop() == "STOP"
        assert encode_ping() == "PING"


class TestParseReply:
    def test_anima(self):
        reply = parse_reply("ANIMA,0,anima-sim,8")
        assert reply == Hello(protocol_version=0, device_name="anima-sim",
                              channel_count=8)

    def test_ok_and_pong(self):
        assert parse_reply("OK") == Ok()
        assert parse_reply("PONG") == Pong()

    def test_err(self):
        assert parse_reply("ERR,4,not-configured") == Err(4, "not-configured")

    def test_err_message_may_contain_commas(self):
        assert parse_reply("ERR,1,parse,extra").message == "parse,extra"

    def test_tolerates_trailing_line_ending(self):
        assert parse_reply("OK\r\n") == Ok()

    @pytest.mark.parametrize(
        "line",
        ["", "WAT", "OK,1", "ANIMA,0,name", "ANIMA,x,name,8", "ERR,x,msg", "ERR,1"],
    )
    def test_malformed_rejected(self, line):
        with pytest.raises(WireError):
            parse_reply(line)
