# Aether workspace format

**Status: partially shipped contract.** The canonical Assembly/Mate/BOM v1
graph and deterministic `.aether` ZIP read/write shipped in AnimaCore on
2026-08-14. The browser Part authoring slice still saves one editable Part as
plain JSON in `.cadpart`; see `Aether CAD/PART_FORMAT.md`. Part-feature graph
migration, Drawings, collaboration, and the remaining interop adapters are
still planned.

## Decision

Ship one canonical `.aether` workspace format first.

Part, Assembly, Drawing, animation, and later simulation tabs are typed views
over one deterministic Aether Core state graph. They are not independent data
silos and do not duplicate semantic entities. A mate created in an Assembly
and the joint driven by Aether Animation are the same stable-ID Core entity,
viewed through different product projections.

Typed `.aethpart`, `.aethasm`, and `.aethdrw` exchange packages are deferred
until a real file-per-item workflow requires them. If introduced, they use the
same manifest and graph schema and contain a dependency-closed subset of a
workspace. They do not create new semantic formats.

## Authority hierarchy

In descending order of authority:

1. `state/graph.json` — canonical deterministic semantic state.
2. `state/operations.jsonl` — optional ordered semantic operation history,
   when collaboration/branching lands.
3. kernel B-Rep caches — derived and disposable.
4. render-mesh caches — derived and disposable.
5. thumbnails and editor presentation — derived or product-local.

The feature/constraint graph must be sufficient to rebuild exact geometry.
Deleting every cache must never change document meaning. OCCT native B-Rep
serialization is version-sensitive and therefore can never become document
truth.

## Planned container layout

`.aether` is a deterministic ZIP container with uncompressed, readable JSON
for semantic state. Binary compression is applied only where measurements
justify it.

```text
Autonomous-Rover.aether
├── manifest.json
├── state/
│   ├── graph.json
│   └── operations.jsonl             # optional, planned collaboration log
├── assets/
│   ├── source/                      # packed imported source files
│   └── media/                       # images, audio, video
├── cache/
│   ├── kernel/<cache-key>.brep      # optional, disposable OCCT cache
│   └── render/<cache-key>.meshbin   # optional, disposable display cache
├── previews/
│   └── thumbnail.png
└── editor/
    └── presentation.json            # layouts, expanded rows, camera views
```

ZIP entry names use `/`, are unique, and reject absolute paths or `..` path
segments. Writers produce entries in deterministic lexical order with stable
timestamps so equivalent state can produce byte-stable snapshots.

## Manifest

The manifest identifies schema and compatibility; it does not duplicate the
graph.

```json
{
  "format": "aether-workspace",
  "format_version": 1,
  "workspace_id": "workspace-uuid",
  "name": "Autonomous Rover",
  "core_semantics_version": "1",
  "graph_path": "state/graph.json",
  "graph_sha256": "hex-digest",
  "root_view_ids": ["part-tab-1", "assembly-tab-1"],
  "display_unit_system": "metric"
}
```

`display_unit_system` is an editor preference. It never supplies the meaning
of an otherwise unitless number.

## Canonical graph

The graph uses one stable ID namespace and typed entities. References are IDs,
not array indexes, display names, transient OCCT handles, or GPU triangle IDs.

Entity families are introduced vertically. The shipped Assembly slice includes
Part definitions, Assembly definitions and instances, connector definitions,
mates/DOF/limits, relations, configurations, and their explicit-unit state.
Remaining planned families include:

- views: Part, Assembly, Drawing, Animation, Show;
- reference geometry: origins, axes, planes, named coordinate frames;
- sketch entities and constraints;
- parametric features and Bodies;
- Part definitions and Assembly instances;
- mate connectors, mates, DOF, limits, and relations;
- drawing sheets, projected views, annotations, and BOM projections;
- media and product-extension metadata.

Each entity has `id`, `type`, `schema_version`, and type-specific fields. DAG
edges are explicit stable-ID references. Rebuild order is derived by a stable
topological sort; cycles are validation errors, never renderer behavior.

## Units and frames

Every numeric contract field carries its unit in its name:

- `width_mm`, `depth_mm`, `position_m`;
- `angle_rad`, `limit_min_rad`, `velocity_rad_s`;
- `time_s`, `sample_rate_hz`.

The global display-unit preference controls formatting only. It cannot change
stored values. Coordinate frames follow the standing World → Character → Part
model; connector frames are Part-local. Aether Core owns conversions and frame
composition.

