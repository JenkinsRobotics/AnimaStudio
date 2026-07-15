# Anima — Character Format Specification

> File extension: `.character.anima`  
> Format: YAML  
> Version: 1.0 (draft)

A character file defines the identity and expressive range of an Anima character. It is authored once per character and referenced by scene files. The same character file covers both digital and physical output.

---

## File Structure Overview

```yaml
anima_version: "1.0"
type: character

identity:        # who this character is
blend_shapes:    # expressive face parameters
bones:           # body joint hierarchy
expressions:     # named preset states
clips:           # short named animation sequences
lip_sync:        # phoneme-to-viseme mapping
digital:         # digital renderer configuration
physical:        # physical hardware mapping
voice:           # TTS voice and persona binding
```

---

## Full Example — JP01 Character

```yaml
anima_version: "1.0"
type: character

identity:
  name: JP01
  display_name: "JP01"
  description: "Jenkins Robotics JP01 — walking humanoid robot"
  version: "1.0.0"
  author: "Jenkins Robotics"

# ─────────────────────────────────────────────
# BLEND SHAPES
# Industry-standard ARKit parameters + custom extensions.
# Values are always 0.0 (neutral) to 1.0 (maximum).
# ─────────────────────────────────────────────
blend_shapes:

  # Jaw
  jawOpen:          { default: 0.0, description: "Jaw open" }
  jawForward:       { default: 0.0, description: "Jaw forward" }
  jawLeft:          { default: 0.0, description: "Jaw left" }
  jawRight:         { default: 0.0, description: "Jaw right" }

  # Mouth
  mouthSmileLeft:      { default: 0.0 }
  mouthSmileRight:     { default: 0.0 }
  mouthFrownLeft:      { default: 0.0 }
  mouthFrownRight:     { default: 0.0 }
  mouthPressLeft:      { default: 0.0 }
  mouthPressRight:     { default: 0.0 }
  mouthFunnel:         { default: 0.0 }
  mouthPucker:         { default: 0.0 }
  mouthOpen:           { default: 0.0 }
  mouthUpperUpLeft:    { default: 0.0 }
  mouthUpperUpRight:   { default: 0.0 }
  mouthLowerDownLeft:  { default: 0.0 }
  mouthLowerDownRight: { default: 0.0 }

  # Eyes
  eyeBlinkLeft:     { default: 0.0, description: "Left eye blink" }
  eyeBlinkRight:    { default: 0.0 }
  eyeSquintLeft:    { default: 0.0 }
  eyeSquintRight:   { default: 0.0 }
  eyeWideLeft:      { default: 0.0 }
  eyeWideRight:     { default: 0.0 }
  eyeLookUpLeft:    { default: 0.0 }
  eyeLookUpRight:   { default: 0.0 }
  eyeLookDownLeft:  { default: 0.0 }
  eyeLookDownRight: { default: 0.0 }
  eyeLookInLeft:    { default: 0.0 }
  eyeLookInRight:   { default: 0.0 }
  eyeLookOutLeft:   { default: 0.0 }
  eyeLookOutRight:  { default: 0.0 }

  # Brows
  browDownLeft:     { default: 0.0 }
  browDownRight:    { default: 0.0 }
  browInnerUp:      { default: 0.0 }
  browOuterUpLeft:  { default: 0.0 }
  browOuterUpRight: { default: 0.0 }

  # Nose and cheek
  noseSneerLeft:    { default: 0.0 }
  noseSneerRight:   { default: 0.0 }
  cheekPuff:        { default: 0.0 }
  cheekSquintLeft:  { default: 0.0 }
  cheekSquintRight: { default: 0.0 }

  # Tongue
  tongueOut:        { default: 0.0 }

  # Custom JP01 extensions (beyond ARKit 52)
  headNod:          { default: 0.0, description: "Head nod down" }
  headShake:        { default: 0.0, description: "Head shake side" }
  headTilt:         { default: 0.0, description: "Head tilt" }
  bodyLean:         { default: 0.0, description: "Torso lean forward" }
  chestBreath:      { default: 0.0, description: "Breathing cycle" }

# ─────────────────────────────────────────────
# BODY JOINTS
# Named joints with neutral position and range.
# ─────────────────────────────────────────────
bones:
  head_yaw:
    description: "Head rotation left/right"
    neutral_deg: 0.0
    range_deg: [-45, 45]
  head_pitch:
    description: "Head tilt forward/back"
    neutral_deg: 0.0
    range_deg: [-30, 30]
  head_roll:
    description: "Head tilt side"
    neutral_deg: 0.0
    range_deg: [-20, 20]
  shoulder_left:
    neutral_deg: 0.0
    range_deg: [-90, 90]
  shoulder_right:
    neutral_deg: 0.0
    range_deg: [-90, 90]
  elbow_left:
    neutral_deg: 0.0
    range_deg: [0, 135]
  elbow_right:
    neutral_deg: 0.0
    range_deg: [0, 135]
  torso_yaw:
    neutral_deg: 0.0
    range_deg: [-30, 30]

# ─────────────────────────────────────────────
# EXPRESSION PRESETS
# Named states the AI or scenes can reference.
# Each preset is a set of blend shape values.
# Unspecified blend shapes hold their current value.
# ─────────────────────────────────────────────
expressions:

  neutral:
    description: "Resting state"
    blend_shapes:
      eyeBlinkLeft: 0.0
      eyeBlinkRight: 0.0
      browInnerUp: 0.0
      mouthSmileLeft: 0.0
      mouthSmileRight: 0.0

  happy:
    description: "Positive, pleased"
    blend_shapes:
      mouthSmileLeft: 0.7
      mouthSmileRight: 0.7
      cheekSquintLeft: 0.4
      cheekSquintRight: 0.4
      eyeSquintLeft: 0.2
      eyeSquintRight: 0.2

  curious:
    description: "Interested, attentive"
    blend_shapes:
      browInnerUp: 0.5
      browOuterUpLeft: 0.3
      browOuterUpRight: 0.3
      eyeWideLeft: 0.2
      eyeWideRight: 0.2
      headTilt: 0.3

  thinking:
    description: "Processing, considering"
    blend_shapes:
      browDownLeft: 0.3
      browInnerUp: 0.4
      eyeSquintLeft: 0.3
      eyeSquintRight: 0.1
      mouthPressLeft: 0.2
      headTilt: 0.15

  surprised:
    description: "Unexpected, startled"
    blend_shapes:
      eyeWideLeft: 0.9
      eyeWideRight: 0.9
      browInnerUp: 0.8
      browOuterUpLeft: 0.7
      browOuterUpRight: 0.7
      jawOpen: 0.4
      mouthOpen: 0.5

  sad:
    description: "Unhappy, disappointed"
    blend_shapes:
      mouthFrownLeft: 0.6
      mouthFrownRight: 0.6
      browInnerUp: 0.6
      browDownLeft: 0.2
      browDownRight: 0.2
      eyeSquintLeft: 0.3
      eyeSquintRight: 0.3

  excited:
    description: "Enthusiastic, energized"
    blend_shapes:
      mouthSmileLeft: 0.9
      mouthSmileRight: 0.9
      eyeWideLeft: 0.5
      eyeWideRight: 0.5
      browOuterUpLeft: 0.5
      browOuterUpRight: 0.5
      cheekPuff: 0.2

# ─────────────────────────────────────────────
# NAMED CLIPS
# Short authored animations available by name.
# Can be authored in Anima Studio and stored here
# or in a separate clips library file.
# ─────────────────────────────────────────────
clips:
  blink:
    duration_s: 0.15
    loop: false
    tracks:
      blend_shapes:
        - time: 0.0
          values: { eyeBlinkLeft: 0.0, eyeBlinkRight: 0.0 }
        - time: 0.07
          values: { eyeBlinkLeft: 1.0, eyeBlinkRight: 1.0 }
        - time: 0.15
          values: { eyeBlinkLeft: 0.0, eyeBlinkRight: 0.0 }

  nod:
    duration_s: 0.8
    loop: false
    tracks:
      bones:
        - time: 0.0
          values: { head_pitch: 0.0 }
        - time: 0.3
          values: { head_pitch: -15.0 }
        - time: 0.5
          values: { head_pitch: -15.0 }
        - time: 0.8
          values: { head_pitch: 0.0 }

  wave:
    duration_s: 2.0
    loop: false
    tracks:
      bones:
        - time: 0.0
          values: { shoulder_right: 0.0 }
        - time: 0.3
          values: { shoulder_right: 70.0 }
        - time: 0.7
          values: { shoulder_right: 55.0 }
        - time: 1.0
          values: { shoulder_right: 70.0 }
        - time: 1.3
          values: { shoulder_right: 55.0 }
        - time: 1.7
          values: { shoulder_right: 0.0 }

  idle_breathing:
    duration_s: 4.0
    loop: true
    tracks:
      blend_shapes:
        - time: 0.0
          values: { chestBreath: 0.0, bodyLean: 0.0 }
        - time: 2.0
          values: { chestBreath: 0.6, bodyLean: 0.05 }
        - time: 4.0
          values: { chestBreath: 0.0, bodyLean: 0.0 }
      easing: sine_in_out

# ─────────────────────────────────────────────
# LIP SYNC
# Phoneme-to-viseme mapping for TTS-driven mouth animation.
# ─────────────────────────────────────────────
lip_sync:
  engine: amplitude          # "amplitude" | "phoneme" | "viseme"
  
  # Amplitude-driven fallback (used when phoneme data unavailable)
  amplitude_mapping:
    jawOpen:      { scale: 0.8, smoothing: 0.1 }
    mouthOpen:    { scale: 0.5, smoothing: 0.1 }

  # Phoneme-to-blend-shape mapping (when phoneme data available)
  phoneme_mapping:
    AA: { jawOpen: 0.7, mouthOpen: 0.6, mouthFunnel: 0.0 }  # "father"
    AE: { jawOpen: 0.6, mouthSmileLeft: 0.3, mouthSmileRight: 0.3 }
    AH: { jawOpen: 0.5, mouthOpen: 0.4 }                     # "but"
    AO: { jawOpen: 0.6, mouthFunnel: 0.4 }                   # "dog"
    AW: { jawOpen: 0.5, mouthFunnel: 0.6 }
    AY: { jawOpen: 0.5, mouthSmileLeft: 0.2 }
    B:  { jawOpen: 0.0, mouthPressLeft: 0.5, mouthPressRight: 0.5 }
    CH: { jawOpen: 0.1, mouthPucker: 0.5 }
    D:  { jawOpen: 0.1 }
    EH: { jawOpen: 0.4, mouthSmileLeft: 0.1, mouthSmileRight: 0.1 }
    ER: { jawOpen: 0.3, mouthFunnel: 0.2 }
    EY: { jawOpen: 0.3, mouthSmileLeft: 0.4, mouthSmileRight: 0.4 }
    F:  { jawOpen: 0.1, mouthUpperUpLeft: 0.3 }
    IH: { jawOpen: 0.2, mouthSmileLeft: 0.2, mouthSmileRight: 0.2 }
    M:  { jawOpen: 0.0, mouthPressLeft: 0.8, mouthPressRight: 0.8 }
    N:  { jawOpen: 0.1 }
    OW: { jawOpen: 0.5, mouthFunnel: 0.7, mouthPucker: 0.3 }
    P:  { jawOpen: 0.0, mouthPressLeft: 0.9, mouthPressRight: 0.9 }
    R:  { jawOpen: 0.2, mouthFunnel: 0.2 }
    S:  { jawOpen: 0.1, mouthSmileLeft: 0.1 }
    SH: { jawOpen: 0.1, mouthPucker: 0.3, mouthFunnel: 0.2 }
    T:  { jawOpen: 0.0, tongueOut: 0.1 }
    TH: { jawOpen: 0.1, tongueOut: 0.3 }
    UH: { jawOpen: 0.3, mouthFunnel: 0.3 }
    UW: { jawOpen: 0.2, mouthFunnel: 0.8, mouthPucker: 0.5 }
    V:  { jawOpen: 0.1, mouthUpperUpLeft: 0.4 }
    W:  { jawOpen: 0.2, mouthFunnel: 0.5, mouthPucker: 0.4 }

# ─────────────────────────────────────────────
# DIGITAL OUTPUT CONFIGURATION
# ─────────────────────────────────────────────
digital:
  renderer: live2d             # "live2d" | "vrm" | "custom"

  live2d:
    model_file: "jp01_face.model3.json"
    
    # ARKit blend shape → Live2D parameter mapping
    parameter_mapping:
      jawOpen:          ParamMouthOpenY
      mouthSmileLeft:   ParamMouthForm    # averaged with right
      mouthSmileRight:  ParamMouthForm
      eyeBlinkLeft:     ParamEyeLOpen     # inverted: 1-value
      eyeBlinkRight:    ParamEyeROpen     # inverted: 1-value
      eyeLookUpLeft:    ParamEyeBallY     # combined
      eyeLookDownLeft:  ParamEyeBallY
      eyeLookInLeft:    ParamEyeBallX
      eyeLookOutLeft:   ParamEyeBallX
      browInnerUp:      ParamBrowLY
      browOuterUpLeft:  ParamBrowLAngle
      cheekPuff:        ParamCheek
      headNod:          ParamAngleX
      headShake:        ParamAngleY
      headTilt:         ParamAngleZ

  idle:
    # Auto-blink interval
    blink_interval_s: [3.0, 6.0]     # random range in seconds
    blink_duration_s: 0.12
    # Subtle micro-movements when idle
    eye_saccade: true
    eye_saccade_interval_s: [1.5, 4.0]
    eye_saccade_range: 0.15
    # Idle breathing (blend shape)
    breathing: true
    breathing_clip: idle_breathing

# ─────────────────────────────────────────────
# PHYSICAL OUTPUT CONFIGURATION
# Maps blend shapes and bones to hardware targets.
# Hardware safety limits are enforced by the project config.
# ─────────────────────────────────────────────
physical:
  enabled: true

  # Blend shape → servo mapping
  # range: [value_at_0.0, value_at_1.0] in servo degrees
  blend_shape_mapping:
    jawOpen:
      joint: head_jaw
      range: [5, 40]
      smoothing: 0.08       # seconds of exponential smoothing
    browInnerUp:
      joint: head_brow
      range: [25, 55]
      smoothing: 0.1

  # Bone → servo mapping (direct joint targets)
  bone_mapping:
    head_yaw:
      servo_channel: 0
      range: [-45, 45]        # degrees → servo degrees (1:1 here)
      smoothing: 0.05
    head_pitch:
      servo_channel: 1
      range: [-25, 25]
      smoothing: 0.05
    head_roll:
      servo_channel: 2
      range: [-20, 20]
      smoothing: 0.05
    shoulder_right:
      servo_channel: 3
      range: [0, 90]
      smoothing: 0.03

  # LED mapping from expression state
  led_mapping:
    happy:      { color: [255, 200, 50],  pattern: pulse,   speed: 0.8 }
    curious:    { color: [100, 180, 255], pattern: solid }
    thinking:   { color: [150, 100, 255], pattern: pulse,   speed: 0.3 }
    surprised:  { color: [255, 255, 255], pattern: flash,   speed: 2.0 }
    sad:        { color: [80,  120, 200], pattern: solid,   brightness: 0.5 }
    excited:    { color: [255, 150, 0],   pattern: rainbow, speed: 1.5 }
    neutral:    { color: [200, 200, 200], pattern: solid,   brightness: 0.7 }

# ─────────────────────────────────────────────
# VOICE AND PERSONA BINDING
# ─────────────────────────────────────────────
voice:
  tts_slot: tts               # which JaegerOS slot provides speech
  default_voice: "af_heart"   # Kokoro voice identifier
  default_speed: 1.0
  default_language: "en-us"

  # Emotion-to-TTS-speed mapping
  speech_rate_by_expression:
    excited: 1.15
    sad:     0.9
    thinking: 0.95
    neutral: 1.0
