# Inheriting from FreeCAD and OCCT

**Decision (Jonathan, 2026-09-12): keep our design, inherit the engine.** The
UI, document model and product shape stay ours. Anything below that line —
solving, projection, tessellation, exchange — we take from FreeCAD and OCCT
rather than write, wherever it is genuinely available.

This document records what is *verified* available, what it replaces, and in
what order. Numbers here were measured on 2026-09-12, not estimated.

## Why this document exists

Building the sketcher one constraint at a time was costing days per feature.
Measured cause:

| Layer | Non-test LOC | Who does the hard part |
|---|---|---|
| `engine/src/kernel/` | 893 | OCCT, via `replicad` + `opencascade.js` |
| `engine/src/sketch/` | 15,389 | us |
| └ `sketch/solver/` | 2,599 (+5,313 test) | us |
| └ `sketch/operations/` | 6,819 | us |
| `Aether CAD/src/` (UI) | 27,726 | us — and correctly so |

B-Rep solid modelling, the hardest part of CAD, is the *smallest* module
because we borrowed OCCT. 2D constraints are the largest because we did not.
The strategy already works here; it was simply never applied above the kernel.

## Tier 1 — already inherited

**OCCT via `replicad` + `replicad-opencascadejs`.** Solids, booleans,
fillet/chamfer, STEP import, exact topology. Keep as is.

## Tier 2 — inherit as code

### 2a. Sketch constraints → FreeCAD PlaneGCS (spiked, viable)

`@salusoft89/planegcs` is FreeCAD's Sketcher solver (`planegcs`) compiled to
WASM with full TypeScript types, published on npm, LGPL-2.0-or-later.

**Spike result (2026-09-12).** `solver/planegcs-spike.ts` maps our drawing
model onto planegcs primitives behind the existing
`solveDrawingConstraints(source, options)` seam. A harness ran the *existing*
sketch corpus — 539 tests, 1,878 real solve calls — through both solvers and
compared coordinates:

| Verdict | Solves | Share |
|---|---|---|
| unsupported *by the spike* | 867 | 67.4% |
| **agreed to 1e-6** | **202** | **15.7%** |
| spike mapping still failing | 163 | 12.7% |
| disagreed | 26 | 2.0% |
| both rejected | 19 | 1.5% |
| planegcs solved what we reject | 10 | 0.8% |

*(1,287 solves carrying at least one constraint; the other 591 calls had no
constraints and return early in both solvers.)*

**Fifteen of our twenty-seven constraint kinds produced identical geometry:**
horizontal, vertical, fix, radius, diameter, length, distance, angle,
coincident, concentric, parallel, perpendicular, equal, tangent, symmetric.

Nothing was rejected because planegcs cannot express it. The gaps break down as:

- **Spike scope, planegcs supports it natively:** bezier segments (198) and
  ellipse segments (138) — planegcs has B-spline, ellipse, hyperbola and
  parabola primitives; the spike simply did not map them.
- **Ours to keep:** `pattern` (192), `slot` (47), `offset` (66) are
  higher-level Aether constructs, not solver primitives. Offset has an OCCT
  answer (2c).
- **Spike mapping bugs, not limits:** 163 "expected Point, got Curve" (a
  curve-contact reference still resolving to the segment), plus 121
  reference/driver dimensions whose value the spike reads before resolving.

**The one real migration cost:** the 26 disagreements are *different valid
solutions*, not wrong ones — drift of 10–16 mm on under-determined systems
where our spike leaves `fix` unimplemented. Constraint systems have many
solutions and the two solvers pick different branches. Existing sketches
would re-settle, so pinned coordinates in tests change. That is a re-pinning
exercise, and FreeCAD has the same character.

**What it buys:** deletes ~2,599 lines of residuals, damping, rank and
diagnostic code; turns "add a constraint type" from a residual + Jacobian +
diagnostics + tests job into a mapping entry; and hands us
`get_gcs_conflicting_constraints()`, `get_gcs_redundant_constraints()` and
`get_gcs_partially_redundant_constraints()` — which is what
`solver/diagnostics.ts`, `diagnostic-rank.ts` and `diagnostic-residuals.ts`
hand-roll today.

