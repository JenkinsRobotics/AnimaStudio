# Anima Wire Protocol v0 (draft)

> The host↔microcontroller contract — Anima's equivalent of the Bottango
> firmware protocol, but open and ours. Implemented by the Python
> reference host (`anima_studio/wire.py`), Studio's serial
> `AnimationOutput`, and the Arduino/ESP32 firmware. Change this doc
> first, implementations second (see `dev/briefings/` protocol).

## Transport

UTF-8 lines (`\n`-terminated) over USB serial, 115200 8N1. Also runs
unchanged over TCP for simulators. Fields are comma-separated; no
spaces. Commands are uppercase. v0 has no checksum — a known gap;
v1 adds one if line noise shows up in practice.

## Values

Channel values are normalized floats `0.0..1.0` — the same range as rig
blend shapes and joint parameters. Physical meaning (pulse width range,
angle range, inversion) is configured per channel with `CFG`, never
baked into animation data.

## Host → device

| Command | Meaning |
|---|---|
| `HELLO,0` | Handshake; `0` is the protocol version. Device replies `ANIMA,...`. |
| `CFG,<ch>,<type>,<k=v>,...` | Configure channel. v0 type: `servo`. Keys: `pin`, `min_us`, `max_us`, `invert=0/1`, `neutral` (0..1). Ex: `CFG,0,servo,pin=9,min_us=600,max_us=2400,neutral=0.5` |
| `FRM,<ms>,<ch>:<val>,...` | Move listed channels to targets over `<ms>` milliseconds, device-side linear interpolation. `FRM,0,...` = jump now. Ex: `FRM,33,0:0.500,1:0.250` |
| `EN,<ch>,<0/1>` | Enable/disable a channel (detach servo signal when 0). |
| `STOP` | E-stop: immediately disable every output. Always honored, never queued. |
| `PING` | Heartbeat probe; device replies `PONG`. |

## Device → host

| Reply | Meaning |
|---|---|
| `ANIMA,0,<name>,<n_channels>` | Handshake reply. |
| `OK` | Command accepted. |
| `ERR,<code>,<msg>` | Rejected: `1` parse, `2` bad channel, `3` bad value, `4` not configured. |
| `PONG` | Heartbeat reply. |

## Failsafe

If a device receives no line for `failsafe_ms` (default 2000, set via
`CFG` key on channel or a future `SET` global), it disables all outputs
— same behavior as `STOP`. A disconnected cable must never leave a
servo straining.

## Streaming rates

Live puppeteering streams `FRM` at 30–60 Hz with `<ms>` ≈ the frame
interval, so device-side interpolation smooths between frames. Offline
playback may use sparse `FRM`s with long durations for linear segments;
curved segments are sampled by the host — the device stays dumb.