## Part, Assembly, and Drawing views

### Part

A Part view roots one dependency subgraph of sketches, constraints, features,
Bodies, materials, and reference geometry. Multi-body Parts are allowed by the
graph; the first shipped slice currently supports one Body.

### Assembly

An Assembly view contains instances that reference Part definition IDs and
stores transforms, connectors, mates, limits, relations, suppression, and
grounding. Definitions are not copied into every instance.

The renderer-free bridge read model and mutation/solve/BOM envelopes consumed
by Aether CAD are frozen in
[`Aether_CAD_Assembly_Projection.md`](Aether_CAD_Assembly_Projection.md). That
projection is disposable transport data, not another persisted graph.

### Drawing

A Drawing view references Part or Assembly IDs and stores sheets, projection
definitions, dimensions, GD&T annotations, and BOM configuration. Projected
vectors are rebuildable from exact geometry and view definitions.

The exact renderer-free bridge read model, atomic command surface, rebuild
state, and exporter ownership consumed by Aether CAD are frozen in
[`Aether_CAD_Drawing_Projection.md`](Aether_CAD_Drawing_Projection.md). It is
derived transport data, not a second Drawing format.

## CAD-to-animation identity

There is no mate-to-joint export inside the Aether ecosystem.

The Core mate entity already defines connector frames, remaining DOF, limits,
and relations. Aether CAD authors and inspects it. Aether Animation drives the
same DOF IDs and adds product-specific motor/channel mappings, clips, puppetry,
and output routing. Hardware drivers remain outside Aether Core.

Interop exports such as URDF may translate Core entities because they cross an
external format boundary; that translation is not used between Aether
products.

## Cache validity

Every cache entry is optional and must declare a key derived from all inputs
that affect it.

Kernel cache key inputs:

- canonical graph hash;
- Aether Core evaluator version;
- OCCT build/ABI identity;
- modeling tolerance profile.

Render cache key inputs:

- exact-geometry result hash;
- tessellation profile;
- vertex/index binary schema version;
- required appearance attributes.

Unknown or mismatched caches are ignored and rebuilt lazily. Cache failure may
slow opening but may not prevent semantic state from opening.

## Import and export scope

The format contract distinguishes exact CAD from mesh/media assets.

| Format | Planned role | Constraint |
|---|---|---|
| STEP | exact CAD import/export | primary neutral solid/assembly exchange |
| IGES | exact surface/curve import/export | lower priority than STEP |
| STL, OBJ, 3MF | mesh import/export | not silently promoted to editable B-Rep |
| DXF | 2D sketch/drawing exchange | separate 2D adapter |
| Parasolid `.x_t` | not promised | requires Siemens licensing |
| DWG | not promised | requires a licensed implementation such as ODA |

The shipped browser proof currently imports STEP. Other rows remain planned
until an adapter and round-trip fixtures exist.

## Collaboration compatibility

Real-time collaboration is deferred, but the graph must be operation-friendly:
stable IDs, typed semantic commands, deterministic validation, and no hidden
renderer-owned state. A later append-only event stream or CRDT records changes
to the same graph; it does not introduce a second document model.

## Migration from `.cadpart`

The current `.cadpart` JSON remains the shipped, debuggable Part vertical
slice. Migration proceeds in this order:

1. wrap its existing Part document as a Part-rooted graph projection;
2. prove equal OCCT Body output and stable IDs before/after wrapping;
3. add Assembly view entities referencing that Part definition;
4. implement deterministic `.aether` ZIP read/write;
5. keep `.cadpart` import as a legacy Part-subgraph importer;
6. only later consider typed subset-package exports.

At no point may both `.cadpart` state and `.aether` state be independently
editable copies of the same open Part.

## Acceptance gates for v1

- New workspace → create Part → Sketch → Extrude → save `.aether` → reopen
  produces the same graph IDs and exact OCCT Body.
- Create two Part definitions and an Assembly with a mate; Aether Animation
  resolves the same mate/DOF IDs without translation.
- Delete all caches; reopen and rebuild yields identical semantic hashes.
- Change OCCT cache ABI; semantic state opens and invalid caches are ignored.
- Corrupt cache; state still opens with a rebuild warning.
- Unknown semantic schema version fails clearly before mutating open state.
- Deterministic serializer fixtures remain byte-stable.
