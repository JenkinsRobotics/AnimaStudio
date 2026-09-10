# Aether CAD architecture

Aether CAD is a local-first web CAD foundation. It combines editable Part
feature history, exact OCCT B-Rep evaluation, STEP assembly import, and WebGPU
display while keeping each responsibility replaceable and testable.

It is not yet a complete Onshape replacement. New CAD features should extend
the layers below instead of adding behavior directly to `main.ts` or
`viewer.ts`.

## Dependency direction

```text
domain DTOs
  ├─ pure frame / inference / mate-state functions
  ├─ OCCT exact-topology adapter → worker transport
  └─ renderer presentation → application shell
```

The dependency direction is one-way:

- Aether CAD UI and viewport modules import engine semantics through
  `aether-core.ts`; that facade is the future package/process boundary.
- Persistent Assembly/Mate/BOM state crosses the local Core HTTP bridge as the
  renderer-free projection and revisioned mutation responses decoded by
  `cad-assembly-bridge.ts`.
  Browser state may retain drafts and selection, but never becomes a second
  editable assembly graph.
- `cad-assembly-controller.ts` owns the single open Core workspace handle and
  revision-coherent projection lifecycle. Browser open/save passes opaque
  `.aether` bytes through Core; JavaScript never reads or writes the ZIP. The
  controller also forwards selected-instance Ground/Float, Suppress/Restore,
  and Remove intents as atomic Core commands; the UI only projects capability,
  selection, and active state. Hierarchical/Flattened BOM selection likewise
  requests a new Core projection; React never groups canonical BOM rows.
  Component insertion is a revisioned Core transaction sequence: the browser
  submits one validated authoring draft, Core creates the Part definition, the
  controller reads Core's assigned stable ID, and Core creates the instance.
  If the second mutation is rejected, the controller attempts a compensating
  removal of the unused definition and publishes only returned Core snapshots.
  This does not create a browser-owned Assembly graph or claim source geometry.
  Manual connector authoring likewise submits a validated Part-local meter
  origin and two nonparallel axis presets for the selected instance's Part
  definition. Core normalizes and persists the frame; the controller selects
  only the new stable connector ID returned in the coherent projection. This
  path makes no viewport snap or exact-feature provenance claim.
  Persistent mate authoring projects eligible instance-owned connector pairs
  from that same canonical snapshot. Fastened, revolute, and prismatic drafts
  first call Core's non-mutating preview operation; every draft edit invalidates
  the prior result, and Apply remains unavailable until the current revision
  solves successfully. Commit sends `add_mate`, advances the canonical revision,
  selects only Core's returned stable mate ID, and republishes Core's solve and
  BOM projections. Browser code never applies connector transforms or infers
  remaining freedom.
  Selected persistent mates then expose lifecycle intent through the same
  revisioned boundary. Suppress/Restore serializes the complete selected Core
  projection back through `update_mate`, changing only `suppressed`; Remove
  supplies the stable mate ID to `remove_mate`. Core remains responsible for
  dependency validation and solving. A rejected mutation preserves selection,
  while successful removal clears it after the refreshed projection arrives.
  The older Part-session mate proof remains a separate, noncanonical path.
  An active selected revolute or prismatic mate with one free DOF additionally
  exposes value and limit authoring. The UI presents rotations in degrees and
  converts only at the Core boundary; translations remain meters.
  `set_dof_value` owns value edits, while a complete revisioned `update_mate`
  payload owns paired minimum/maximum limit changes. Core returns the solved
  transforms, dependent/free state, and limit violations; the UI neither
  clamps values nor derives those outcomes.
  Persistent relation authoring consumes compatible free DOF options from the
  same snapshot. Gear, rack-and-pinion, screw, and linear drafts carry stable
  driver/driven IDs, an explicit ratio, direction, and driven-unit offset.
  `add_relation` assigns identity and republishes dependency order and solved
  values. Rotation offsets cross the boundary in radians, translation offsets
  in meters, and mixed rotation-to-translation ratios are labeled m/rad. The
  inspector uses Core's solved DOF value so dependent motion is never confused
  with the underlying authored neutral value.
- The OCCT adapter may depend on pure inference and frame math.
- The renderer consumes topology DTOs; it never asks triangles to redefine
  exact CAD geometry.
- Mate state and transform solving do not depend on Three.js or DOM APIs.
- The application shell coordinates features; it does not contain CAD math.

The implementation remains embedded today. Extraction means moving the
implementation behind the same facade after parity tests pass—not creating a
parallel evaluator or exposing OCCT/Three.js objects across the boundary.

## Source map

