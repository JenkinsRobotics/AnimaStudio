# Studio ↔ AnimaCore bridge protocol (planned; BR1 engine side building)

> The seam that makes AnimaCore the single canonical engine and Anima
> Studio a front end (Jonathan + Codex, 2026-07-15). The app does not
> reimplement rig/evaluation semantics; it speaks this protocol to a
> bundled AnimaCore helper. One engine, one set of semantics, multiple
> front ends.

## Ownership (the policy this protocol enforces)

**AnimaCore (`animacore/`, Python) owns the meaning of everything:**
typed mates/DOF/limits/relations, canonical validation, keyframe and
scene evaluation, mate alignment + kinematic pose resolution,
`.character.anima` / `.scene.anima` parsing and writing, output
mapping + serial transport + hardware safety, and node-graph
compilation to scene logic.

**The Swift app owns presentation only:** windows/panels/tools,
selection/inspectors, undo/redo *command presentation*, RealityKit
rendering + model hit-testing, camera/gizmo drawing, file dialogs +
bookmarks + recent projects + macOS lifecycle, and the `.animastudio`
package's *editor-only* metadata (canvas layout, asset references,
revisions, milestones). The app holds **DTOs that mirror engine
results** — it never independently defines what a rig, a pose, or a
frame *means*.

The `.animastudio` package **contains or references** canonical
`.character.anima` and `.scene.anima` documents plus editor metadata.
It is not a competing executable animation format.

The Swift `AnimaEvaluation` target's evaluator and the RealityKit
`RigPoseResolver` / `MateConnectorMath` are **transitional** — they get
replaced by bridge calls (migration order below), not extended.

## Transport

Newline-delimited JSON over the helper's stdio. The app spawns the
helper (`python -m animacore.bridge`, or a bundled executable) and
keeps it alive for the session — one long-running process, not a
shell-out per call. One JSON object per line, UTF-8.

**Request:** `{"id": <int>, "method": "<verb>", "params": {…}}`
**Response (ok):** `{"id": <int>, "ok": true, "result": {…}}`
**Response (error):** `{"id": <int>, "ok": false, "error":
{"code": "<slug>", "message": "<human>", "path": "<format path|null>"}}`

`id` is echoed so the client can match replies; the helper may answer
out of order. Error `code` is a stable slug (`protocol_mismatch`,
`format_error`, `unknown_handle`, `limit_violation`, `bad_request`);
`path` carries the loader's field path (`clips.turn.tracks…`) verbatim
when the error is a format error, so the app shows it at the offending
line — one error surface, never a second parser.

## Verbs — BR1 vertical slice

| Method | params | result |
|---|---|---|
| `hello` | `{client, protocol_version}` | `{engine:"animacore", engine_version, protocol_version, capabilities:[…]}` — mismatched `protocol_version` → `protocol_mismatch` error |
| `load_character` | `{text}` (file bytes; `path` variant later) | `{handle, rig:{identity, parts:[…], joints:[{name,type,dofs:[{path,kind,unit,min,max,neutral}]}], parameters:[…], clips:[{name,duration_s,loop}], outputs:[{dof_path,channel}]}}` — invalid → `format_error` with `path` |
| `validate_character` | `{text}` | `{diagnostics:[…]}` (empty = valid) — no handle allocated |
| `evaluate` | `{handle, clip?, time_s?}` | `{dof_values:{path:native_units}, parameters:{name:0..1}, channels:{channel:0..1}, limit_violations:[{dof_path,value,min,max}]}` |
| `release` | `{handle}` | `{}` — drop a loaded rig |
| `shutdown` | `{}` | `{}` then the helper exits |

Units are native and explicit in the model (radians / meters); the app
formats to degrees/mm for display. `channels` is exactly
`project_channels` output; when a mapped DOF is in `limit_violations`
the channel is omitted (hardware must refuse to arm) rather than erroring
the whole evaluate.

## Later verbs (reserved, each gated on its engine feature)

- `resolve_pose {handle,…}` → per-part world transforms (migrates
  `RigPoseResolver` + `MateConnectorMath` into the engine — **the step
  that lets RealityKit render engine-resolved geometry**).
- `load_scene` / `scene_new_runner` / `scene_advance` / `scene_post_event`
  → drive `SceneRunner` for Show playback.
- `open_output` / `send_frame` / `stop` → the app's Hardware workspace
  driving a real device through `serial_transport`, capabilities-gated.
- `compile_graph` → node canvas ↔ `.scene.anima`.

## Migration order (replace, don't extend, the Swift engine)

1. **BR1 (now):** policy + protocol + engine helper with the slice
   above; **prove the seam vertically** — Codex's client opens a
   `.character.anima` example through the helper, evaluates one frame,
   renders the returned DOF values in RealityKit (its current pose
   resolver applies them to rest geometry).
2. Add `resolve_pose`; move mate-alignment/kinematic math out of Swift.
3. Route the Swift timeline/inspector through `evaluate`; delete the
   Swift `AnimaEvaluation` evaluator.
4. `.animastudio` save/open wraps canonical `.character.anima` /
   `.scene.anima` written by the engine, via the bridge.
5. Simulator/serial output and scene playback through the same helper.
