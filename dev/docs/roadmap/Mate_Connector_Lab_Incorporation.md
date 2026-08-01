# Mate Connector Lab → Production Incorporation

Reviewed 2026-08-01 (Claude) at Jonathan's direction. `dev/OCCTMateLab/` is
Codex's isolated browser proof of connector-first mate authoring. Its model
is correct and production adopts it in the packets below; the lab itself
stays an isolated reference under `dev/`.

## What the lab proves (and production lacks)

1. **Connector-first authoring.** Persistent, stable-ID, part-local
   `MateConnector` anchors placed independently of any mate, rendered as
   triads that follow their part. Mates then select two existing connectors.
   Production instead infers two transient frames mid-placement and forgets
   them. Connectors as durable entities are "the other half of mates".
2. **Exact multi-candidate inference.** Per hovered face, the lab surfaces
   ALL snap candidates from analytic B-Rep — face center, circular-edge
   centers (exact circle axis frames), edge midpoints, vertices, cylinder
   axis — deduped by kind+origin epsilon (1e-7). Production's picker returns
   only the single nearest face/edge/vertex/axis, which is why placement
   accuracy feels bad.
3. **Isolation of inference failures.** One face whose analytic query throws
   degrades that face only, never discards the part (the lab's blank-import
   fix). Production's picker should adopt the same policy.

## Adoption packets

### Packet 1 — multi-candidate inference in the native picker
Port the lab's candidate taxonomy (`face-center | edge-midpoint | vertex |
circle-center | cylinder-axis`) into `CADMetalFeaturePicker`: enumerate all
candidates for the hovered face from the shim's exact topology, snap to the
nearest within a pixel threshold, and report the full candidate set so the
viewport can illuminate the nodes and draw the hover triad. Add the Shift
face-lock. This is the accuracy fix Jonathan is waiting on.

### Packet 2 — persistent connectors (engine-owned)
Character format: parts gain a `mate_connectors:` list (stable `id`, name,
frame) — engine-side model/loader/serializer/bridge (`add_connector`
existed as a named gap). The app renders connector triads on both CAD
engines (reference-geometry style) and mate placement selects saved
connectors first, inferred frames second — matching the lab flow.

### Packet 3 — assembly-graph policy
The lab's conservative rule (a moving part cannot be re-used as moving until
cleared) is a placeholder; the engine already owns the real joint graph.
Production replaces the rule with engine validation feedback (cycle and
over-constraint reporting through `add_mate` errors).

## Theme

The lab's visual environment shipped as production theme **"Mate Lab"**
(light `#f2f5f8` studio, steel-blue `#79a9c2` parts, slate edges, cyan/
orange selection accents, bright hemisphere-style lighting).