| File | Responsibility |
| --- | --- |
| `aether-core.ts` | Sole app-facing engine facade and future extraction contract. |
| `part-document.ts` | Versioned `.cadpart` history, validation, and revisions. |
| `part-file.ts` | Deterministic parse/serialize and browser save behavior. |
| `part-feature-tree.ts` | Pure Sketch/Extrude/Body hierarchy projection. |
| `domain.ts` | Renderer-neutral geometry, connector, worker, and mate DTOs. |
| `cad-frame-math.ts` | Right-handed local-coordinate frames and axis placement. |
| `topology-inference.ts` | Pure station, de-duplication, and semantic-priority policy. |
| `exact-topology.ts` | The only OCCT B-Rep-to-connector inference adapter. |
| `occt-part-evaluator.ts` | Ordered Part-history evaluation into exact OCCT solids. |
| `part-geometry.ts` | Exact topology + disposable display projection. |
| `occt.worker.ts` | OCCT lifecycle and typed import/evaluate request routing. |
| `worker-client.ts` | Typed main-thread/worker request boundary. |
| `mate-state.ts` | Transitional viewport connector/mate draft for the Part proof; not persistent assembly truth. |
| `cad-assembly-authoring.ts` | Validated, explicit-SI component-insertion draft and normalization; no stable IDs or Assembly graph ownership. |
| `cad-connector-authoring.ts` | Validated manual Part-local connector draft, axis presets, and explicit-meter normalization; no snap or topology semantics. |
| `cad-mate-authoring.ts` | Validated Fastened/Revolute/Prismatic endpoint drafts and Core mutation payloads; no solving, alignment, or stable-ID ownership. |
| `cad-assembly-bridge.ts` | Typed HTTP transport and structural decoder for the canonical Core Assembly/Mate/BOM projection. |
| `cad-assembly-controller.ts` | Canonical workspace lifecycle, coherent describe/solve/BOM refresh, mutations, and Core-owned file bytes. |
| `cad-assembly-presentation.ts` | Pure canonical Assembly projection mapper for shared Tree/ListBox/PropertyGrid/DataTable datasets. |
| `cad-assembly-workspace-store.ts` | Assembly load/tab/filter/selection/expansion presentation state; no assembly meaning. |
| `cad-bridge-decode.ts` | Shared strict JSON/schema primitives and precise error paths for Core bridge projections. |
| `cad-drawing-bridge.ts` | Typed HTTP transport and structural decoder for exact Core Drawing projections and rebuild state. |
| `cad-drawing-presentation.ts` | Pure exact Drawing mapper for shared Tree/ListBox/PropertyGrid/DataTable datasets. |
| `cad-drawing-workspace-store.ts` | Drawing load/tab/filter/selection/expansion presentation state; no document meaning. |
| `react/DrawingSheetCanvas.tsx` | Accessible SVG renderer for Core-provided exact sheet-space Drawing data only. |
| `react/DrawingWorkspace.tsx` | Canonical-ready Drawing workbench composed from shared collections, inspector, commands, and the exact sheet renderer. |
| `assembly-tree.ts` | Pure STEP-document/Part hierarchy projection. |
| `math.ts` | Renderer-independent homogeneous Fastened-mate transform. |
| `cad-appearance-store.ts` | One renderer-only display, lighting, floor, shadow, finish, and background session snapshot shared by ribbon and Visualization UI. |
| `viewport-appearance.ts` | Pure shaded, shaded-with-edges, wireframe, hidden-line, and ghost rendering policy. |
| `connector-visuals.ts` | Instanced snap nodes and persistent connector triads. |
| `cad-command-registry.ts` | Typed CAD command handlers and enabled/active state. |
| `cad-tool-catalog.ts` | Product-owned traditional CAD workspace/group/tool inventory; each entry routes to a typed action or carries an exact unavailable reason. |
| `cad-presentation-store.ts` | Typed React presentation projection, toolbar mode, independent panel placement, and UI intent dispatch. |
| `cad-selection-store.ts` | One renderer/UI selection snapshot for filter, stable selected entities, preselection, and directional box gesture state. |
| `react/CADTraditionalRibbon.tsx` | Shared-Ribbon projection for the seven-workspace traditional baseline, suite-stage context, and open-document strip. |
| `reference-geometry.ts` | Principal reference-frame definitions and browser projection. |
| `camera-view.ts` | Standard camera views plus renderer-neutral nudge and roll basis math. |
| `cad-camera-presentation-store.ts` | Isolated orientation projection and typed UI-intent bridge between the shared `ViewportNavigationCube` and the viewer camera. |
| `viewer.ts` | Viewport orchestration, camera, picking, and feature interaction. |
| `main.ts` | Part session, Assembly-controller composition, persistent viewport adapter, and command wiring. |

The traditional ribbon is the v1 default. The floating viewport palette remains
an alternate presentation of the same registered commands. Browser,
Properties, and History/Problems panels independently select docked, floating,
or hidden placement; the global Docked, Expanded, and Canvas presets remain
available and Reset returns the three panels to the docked workbench. These are
presentation decisions only and never create CAD state. The app persists them
as local UI preferences, independently of `.cadpart` and `.aether` documents.
All three placement controls consume the product-free `@aether/ui`
`PanelPlacementMenu`; Aether CAD supplies the stable panel identity and retains
preference ownership in `cad-presentation-store.ts`.

