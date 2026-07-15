# Anima — Scene Format Specification

> File extension: `.scene.anima`  
> Format: YAML  
> Version: 1.0 (draft)

A scene file describes a complete performance — a sequence of actions with timing, logic, and audio synchronization that the Anima Runtime executes as a JaegerOS action.

---

## File Structure Overview

```yaml
anima_version: "1.0"
type: scene

meta:        # scene identity and settings
character:   # which character file this targets
sequence:    # the ordered list of actions
```

---

## Meta Block

```yaml
meta:
  name: "greeting_wave"
  description: "JP01 greets a visitor and waves"
  author: "Jenkins Robotics"
  version: "1.0.0"
  duration_hint_s: 5.0      # approximate, for planning
  interruptible: true        # can JaegerAI cancel mid-scene?
  tags: [greeting, wave, social]
```

---

## Character Reference

```yaml
character:
  file: "jp01.character.anima"   # relative path or library name
  # override specific settings for this scene only
  overrides:
    voice:
      default_speed: 1.05
```

---

## Sequence — Action Types

The `sequence` is an ordered list of actions. Actions execute top-to-bottom by default. Special actions (parallel, wait_for, if) modify flow.

### `speak` — Text to Speech

```yaml
- speak: "Hello! I'm JP01. Nice to meet you."
  expression: happy           # set expression while speaking
  voice: af_heart             # override default voice
  wait_for_completion: true   # default true — next action waits
```

Internally: publishes `/act/speech` and waits for `/sense/spoken` acknowledgement before proceeding (unless `wait_for_completion: false`).

### `expression` — Set Expression State

```yaml
- expression: curious
  blend_time_s: 0.4           # transition duration (default 0.3)
```

### `clip` — Play Named Animation Clip

```yaml
- clip: wave
  wait_for_completion: true
  blend_in_s: 0.1
  blend_out_s: 0.2
```

### `pose` — Set Specific Joint or Blend Shape Values

```yaml
- pose:
    head_yaw: 15.0            # degrees
    head_pitch: -5.0
    blend_time_s: 0.5
```

### `blend_shapes` — Set Specific Blend Shape Values Directly

```yaml
- blend_shapes:
    mouthSmileLeft: 0.8
    mouthSmileRight: 0.8
    cheekSquintLeft: 0.4
    blend_time_s: 0.3
```

### `lights` — LED State

```yaml
- lights:
    pattern: pulse
    color: [255, 200, 50]     # RGB
    brightness: 0.9
    speed: 0.8
```

### `wait` — Timed Pause

```yaml
- wait: 1.5                   # seconds
```

### `wait_for` — Wait for External Event

```yaml
- wait_for: user_speech_start
  timeout_s: 30.0             # optional — continue after timeout
  timeout_action: continue    # "continue" | "skip_to_end" | "goto: label"
```

Supported event triggers:

| Event | Fires when |
|-------|-----------|
| `user_speech_start` | `/sense/user_speech_start` published |
| `user_speech_end` | `/sense/user_speech_end` published |
| `user_speech_contains: "keyword"` | transcript contains keyword |
| `animation_complete` | current clip or parallel block finishes |
| `time: 5.0` | 5 seconds elapsed since scene start |
| `topic: /sense/my_topic` | any message on this topic |
| `expression_reached: happy` | expression transition completes |

### `parallel` — Run Multiple Actions Simultaneously

```yaml
- parallel:
    - speak: "Let me show you something."
      wait_for_completion: false
    - clip: wave
    - lights:
        pattern: pulse
        color: [100, 200, 255]
  wait_for: all               # "all" | "first" | "speak"
```

`wait_for: all` — parallel block completes when all children complete.  
`wait_for: first` — parallel block completes when the first child completes, cancels others.  
`wait_for: speak` — waits specifically for the speak action, lets clip continue.

### `if` — Conditional Branch

```yaml
- if:
    condition: user_speech_contains("goodbye")
    then:
      - speak: "It was great meeting you! Goodbye!"
      - expression: happy
      - clip: wave
    else:
      - speak: "What else can I help you with?"
      - wait_for: user_speech_start
```

Condition expressions:

```yaml
condition: user_speech_contains("keyword")
condition: expression_is("happy")
condition: topic_received("/sense/motion_arrived")
condition: variable_equals(name="mood", value="excited")
condition: elapsed_s_greater_than(30.0)
condition: and:
  - user_speech_contains("yes")
  - not: expression_is("sad")
condition: or:
  - user_speech_contains("goodbye")
  - user_speech_contains("bye")
```

### `loop` — Repeat a Block

```yaml
- loop:
    count: 3           # integer, or "forever"
    body:
      - clip: nod
      - wait: 0.5
```

### `goto` — Jump to Labeled Step

```yaml
- label: ask_again
- speak: "Would you like to hear more?"
- wait_for: user_speech_start
- if:
    condition: user_speech_contains("yes")
    then:
      - speak: "Great! Here's more..."
    else:
      - goto: ask_again
```

### `set_variable` — Store a Value

```yaml
- set_variable:
    name: user_mood
    value: "interested"
```

### `ai_response` — Hand Off to JaegerAI

```yaml
- ai_response:
    prompt_hint: "The visitor just said hello. Respond warmly."
    max_turns: 3          # number of conversation turns before returning to scene
    on_complete: continue # "continue" | "end_scene"
```

