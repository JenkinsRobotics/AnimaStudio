# Packet — move `core/engine` into Aether CAD (2026-09-11)

Jonathan's decision, 2026-09-11: adopt the Onshape product shape. A product
owns its kernel binding, constraint solver, and feature layer; the only
genuinely cross-product asset is the design system. Sequencing chosen:
**execute after the gallery feature-split packet releases `core/ui`.**

**Status: EXECUTED 2026-09-11** by Claude, on Jonathan's direct go-ahead
(before the `core/ui` gallery packet released — Jonathan accepted the overlap;
`core/ui/package.json` was edited surgically, preserving the other agent's
in-flight changes, and its suite re-verified green afterwards).

All four acceptance gates pass:

| Gate | Result |
|---|---|
| `Aether CAD/` | typecheck clean, **462/462** tests, build ✓ |
| `Aether CAD/engine/` | **719/719** tests ✓ |
| `core/ui/` | **163/163** tests, typecheck, build ✓ |
| `aether-animation/web/` | build ✓, and `node_modules/@aether/` = **only `ui`** |

**Two things the plan did not predict**, both the same class of defect the
move exists to prevent — code reaching *out* of the package by relative path:

1. `engine/src/units.ts` imported `../../assets/cad/units.json`
   (`core/assets/`). Repointed. The catalog stays in `core/assets/` because it
   is genuinely shared — `animacore/cad_document.py` reads the same file.
2. Six engine **test** files read Noto Sans from `../../assets/fonts/`, and
   three app files hardcoded `core/engine/...` paths (two `createRequire`
   URLs for `opentype.js`, one deep `import()` of a curves module). All
   repointed. The initial `grep` for stragglers missed these because it did
   not include `*.jsx` — worth remembering for the next move.

Docs updated in the same unit: `AGENTS.md`/`CLAUDE.md`, `CONVENTIONS.md`,
`README.md`, `aether-animation/README.md`, `Aether CAD/src/sketch/README.md`,
`dev/docs/roadmap/UI_Framework_Decision.md`,
`dev/docs/roadmap/Aether_Studio_Suite.md`, `dev/docs/reality/STATUS.md`.
Dated historical entries in STATUS/roadmap were left alone deliberately —
they are records of what was true then.

**Left for whoever picks it up:** `core/assets/fonts/noto-sans/` is now used
only by Aether CAD (engine tests + `src/sketch/text-fonts.ts`). By the
"one product uses it → it belongs to that product" rule it should move to
`Aether CAD/assets/`, but that is a separate packet; it was out of scope here
and the paths work as they are.

---

### Original plan (for the record)

---

## Why — measured, not assumed (2026-09-11)

| Package | Consumers | Verdict |
|---|---|---|
| `@aether/ui` | Aether CAD (22 files), `studio/` (9), `aether-animation/web` (6) | genuinely shared |
| `@aether/core` (444 files) | **Aether CAD only** (104 files) + 2 `core/ui/gallery` demos | product code in a shared folder |

`aether-animation/web/package.json` depends on `@aether/ui`, react, three —
never the engine. The animation lane has its own engine (`animacore/`,
Python). `core/engine` has never been suite-shared; the `@aether/core` name
implies otherwise and has actively misled contributors.

**Layering violation to fix in the same unit:** `core/ui/package.json`
declares `"@aether/core": "file:../engine"` — the shared design system
depends on one product's engine, so Animation inherits CAD's engine in its
dependency graph. `core/ui/src/` is clean; only the gallery imports it.

## Everything else under `core/` is already correct (verified 2026-09-11)

| Path | Role | Verdict |
|---|---|---|
| `core/ui/` | design system, 3 consumers | shared — stays |
| `core/assets/` | icons, branding | shared — stays |
| `core/host/` | Python transport, library, history, state | **the server** — stays |
| `core/session/` | accounts | **the server** — stays |
| `core/engine/` | CAD kernel binding, solver, feature layer | **moves** |

Resulting suite shape, which is the target Jonathan described:

```
Aether CAD/        the Onshape-shaped product: engine + features + UI
aether-animation/  the other product (animacore, Python engine)
core/ui/           shared design system
core/assets/       shared artwork
core/host/         Aether Studio = the server: documents, users, sessions
core/session/
```

## Why it is cheap

Every consumer imports by **package name** (`@aether/core/...`), and there
are **no tsconfig or vite path aliases** anywhere in the repo. The 104 app
files and 444 engine files do not change. Only dependency wiring moves.

## Steps

1. `git mv core/engine "Aether CAD/engine"`
2. `Aether CAD/package.json` — `"@aether/core": "file:../core/engine"`
   → `"file:./engine"`
3. `core/ui/package.json` — move `@aether/core` from `dependencies` to
   `devDependencies` (only the gallery needs it) and repoint to
   `file:../../Aether CAD/engine`.
4. `npm install` in `Aether CAD/`, `core/ui/`.
5. Update `CLAUDE.md` — the `core/` paragraph, already flagged there.
6. Grep for stragglers: `grep -rn "core/engine" --include="*.json"
   --include="*.md" . | grep -v node_modules`

## Acceptance

- `Aether CAD/`: `npx tsc --noEmit` clean, `npx vitest run` 462+ pass,
  `npm run build` succeeds.
- `Aether CAD/engine/`: `npx vitest run` 719+ pass.
- `core/ui/`: `npm test && npm run typecheck && npm run build`, gallery
  still renders the nine feature demos.
- `aether-animation/web/`: `npm run build` — proves the engine left its
  dependency graph.

## Preconditions

- `core/ui` released by the gallery feature-split packet. As of
  2026-09-11 that agent has `core/ui/package.json`, `gallery/main.tsx`,
  `gallery/features/` and 12 `src/` files modified. Do not touch
  `core/ui/package.json` before release — step 3 is why this packet waits.
- Nothing else holds `Aether CAD/src/features/`; the app-side editor port
  is the natural follow-on and should land **after** this move so the new
  files are written against the final path.

## Not in scope

- Splitting `document/solid-features.ts` (155 lines) into per-feature
  modules. Correct eventually — Onshape's standard library is one module
  per feature — but it earns the split when the app-side editor port
  reveals the real parameter-schema shape, not before.
- `Aether CAD/src/viewer.ts` (1,842 lines) and `main.ts` (1,266). Real
  god files, rendering/controller concerns, separate packet.