**Known integration constraint:** the wrapper needs an awaited WASM init while
our seam is synchronous. Pre-warm during app startup, as the viewer already
does for the OCCT worker.

### 2b. Drawing views → OCCT hidden-line removal (biggest single win)

`dev/briefings/claude.md` currently assigns Core to own "B-Rep projection,
hidden-line classification, section/detail/auxiliary/broken view geometry"
by hand. **That is already in the WASM build we ship.** Verified in
`replicad-opencascadejs/src/replicad_single.d.ts`:

| OCCT binding | References | Gives us |
|---|---|---|
| `HLRBRep_Algo` | 23 | hidden-line removal — visible/hidden edge classification |
| `HLRAlgo_Projector` | 14 | the view projection HLR runs against |
| `BRepMesh_IncrementalMesh` | 8 | controlled tessellation for display |
| `BRepOffsetAPI_MakeOffset` | 11 | exact offsets |
| `GeomAPI_Interpolate` | 6 | spline fitting through points |
| `ShapeUpgrade` | 6 | shape repair / conversion |
| `STEPControl_Writer` | 8 | STEP **export** |
| `IGESControl_Reader` | 0 | **not** exposed — IGES needs a different build |

Do this before writing any drawing projection code. It is the difference
between a hand-written hidden-line classifier and calling the same algorithm
FreeCAD's TechDraw calls.

### 2c. Smaller inheritances, same principle

- `offset` constraint → `BRepOffsetAPI_MakeOffset` instead of our own offset
  residuals (66 unsupported solves today).
- Fit splines / bezier → planegcs B-spline plus `GeomAPI_Interpolate`.
- STEP export → `STEPControl_Writer` (we already read STEP).

## Tier 3 — inherit as specification, not code

FreeCAD is C++ against its own document model; its *app* does not port into a
TS/WASM web product, and we are keeping our design anyway. What transfers is
**behaviour**:

- PartDesign feature semantics — what pad/pocket/dress-up do to a body, and
  the sketch-attachment rules.
- The topological naming problem and how FreeCAD's mitigation works — worth
  reading before our feature-reference model hardens.
- Sketcher interaction rules. Two community documents in the upstream
  `planegcs` repository are the best available write-ups: *Sketcher Lecture*
  (Christoph Blaue) and the *Solver manual* (Abdullah Tahiri).

Write these down as target specs so features stop being discovered mid-build.
Onshape stays the interaction reference it already is.

## Recommended order

1. **HLR for drawings** — pure gain, no dependency, no migration. Blocks the
   Drawing packet, which is queued and not yet written.
2. **Finish the planegcs mapping** — ellipse and B-spline primitives, the
   curve-contact references, and `fix`; then swap the seam and re-pin.
3. **Offsets and spline fitting** to OCCT.
4. **Tier 3 specs**, continuously, ahead of each feature packet.

## License

PlaneGCS is LGPL-2.0-or-later, loaded as a WASM module — the dynamic-linking
case. This repository is already framed as an open system, so the obligation
is compatible, but it is a decision to record rather than assume. OCCT is
LGPL-2.1-with-exception and already in use.

## Spike artefacts (delete when the migration lands or is abandoned)

- `engine/src/sketch/solver/planegcs-spike.ts` — the mapping and the recorder.
- `engine/src/sketch/solver/planegcs-setup.ts` — WASM init + hook registration.
- `engine/vitest.spike.config.ts` — runs the corpus with the hook registered.
- The hook in `solver/solve.ts` — a `globalThis` lookup, nothing imported, so
  production bundles are unaffected (verified: `planegcs` appears in no built
  asset, and the CAD production build passes).

Re-run: `AETHER_SOLVER_REPORT=<file> npx vitest run --config
vitest.spike.config.ts src/sketch` from `Aether CAD/engine`.
