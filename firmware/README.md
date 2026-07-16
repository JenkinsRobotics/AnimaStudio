# Anima firmware v0

The open device-side implementation of the
[Anima Wire Protocol](../dev/docs/roadmap/Wire_Protocol.md) — our
equivalent of Bottango's firmware, Apache-2.0 like everything else.
One sketch, two boards: classic Arduino (AVR, stock `Servo.h`) and
ESP32 (built-in LEDC PWM at 50 Hz — no third-party libraries anywhere).

Up to 12 servo channels (`ANIMA_MAX_CHANNELS` in `config.h` — the AVR
Servo library's per-timer ceiling on an Uno; raise per board and
re-check RAM). Protocol behavior mirrors the reference simulator
(`anima_studio/sim.py`) exactly: channels start disabled after `CFG`
until `EN`, frames are atomic, only successfully parsed commands
refresh the failsafe heartbeat, and duplicate CFG keys / FRM channels
are rejected.

## Flash

```bash
# Arduino Uno / Nano (AVR)
arduino-cli compile --fqbn arduino:avr:uno firmware/anima_firmware
arduino-cli upload -p <port> --fqbn arduino:avr:uno firmware/anima_firmware

# ESP32
arduino-cli compile --fqbn esp32:esp32:esp32 firmware/anima_firmware
arduino-cli upload -p <port> --fqbn esp32:esp32:esp32 firmware/anima_firmware

# find <port> with the board plugged in:
ls /dev/tty.usbmodem* /dev/tty.usbserial* 2>/dev/null
```

## Wiring

- Servo **signal** → the pin you pass in `CFG` (e.g. pin 9).
- Servo **power** → an external 5–6 V supply rated for your servos —
  never the board's 5 V pin for anything beyond one micro servo.
- **Common ground** between the servo supply and the board. Always.

## Smoke test by hand (serial monitor, 115200, newline endings)

```
HELLO,0                                   → ANIMA,0,anima-avr,12
CFG,0,servo,pin=9,min_us=600,max_us=2400  → OK
EN,0,1                                    → OK   (servo snaps to neutral)
FRM,1000,0:1.000                          → OK   (sweeps to max over 1 s)
STOP                                      → OK   (signal detached)
```

## Smoke test from Python (the real host path)

```python
from anima_studio.serial_transport import SerialWireOutput
from anima_studio.outputs import ChannelConfig

out = SerialWireOutput("/dev/tty.usbmodemXXXX")  # handshake_timeout_s=3.0 if an Uno resets slowly
out.open([ChannelConfig(channel=0, pin=9, min_us=600, max_us=2400)])
out.send_frame({0: 1.0}, duration_ms=1000)
out.stop()
```

## Safety

- **Failsafe:** if no successfully parsed command arrives for
  `failsafe_ms` (default 2000, per channel via CFG), the channel
  disarms — a yanked cable never leaves a servo straining. Line noise
  does not keep the heartbeat alive.
- **STOP** disarms every channel immediately and is never queued.
- Channels stay disarmed after STOP or failsafe until re-enabled with
  `EN`.
