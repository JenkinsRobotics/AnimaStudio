# Packet — wire the central shortcut registry to key handling (2026-09-12)

**Status: READY, NOT CLAIMED.** The map exists and is tested; nothing consumes
it yet.

## What exists

`Aether CAD/src/shortcuts.ts` — the single keyboard table for the product.

- Every binding declared in one place, grouped (`Sketch tools`, `Constrain`,
  `Dimension`, `View`). Dimension is bound to `d`, per Onshape.
- Constraint bindings are **derived from** `src/sketch/constraint-catalog.ts`,
  so the Constrain menu and the keyboard cannot disagree.
- `ShortcutRegistry.remap(id, keys)` / `reset(id?)` layer user or theme
  overrides over the defaults; a preferences file only states what it changes.
- `commandFor(event)` resolves a `KeyboardEvent` to a command id.
- `conflicts()` reports shadowing. `src/shortcuts.test.ts` asserts the shipped
  defaults have **zero** conflicts, and that remapping Dimension onto `l`
  reports the clash with Line rather than silently winning.

## What is missing

No listener calls `commandFor()`. Keys are still handled where they always
were — `sketch-workspace.ts` (`workspaceKey`, `globalKey`) and `main.ts`.

## The work

1. Route the existing sketch keydown handlers through `shortcuts.commandFor()`,
   dispatching the resolved command id via `cadCommands.execute()` instead of
   matching `e.key` inline. Delete the inline key comparisons as they are
   replaced — two sources of truth is the failure this packet exists to stop.
2. Decide precedence when a sketch is open vs not; today `globalKey` skips
   events whose target is inside the workspace root, and that rule must be
   preserved.
3. Do not fire shortcuts while a text field, textarea, or dimension input has
   focus. `sketch-workspace.ts` already has this concern in `workspaceKey`.
4. Persist overrides beside the other workspace preferences
   (`aether-cad.presentation.v1`, `aether-cad.reference-visibility.v1`). Same
   defensive parse: drop unknown ids and non-string bindings.
5. Surface the table in the settings window so a user can remap without editing
   a file; show `conflicts()` inline rather than refusing the edit.

## Acceptance

- Pressing each default binding runs its command, verified through
  `cadCommands`, with a sketch open.
- A remapped binding takes effect without reload and survives one.
- No shortcut fires while a dimension or name field has focus.
- `grep -rn 'e.key ===' src/` finds no sketch tool or constraint key matching
  left outside the registry.
- `Aether CAD`: typecheck, full suite, build.

## Not in scope

- Chords and sequences. The signature format is single-combo by design; add
  only if a real binding needs it.
- Assembly and drawing workspace keys. Same registry, separate packet, once the
  sketch lane proves the pattern.