This suspends the scene and lets JaegerAI handle conversation. When `max_turns` is reached or JaegerAI signals completion, the scene resumes.

---

## Complete Scene Examples

### Example 1 — Simple Greeting

```yaml
anima_version: "1.0"
type: scene

meta:
  name: greeting_simple
  duration_hint_s: 4.0

character:
  file: jp01.character.anima

sequence:
  - expression: happy
    blend_time_s: 0.3
  - parallel:
      - speak: "Hello! I'm JP01."
        wait_for_completion: false
      - clip: wave
    wait_for: speak
  - wait: 0.5
  - speak: "It's great to meet you!"
  - expression: neutral
    blend_time_s: 0.5
```

### Example 2 — Interactive Conversation with Logic Gates

```yaml
anima_version: "1.0"
type: scene

meta:
  name: meet_and_greet
  interruptible: true

character:
  file: jp01.character.anima

sequence:
  - expression: curious
  - speak: "Hello! I'm JP01. What's your name?"

  - wait_for: user_speech_end
    timeout_s: 15.0
    timeout_action: continue

  - expression: happy
  - speak: "Wonderful! It's great to meet you."

  - parallel:
      - lights:
          pattern: pulse
          color: [255, 200, 50]
          speed: 0.8
      - clip: nod
    wait_for: all

  - speak: "Would you like to see what I can do?"

  - wait_for: user_speech_end
    timeout_s: 10.0

  - if:
      condition: or:
        - user_speech_contains("yes")
        - user_speech_contains("sure")
        - user_speech_contains("okay")
      then:
        - expression: excited
        - speak: "Excellent! Watch this."
        - clip: wave
        - wait: 0.5
        - speak: "I can also walk, navigate, and help with tasks."
      else:
        - expression: neutral
        - speak: "No worries! Let me know if you need anything."

  - wait: 1.0
  - expression: neutral
    blend_time_s: 0.5
  - lights:
      pattern: solid
      color: [200, 200, 200]
      brightness: 0.7
```

### Example 3 — Show Control Scene (No AI)

```yaml
anima_version: "1.0"
type: scene

meta:
  name: demo_performance
  description: "Timed show control demo — no AI interaction"
  interruptible: false

character:
  file: jp01.character.anima

sequence:
  - lights:
      pattern: rainbow
      speed: 1.0

  - parallel:
      - expression: excited
      - wait: 0.5
    wait_for: all

  - speak: "Welcome to the Jenkins Robotics demonstration."
  - wait: 0.8

  - parallel:
      - clip: wave
      - lights:
          pattern: pulse
          color: [255, 150, 0]
    wait_for: all

  - speak: "My name is JP01. I am an AI-powered walking robot built on the Jaeger ecosystem."
  - wait: 0.5

  - expression: curious
  - speak: "I can perceive my environment, navigate autonomously, and hold a conversation."
  - wait: 1.0

  - parallel:
      - expression: happy
      - lights:
          pattern: solid
          color: [100, 200, 100]
    wait_for: all

  - speak: "Thank you for visiting. I look forward to working with you."
  - clip: wave
```

### Example 4 — AI Handoff Scene

```yaml
anima_version: "1.0"
type: scene

meta:
  name: open_conversation
  description: "Scripted intro, then hand off to JaegerAI"

character:
  file: jp01.character.anima

sequence:
  - expression: happy
  - speak: "Hi there! I'm JP01. How can I help you today?"

  - wait_for: user_speech_start
    timeout_s: 20.0
    timeout_action: continue

  - ai_response:
      prompt_hint: "You just greeted a visitor. Continue the conversation naturally."
      max_turns: 10
      on_complete: continue

  - expression: neutral
  - speak: "It was great talking with you. Come back any time!"
  - clip: wave
```

---

## Execution Model

When the Anima Runtime receives an `AnimationCommand` with a scene file:

```
1. Load scene file and validate
2. Load referenced character file (or use already-loaded character)
3. Start JaegerOS action (goal accepted)
4. Walk sequence top to bottom:
   - Execute each action
   - Publish feedback after each step
   - Evaluate conditions and branches
   - Handle wait_for by subscribing to bus topics
   - Handle parallel by spawning concurrent coroutines
5. On completion: publish AnimationResult(success=True)
6. On cancel: blend out, return to idle, publish result
7. On error: publish AnimationResult(success=False, reason=...)
```

---

## Variable Scope

Variables set with `set_variable` are scoped to the current scene execution. They reset when the scene ends. JaegerAI can also read and write scene variables through the tool interface during `ai_response` blocks.

---

## Logic Gate Evaluation

`wait_for` events are resolved by subscribing to JaegerOS bus topics:

```
wait_for: user_speech_start
    → subscribe to /sense/user_speech_start
    → suspend execution
    → resume when topic received or timeout fires

wait_for: user_speech_contains("goodbye")
    → subscribe to /sense/transcript
    → check each transcript for keyword
    → resume when match found or timeout fires
```

This means all wait conditions are event-driven — no polling. The scene suspends on the JaegerOS bus and resumes when the event arrives.

---

## Related Docs

- [[05_Anima/Character_Format]] — character file spec (blend shapes, expressions, clips)
- [[05_Anima/Architecture]] — how the Runtime executes scenes
- [[01_JaegerOS/Communication_Semantics]] — JaegerOS action semantics
- [[01_JaegerOS/Wire_Contract]] — bus topics used by scene execution
