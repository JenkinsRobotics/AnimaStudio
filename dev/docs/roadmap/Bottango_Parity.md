# Bottango parity map (planned)

> What Bottango does (per [docs.bottango.com](https://docs.bottango.com/)),
> and where each capability lands in Anima. Anima is not a clone — the
> distinction is one semantic rig driving physical, screen, LED, and
> digital outputs through replaceable adapters, plus an open format and
> AI integration. But Bottango defines the workflow bar for the physical
> side, and this map keeps us honest about parity.

| Bottango capability | Anima home | Status |
|---|---|---|
| Timeline keyframe animation, Bézier curve/graph editor, tracks | Studio (`studio/`, AnimaCore + AnimaStudioApp) | foundation shipped (hold/linear keyframes, tracks, scrubbing); Bézier + graph view planned |
| Motor types: hobby servo, PCA9685 banks, steppers, DYNAMIXEL, custom | Runtime (`anima_studio/`) channel/actuator model + firmware | planned |
| Open firmware (Arduino framework: Arduino/ESP32) | `firmware/` — Anima wire-protocol firmware | planned |
| Live real-time control ("move it in the app, the robot moves") | Studio output adapter → wire protocol → firmware | planned (Studio Slice 5 defines the `AnimationOutput` contract) |
| Live puppeteering: control schemes, input recording, microphone input | Studio, after the hardware loop works | planned (later) |
| Audio/video media tracks, audio sync, audio-on-hardware | Studio media tracks + `.scene.anima` `speak`/audio actions | planned |
| Custom events, REST API, SMPTE LTC | Runtime triggers + JaegerOS bus/tools (our answer is the bus, not REST) | planned (later) |
| Export animation for offline playback with playback logic | `.anima` files executed by Anima Runtime on-robot — this is our core thesis, stronger than Bottango's export | format specced; runtime planned |

## What Anima adds beyond Bottango

Open format (`.anima`), open app (not just open firmware), digital avatar
output from the same rig, AI authoring/triggering via JaegerAI, and
show-control logic gates (`wait_for`, conditionals) in scene files.

## Parity milestones (physical side)

1. **Wire protocol v0** — versioned serial protocol spec + Python
   reference host + simulator; see `Wire_Protocol.md`.
2. **First hardware loop** — Studio's evaluated frames reach a servo via
   the protocol (PCA9685 + hobby servo first, Bottango's bread and
   butter).
3. **Firmware** — Arduino/ESP32 sketch speaking the protocol.
4. **Offline playback** — Runtime plays a `.scene.anima` on-robot with
   no desktop attached (this is where we pass Bottango).