The View workspace and Visualization browser project the same typed command and
appearance state. The complete six-face standard-view set plus Isometric, five
display styles, four lighting rigs,
contact shadows, floor/grid modes, material finish, background, and environment
intensity remain renderer presentation only; they never alter exact B-Rep,
feature history, Assembly state, or saved CAD meaning.
The traditional View ribbon and shared command palette expose the discrete
background, finish, feature-edge, ground-mode, and reset choices over that same
store; the Visualization panel remains the detailed control surface for the
continuous environment intensity.

Viewport navigation chrome comes from the product-free `@aether/ui`
`ViewportNavigationCube`. A small camera presentation store publishes only the
renderer orientation and forwards face, Home, nudge, and roll intent to the
existing viewer. Camera basis math remains in `camera-view.ts`; React and the
shared widget do not own renderer behavior or CAD state.

Selection follows the same single-projection rule. Auto, Component, Body,
Face, Edge, and Vertex filters select stable renderer-neutral IDs over exact
topology data. Hover preselection, modifier extension, and directional box
selection update that one snapshot; the Items tree derives selected Part IDs
from it. Left-to-right Window selection requires containment, while
right-to-left Crossing selection accepts intersection. The renderer owns only
hit testing, projection, and highlight presentation.

The Vite development server proxies `/rpc` to the local AnimaCore HTTP bridge.
The clickable macOS wrapper supervises that same bridge and loads the built app
from it on one same-origin port; the superseded static-only launcher server is
gone.

## Invariants

1. **B-Rep is authoritative.** The GPU triangle hit only identifies an exact
   OCCT face. Connector position and orientation come from analytic topology.
2. **Connector frames are Part-local.** Moving a Part moves every connector
   attached to it without recomputing the connector.
3. **A connector is not a mate.** Any number of connector anchors may exist.
   A mate is a separate relationship between two saved connectors.
4. **The solver is renderer-independent.** A future Metal, WebGPU, or native
   viewer must produce the same transform for the same connector pair.
5. **Unsupported topology is fault-isolated.** One unusual edge or face must
   not prevent the remaining Part from loading and rendering.
6. **Names explain intent.** Prefer domain verbs such as
   `extractExactTopology`, `createCandidateCloud`, and
   `solveFastenedMate` over abbreviated or generic helper names.
7. **History is saved; meshes are regenerated.** A `.cadpart` file persists
   semantic features and stable IDs. It never promotes a GPU triangle index to
   document authority.
8. **One exact kernel owns geometry.** OCCT is authoritative today. Alternative
   kernels may be benchmark adapters, never a second silent source of truth.

## Feature inference policy

The current exact inference layer recognizes:

- planar face frames and face centers;
- circular and elliptical edge centers;
- cylinder/shaft/bore axes at trimmed start, center, and end stations;
- conical axes at trimmed start, center, and end stations;
- sphere centers and torus revolution centers;
- edge midpoints and vertices with tangent-aligned secondary axes;
- a safe face-center/normal fallback for unsupported freeform surfaces.

Spatial duplicates collapse to the most meaningful analytic description. For
example, a circular hole center wins over a coincident generic face center.

## Product sequence

Build the product vertically, preserving the boundaries above:

1. **Part document v1 (shipped):** Rectangle Sketch → Extrude → Body, stable
   feature IDs, deterministic `.cadpart` save/open, and exact OCCT rebuild.
2. **2D Sketcher + constraint solver:** line/arc/circle entities, coincidence,
   horizontal/vertical, parallel/perpendicular, tangent, dimensions, live drag,
   solve diagnostics, and a renderer-independent constraint graph.
3. **Feature history commands:** typed create/delete/rename/reorder/suppress,
   undo/redo, dirty state, and failure-aware downstream rebuild.
4. **Stable topology references:** survive feature edits and STEP re-imports;
   never persist transient triangle or OCCT hash numbers as long-term identity.
5. **Selection and inspection:** bodies, faces, edges, vertices, measurements,
   section view, and selection filtering.
6. **Assembly graph (foundation shipped):** persistent instances, reusable
   connectors, fastened/revolute/prismatic mates, DOF/relations, suppression,
   tree solve diagnostics, derived BOM, and deterministic `.aether` open/save.
   Loop solving and over-constraint analysis remain future Core work.
7. **Transform tools:** translate/rotate/plane handles, numeric entry, snapping,
   and command history.
8. **Advanced features:** boolean add/remove/intersect, revolve, sweep, loft,
   fillet, chamfer, draft, shell, patterns, and rebuild diagnostics.

## Kernel decision

The production stack uses Open CASCADE Technology through
OpenCascade.js/Replicad. A Rust/WASM kernel such as Truck could be useful for a
future isolated benchmark because its Rust ownership model and wgpu ecosystem
are attractive. It does not currently replace OCCT's mature STEP/B-Rep feature
coverage for this product, and running both kernels for normal authoring would
double tolerance, topology-naming, and serialization risk. The worker DTO is
the intentional seam for experiments.

Each milestone should add a dedicated feature module and deterministic tests;
the renderer remains a consumer of document state rather than its owner.
