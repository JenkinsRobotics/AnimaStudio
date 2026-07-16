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
| `load_character` | `{text}` (file bytes; `path` variant later) | `{handle, rig:{identity, parts:[…], joints:[<describe_mate>…], parameters:[…], clips:[{name,duration_s,loop}], outputs:[{dof_path,channel}]}}` — invalid → `format_error` with `path`. Each joint entry is `describe_mate` (see below). |
| `validate_character` | `{text}` | `{diagnostics:[…]}` (empty = valid) — no handle allocated |
| `evaluate` | `{handle, clip?, time_s?}` | `{dof_values:{path:native_units}, parameters:{name:0..1}, channels:{channel:0..1}, limit_violations:[{dof_path,value,min,max}]}` |
| `resolve_pose` | `{handle, clip?, time_s?}` | `{parts:{part_name:{position:[x,y,z], orientation:[x,y,z,w]}}}` — per-part **world** transforms after forward kinematics. **The RealityKit render hook.** Unknown handle → `unknown_handle`. See below. |
| `mate_types` | `{}` | `{mate_types:[{type,label,dof_count,universal_controls:[…],dofs:[{name,kind,unit}]}]}` — the static per-kind catalog for all 8 mate kinds (the palette / panel-builder hook); no handle needed |
| `release` | `{handle}` | `{}` — drop a loaded rig |
| `shutdown` | `{}` | `{}` then the helper exits |

Units are native and explicit in the model (radians / meters); the app
formats to degrees/mm for display. `channels` is exactly
`project_channels` output; when a mapped DOF is in `limit_violations`
the channel is omitted (hardware must refuse to arm) rather than erroring
the whole evaluate.

**Enriched joint summary (`describe_mate`).** Each joint in
`load_character` is the consistent per-mate hook
`animacore.mates.describe_mate(joint)`:

```
{id, name, type, parent_part, child_part,
 controls: {connectors:{a:<connector|null>, b:<connector|null>},
            offset:{enabled, translation_m:[x,y,z], rotation_axis:"x|y|z",
                    rotation_radians},
            flip_primary_axis, secondary_axis_rotation_deg,
            simulation_connection},
 dofs: [{path, kind, unit, min, max, neutral}]}
```

where each connector is `{part, origin_m:[x,y,z], primary_axis:[…],
secondary_axis:[…], flipped, feature}`. `id` is a stable tracking id
distinct from `name` (empty until the app assigns it); `controls` is
the universal control set every kind shares (only the DOF slots differ
per kind — see `mate_types`). Offset rotation is native radians here,
like the DOF descriptors. A mate that declared no controls reports
null connectors and default control values.

**Pose resolution (`resolve_pose`).** Forward kinematics over the joint
graph: `evaluate` the frame, then walk parents-before-children giving
each part its **world** transform. `params` mirror `evaluate`
(`{handle, clip?, time_s?}`); the result is one entry per part:

```
{parts: {part_name: {position:[x,y,z],
                     orientation:[x,y,z,w]}}}
```

`position` is metres; `orientation` is a unit quaternion with the real
part **last** — RealityKit `simd_quatf(ix, iy, iz, r)` order, so the app
constructs `simd_quatf(ix: o[0], iy: o[1], iz: o[2], r: o[3])` directly.
A part that is no joint's child is a root at identity (parts carry no
rest transform). Each mate moves the child relative to the parent about/
along the **mate connector as the relative origin**, per its DOF — the
canonical convention lives in `Kinematics.md` → "Pose resolution". This
verb **supersedes** the Swift `RigPoseResolver` + `MateConnectorMath`
(migration step 2 below): RealityKit renders engine-resolved geometry
instead of applying scalar joint angles to rest transforms.

## Later verbs (reserved, each gated on its engine feature)

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
2. **Done (engine side):** `resolve_pose` ships the mate-alignment +
   kinematic math in the engine (`animacore/kinematics.py`). Remaining
   app work: route RealityKit through `resolve_pose` and delete the
   Swift `RigPoseResolver` + `MateConnectorMath`.
3. Route the Swift timeline/inspector through `evaluate`; delete the
   Swift `AnimaEvaluation` evaluator.
4. `.animastudio` save/open wraps canonical `.character.anima` /
   `.scene.anima` written by the engine, via the bridge.
5. Simulator/serial output and scene playback through the same helper.
