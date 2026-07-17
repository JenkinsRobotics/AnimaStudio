# Loading at scale — hundreds of parts, GB workspaces (planning)

> Jonathan, 2026-07-16: a real assembly (31 STLs, 34 MB, one 234k-triangle
> part) crashed the viewport. The immediate cause is fixed; this doc is the
> honest roadmap for making import/preview survive **hundreds of parts and
> GB-scale workspaces**, so we build the expensive pieces only when a real
> workspace needs them — not speculatively.

## What actually broke, and what's already robust

Diagnosis of the crash: the CAD-selection **topology** (coplanar-face grouping
+ per-face triangle geometry in `ImportedMeshFace`, plus edges/corners) was
computed **eagerly for every part on load** with no bound. On a 234k-triangle
part it allocates hundreds of MB of redundant geometry; ×31 parts → OOM kill.
RealityKit renders the raw meshes fine — the topology step was the killer.

Already true (verified in the loader):

- **Parsing runs off the main thread.** `ModelIOImporter.load` is a plain enum
  called via `Task.detached`; the UI does not freeze during a parse.
- **Per-file errors are isolated.** The per-part loop uses `try?` and falls back
  to a placeholder body, so one corrupt STL among hundreds cannot crash a load.
- **Topology is now bounded** (shipped): skipped above
  `maxTopologyTriangles = 40k` per file. Heavy parts still load and render with
  whole-part selection; small parts keep face/edge selection. This scales at any
  part count because it is a per-file test.

## The real ceiling at GB scale

After the topology fix, the next wall is **raw mesh + GPU memory**: every part
is held at full resolution in the entity tree forever. Hundreds of dense parts =
GB of vertex/index buffers resident + their GPU meshes. Loading is also **serial
and unbounded in time** — fine for tens of parts, slow for hundreds — and there
is **no progress/cancel**, so a big load looks like a hang.

## Phased hardening (do a phase when a workspace needs it, not before)

**P1 — Preview level-of-detail (the memory lever).** Decimate dense meshes to a
preview budget (target ~20–40k triangles/part) at import; keep the full-res
source on disk for hardware/export. A viewport does not need 234k triangles per
part. Needs real simplification (vertex-cluster or quadric error) — naive
triangle-dropping leaves holes, so this is a genuine implementation, not a
one-liner. Biggest single win for GB workspaces.

**P2 — Bounded-parallel load + progress/cancel.** Split `loadWithTopology` into
an off-main *parse* stage and an on-main *entity-build* stage; run parses
through a bounded `TaskGroup` (≈4–6 concurrent) so hundreds of parts load
faster without a memory spike. Surface per-part progress and a cancel button.
The parse/build split is the enabling refactor; the UI is Codex's lane.

**P3 — Lazy per-part topology.** Replace the blunt 40k cap with on-demand
topology: compute feature edges/faces only when a part is first hovered for
selection, cache it, evict under memory pressure. Restores face/edge selection
on heavy parts without paying for it on load.

**P4 — Streaming / working-set bound.** For GB workspaces that exceed RAM: load
geometry on demand (visible / near-camera first), evict off-screen parts, back
the cache with the on-disk project assets. Only needed once a real workspace
overflows memory — measure first.

**P5 — Import-time guardrails.** Report total triangle/byte budget on import;
warn (don't silently drop) when an assembly is very large; let the user pick
LOD aggressiveness. Small, do alongside P1.

## Sequencing

P1 (LOD) and P2 (bounded-parallel + progress) are the two that make "hundreds of
parts" pleasant and "GB" survivable; do them first, against a real large
workspace so the budgets are measured, not guessed. P3/P4 are refinements. The
shipped topology cap holds the line until then.
