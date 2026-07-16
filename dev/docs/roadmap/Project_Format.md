# Project format — the `.animastudio` project folder (planned)

> How Anima Studio creates, saves, and reopens a project (Jonathan,
> 2026-07-16). A project is a **folder**, not one file: canonical engine
> documents (`.character.anima` / `.scene.anima`) plus the app's
> editor-only metadata and 3D assets, organized so a character is a
> self-contained, shareable unit.

## Layout

```
~/Documents/Anima Studio/
  MyRobot/                        ← the project folder (plain folder, browsable)
    project.json                  ← manifest (app-owned): name, revision, dates,
    │                               milestone, character/scene index, window/editor state
    characters/
      jp01/                       ← one character — self-contained, drag-to-share
        jp01.character.anima      ← canonical rig (ENGINE format): parts, mates,
        │                           DOF, limits, relations, output mappings
        assets/                   ← this character's 3D models
          head.stl
          body.usdz
        jp01.editor.json          ← editor-only (APP): connector inference cache,
        │                           per-part display, layout — NEVER inside the .anima
    scenes/
      wave.scene.anima            ← animations / shows (ENGINE format)
```

Extensible: `project.json` indexes what's present, so future kinds
(audio, exports, LED maps) become new folders without a format change.

**Real projects are plain folders** (browsable, versionable). A
single-file **`.animastudio` bundle is an Export form only** — "Export
Project" zips the folder into one shareable/double-clickable item;
day-to-day projects stay open folders.

## Where the logic lives (engine vs app)

Per "AnimaCore is canonical," the engine owns everything about file
**content**; the sandboxed Mac app owns the **filesystem**:

- **Engine (Python):** serialize/parse `.character.anima` and
  `.scene.anima`, validate, and define the project-format rules. These
  are pure text-in/text-out — the hooks. (Build: `serialize_character`
  / `serialize_scene`.)
- **App (Swift):** the actual folder/file writing, native New/Open/Save
  dialogs, security-scoped bookmarks, and atomic writes. This layer is
  **irreducibly Swift** — a sandboxed app's file access can't be handed
  to the Python helper subprocess — but it is thin and fully specified
  here, and the `AnimaDocument` P0A machinery already implements most of
  it (revised from a flat bundle to this folder layout). Codex wires it;
  it designs nothing.

## Names: project and character are independent namespaces

A project holds **one or more characters** (`characters/` is a folder of
many). The **project name** and a **character name** are separate
identities — a "MyRobot" project can contain characters "jp01",
"gripper", "turret". Character folder names are unique within a project;
the project name is unique within `~/Documents/Anima Studio/`. Renaming
a project never touches character names, and vice versa. `project.json`
indexes the characters (and scenes) by their folder names + display
names.

## The rule: canonical files vs editor metadata are separate

The `.character.anima` / `.scene.anima` are the **engine's** canonical,
portable documents — a character runs on the robot standalone. The
app's view state (connector-inference cache, layout, thumbnails, the
revision counter) lives in `project.json` / `*.editor.json`, **never in
the `.anima`**. This is the "engine owns `.anima`, app owns editor
metadata" policy (`Studio_Bridge.md`) made physical, and it keeps the
format shareable. Asset references inside a `.character.anima` are
**relative to the character folder** (`assets/head.stl`) so the
character is portable.

## Save / Open / Save As flows

- **New Project** → create `~/Documents/Anima Studio/<name>/` with an
  empty `project.json` (revision 1) and empty `characters/` / `scenes/`.
- **Import model** → copy the STL/USD into the active character's
  `assets/`, add a per-part `model`/`model_node` reference the app uses
  to render (the engine round-trips it as opaque — it never parses the
  mesh).
- **Save** → for each dirty character/scene, the app hands its rig/scene
  to the engine to **serialize** into canonical text (the engine owns
  `.anima` *writing*, so the format has one author), writes the file,
  copies any new assets, and bumps `project.json`'s revision (the V-badge).
  Atomic (temp-then-replace) so a crash never corrupts the project.
- **Save As** → copy the project folder to a new name/location, bump
  revision, retarget the app's open document.
- **Open** → read `project.json` → for each character, load its
  `.character.anima` through the engine (`load_character`, exists) and
  restore view state from `*.editor.json`.
- **Recents** → the gallery tracks project-folder paths (security-scoped
  bookmarks), reading name/revision/thumbnail from each `project.json`.

## Engine serialization contract (BR-SAVE — engine side shipped)

The engine has the write verbs, the inverse of its loaders
(`animacore/serialize.py` + the `serialize_character` / `serialize_scene`
bridge verbs; full spec + round-trip guarantee live in
`Studio_Bridge.md` → "Serialization"):

| Verb | params | result |
|---|---|---|
| `serialize_character` | `{rig}` — the full rig DTO (**exactly** the `load_character` rig shape, full-fidelity: identity, parts, joints w/ controls + dofs + limits, parameters, clips w/ keyframes, relations, outputs w/ ranges) | `{text}` — canonical `.character.anima` YAML; invalid rig → `format_error` |
| `serialize_scene` | `{scene}` — the `.scene.anima` document structure | `{text}` — canonical `.scene.anima` YAML; invalid → `format_error` |

Round-trip is the acceptance test: `load_character(text)` →
serialize → `text'` where `load_character(text')` yields an equal rig,
for every file in `examples/` — verified in
`animacore/tests/test_serialize.py` and `test_bridge.py`. Serialization
validates (an un-serializable/invalid rig errors) so the app can never
write a broken file. To make the round-trip lossless the engine
**additively** enriched the `load_character` rig summary (clip
`keyframes`, output ranges, per-DOF `axis_vector`/`name`/`description`,
joint `description` — nothing renamed/removed).

Remaining app-side work: `AnimaDocument` (the P0A manifest/asset
machinery) is revised from its flat bundle to this nested folder
layout — the store logic carries; the layout gets richer. Codex wires
the folder writing; the engine owns the `.anima` text.
