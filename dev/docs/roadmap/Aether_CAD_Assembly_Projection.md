# Aether CAD assembly bridge projection

**Status:** frozen frontend integration contract; canonical v1 producer and
workspace persistence shipped 2026-08-14. Product-controller wiring remains
separate presentation work.  
**Owner:** Aether Core owns semantic state, validation, solving, persistence,
and derived BOM data. Aether CAD owns presentation, selection, drafts, and
command dispatch.

## Purpose

This contract is the narrow seam required to finish the Assembly, Mate, and
BOM workbenches without creating a browser-owned assembly model. It is a
read-only projection of canonical Core state plus typed commands that ask Core
to mutate that state.

The projection is not a second document format. It is disposable, may be
requested again at any time, and is never serialized by the UI as document
truth. The canonical persisted target remains the `.aether` graph described in
[`Aether_Workspace_Format.md`](Aether_Workspace_Format.md).

## Boundary rules

- Core assigns every semantic ID and owns the workspace revision.
- Core owns connector-frame normalization and composition, mate type and DOF
  meaning, validation, solve order, limit enforcement, relations, grounding,
  suppression effects, and BOM aggregation.
- CAD may keep presentation-only state such as selection, expanded rows,
  active panel, column widths, filters, camera, and an uncommitted form draft.
- CAD may render a Core-provided preview solution, but it does not calculate a
  mate transform or infer remaining DOF from mate names.
- The TypeScript exact-geometry package may infer selectable topology and
  display exact Bodies. It does not become an independently editable assembly
  graph or solver.
- Every numeric field has an explicit unit suffix. A display-unit preference
  only formats values.
- Product views consume stable IDs, never display names, array indexes, OCCT
  handles, mesh triangle indexes, or DOM IDs as semantic identity.

## Transport envelope

The existing local HTTP bridge remains the transport. Requests use its current
shape:

```json
{
  "id": "request-uuid",
  "method": "describe_assembly",
  "params": { "handle": "workspace-handle", "assembly_id": "asm-uuid" }
}
```

Successful responses keep the established `{id, result}` envelope. Errors
keep `{id, error:{code,message,path}}`. Assembly mutations additionally use an
`expected_revision` string. A stale revision returns `revision_conflict` and
does not partially mutate the graph.

All successful assembly mutations return the same refreshed payload:

```json
{
  "handle": "workspace-handle",
  "revision": "opaque-monotonic-revision",
  "assembly": {},
  "solution": {},
  "bom": {}
}
```

This full refresh is intentional for v1. It gives every workbench one
authoritative snapshot and avoids optimistic patches becoming a second truth.

## Read projection

`describe_assembly` returns `AssemblyProjectionV1`:

```text
AssemblyProjectionV1
  schema_version: 1
  workspace_id: StableID
  revision: string
  assembly_id: StableID
  capabilities: AssemblyCapabilities
  assemblies: AssemblyDefinition[]
  part_definitions: PartDefinition[]
  instances: AssemblyInstance[]
  connector_definitions: ConnectorDefinition[]
  mates: MateProjection[]
  relations: RelationProjection[]
  configurations: ConfigurationProjection[]
  issues: Diagnostic[]
```

Arrays are deterministically ordered by Core. The UI may sort a view locally,
but it must retain entity IDs when it does so.

### Capability projection

Capabilities prevent enabled inert controls and allow one UI build to run
against older Core versions:

```text
AssemblyCapabilities
  can_edit_instances: boolean
  can_edit_connectors: boolean
  supported_mate_type_ids: string[]
  can_edit_relations: boolean
  can_solve_tree: boolean
  can_solve_loops: boolean
  can_edit_nested_assemblies: boolean
  can_project_bom: boolean
  can_save_workspace: boolean
  unavailable_reasons: { capability_id: string, reason: string }[]
```

A missing or false capability disables or removes its command with the
provided reason. The UI never guesses support from entity content.

### Definitions and instances

```text
PartDefinition
  id: StableID
  name: string
  part_number: string | null
  description: string | null
  material_id: StableID | null
  mass_kg: number | null
  source: SourceProjection
  custom_properties: { key: string, value: string }[]

SourceProjection
  kind: "authored" | "packed" | "linked" | "imported"
  label: string
  asset_ref: string | null
  status: "resolved" | "missing" | "stale" | "read_only"

AssemblyDefinition
  id: StableID
  name: string
  description: string | null
  root_instance_ids: StableID[]

AssemblyInstance
  id: StableID
  parent_assembly_id: StableID
  definition_kind: "part" | "assembly"
  definition_id: StableID
  name: string
  parent_instance_id: StableID | null
  rest_transform: TransformProjection
  solved_world_transform: TransformProjection
  grounded: boolean
  suppressed: boolean
  visible: boolean
  source_status: "resolved" | "missing" | "stale" | "read_only"

TransformProjection
  position_m: [number, number, number]
  rotation_quaternion_xyzw: [number, number, number, number]
```

`rest_transform` is authored semantic state. `solved_world_transform` is a
derived result for rendering. CAD never writes the solved transform back as a
rest transform unless an explicit Core command defines that operation.

### Connector definitions

Connectors are owned by Part definitions and use Part-local frames. A mate
endpoint combines a connector definition with a specific Assembly instance.

```text
ConnectorDefinition
  id: StableID
  part_definition_id: StableID
  name: string
  frame_part_local: ConnectorFrame
  provenance: ConnectorProvenance
  suppressed: boolean

ConnectorFrame
  origin_m: [number, number, number]
  primary_axis_xyz: [number, number, number]
  secondary_axis_xyz: [number, number, number]

ConnectorProvenance
  kind: "face" | "edge" | "vertex" | "datum" | "manual"
  stable_feature_id: StableID | null
  label: string | null
```

Core validates that axes form a finite right-handed frame and normalizes them
according to its connector policy. Renderer hit information may help create a
draft provenance reference, but it is never a connector ID.

### Mates, DOF, and relations

The engine mate-type catalog remains the source for names, categories,
controls, and DOF templates. The assembly projection carries instance data:

```text
MateProjection
  id: StableID
  name: string
  type_id: string
  endpoint_a: MateEndpoint
  endpoint_b: MateEndpoint
  dofs: DOFProjection[]
  controls: { key: string, value: boolean | number | string }[]
  suppressed: boolean
  solve_state: "satisfied" | "warning" | "failed" | "suppressed"
  diagnostic_ids: StableID[]

MateEndpoint
  instance_id: StableID
  connector_definition_id: StableID

DOFProjection
  id: StableID
  name: string
  kind: "rotation" | "translation"
  value_rad: number | null
  value_m: number | null
  neutral_rad: number | null
  neutral_m: number | null
  limit_min_rad: number | null
  limit_max_rad: number | null
  limit_min_m: number | null
  limit_max_m: number | null
  state: "driven" | "dependent" | "free" | "suppressed"

RelationProjection
  id: StableID
  kind: string
  driver_dof_id: StableID
  driven_dof_id: StableID
  ratio: number
  offset_rad: number | null
  offset_m: number | null
  reversed: boolean
  suppressed: boolean

ConfigurationProjection
  id: StableID
  name: string
  active: boolean
  suppressed_instance_ids: StableID[]
  overridden_dof_ids: StableID[]
```

Exactly one of the rotation or translation value/unit families is populated
for a DOF. A relation offset uses the driven DOF's unit family. The UI does
not derive this choice from labels.

### Solve projection

`solve_assembly` and every successful mutation return:

```text
AssemblySolutionProjection
  status: "solved" | "unconverged" | "invalid"
  revision: string
  instance_world_transforms: { instance_id: StableID, transform: TransformProjection }[]
  dof_values: { dof_id: StableID, value_rad: number | null, value_m: number | null }[]
  remaining_free_dof_count: number
  residual: number | null
  iterations: number
  limit_violations: LimitViolation[]
  diagnostic_ids: StableID[]
```

```text
LimitViolation
  dof_id: StableID
  value_rad: number | null
  value_m: number | null
  limit_min_rad: number | null
  limit_max_rad: number | null
  limit_min_m: number | null
  limit_max_m: number | null
```

Unconverged is data, not a transport failure. The renderer may show the
returned last solution while CAD presents the warning. `invalid` means no new
semantic mutation was committed unless the individual command explicitly
documents otherwise.

### Diagnostics

```text
Diagnostic
  id: StableID
  severity: "info" | "warning" | "error"
  code: string
  message: string
  entity_ids: StableID[]
  field_path: string | null
  recoverable: boolean
```

Messages are operator-facing. Codes and entity IDs drive selection and tests.
CAD does not parse message text to infer behavior.

### BOM projection

`project_bom` is derived Core output:

```text
BOMProjectionV1
  schema_version: 1
  assembly_id: StableID
  revision: string
  mode: "hierarchical" | "flattened"
  rows: BOMRow[]
  total_mass_kg: number | null
  diagnostic_ids: StableID[]

BOMRow
  row_id: string
  parent_row_id: string | null
  part_definition_id: StableID
  quantity: number
  part_number: string | null
  name: string
  description: string | null
  material_name: string | null
  unit_mass_kg: number | null
  extended_mass_kg: number | null
  source_label: string | null
  custom_properties: { key: string, value: string }[]
```

`row_id` is stable only within the `(assembly_id, revision, mode)` projection;
selection that must survive a rebuild uses `part_definition_id`. Suppressed
and configuration-excluded instance rules are applied by Core before rows are
returned.

## Command surface

The first complete vertical slice requires these bridge verbs:

| Group | Required verbs |
|---|---|
| Workspace | `new_workspace`, `load_workspace`, `save_workspace`, `describe_workspace` |
| Assembly read | `describe_assembly`, `project_bom`, `mate_types`, `relation_types` |
| Part definitions | `add_part_definition`, `update_part_definition`, `remove_part_definition` |
| Instances | `add_instance`, `update_instance`, `remove_instance`, `move_instance`, `set_instance_grounded`, `set_instance_suppressed` |
| Connectors | `add_connector`, `update_connector`, `remove_connector`, `list_connectors` |
| Mates | `preview_mate`, `add_mate`, `update_mate`, `remove_mate` |
| Relations | `add_relation`, `update_relation`, `remove_relation` |
| Solve | `solve_assembly`, `set_dof_value` |

Existing bridge verbs may be adapted internally. The frontend calls only the
published capability-backed surface and does not reconstruct a whole rig DTO
to simulate an incremental assembly mutation.

The Part-definition verbs are additive producer inputs needed to create an
Assembly without asking the browser to author a whole graph DTO. Core assigns
their IDs. Each uses the same `expected_revision` and refreshed mutation
envelope as the other semantic mutations.

Every mutation receives `handle`, `expected_revision`, and its typed command
payload. It is atomic: validation failure, stale revision, missing dependency,
or unsupported capability leaves canonical state unchanged.

`preview_mate` is explicitly non-mutating and returns a preview solution plus
diagnostics. `add_mate` is the commit. The UI may discard a preview at any
time without sending a rollback command.

## Persistence requirements

- `new_workspace` creates a Core-owned handle and stable workspace ID.
- `save_workspace` writes a deterministic `.aether` container through the
  canonical serializer; the browser never assembles ZIP entries itself.
- `load_workspace` validates all semantic versions before replacing the open
  handle state.
- Save and reopen preserve semantic IDs, authored transforms, connector
  frames, mate/DOF IDs, grounding, suppression, relations, configurations,
  and deterministic graph ordering.
- Kernel meshes and B-Rep data remain disposable caches. Deleting them does
  not change the assembly projection after rebuild.
- Legacy `.cadpart` opens through a one-way Part-subgraph importer. The same
  open Part is not editable simultaneously as independent `.cadpart` and
  `.aether` truths.

## Frontend integration sequence

1. Add a transport client and structural decoder for this projection. Reject
   unknown required schema versions before publishing UI state.
2. Replace the current transient connector/mate arrays with one latest Core
   projection. Keep only form drafts and selection locally.
3. Build the Assembly tree from `assemblies`, `instances`, connectors, mates,
   relations, and diagnostics using the shared `Tree` component.
4. Build mate creation and inspection from the type catalog and Core preview /
   commit responses using shared fields, popovers, and property grids.
5. Build hierarchical and flattened BOM views from `BOMProjectionV1` using the
   shared `DataTable`. Sorting, filtering, and column layout remain
   presentation-only.
6. Enable Assembly in New/Open only after persistence, stable-ID round-trip,
   and at least fastened/revolute/prismatic solve gates pass.

## Backend acceptance gates

The producer packet is not complete until deterministic tests prove:

1. Create a workspace with two Part definitions, three instances, two
   reusable connector definitions, and one Assembly; describe returns stable
   deterministic IDs and ordering.
2. Preview then commit fastened, revolute, and prismatic mates. Preview does
   not increment revision; commit increments once and returns a fresh
   projection and solution.
3. Grounding and suppression are reflected in solution and BOM output without
   UI-side filtering rules.
4. Relation and DOF values round-trip in their explicit native units; limit
   violations return typed diagnostics.
5. A stale `expected_revision` produces `revision_conflict`, performs no
   partial mutation, and a subsequent describe is unchanged.
6. Save `.aether`, release the handle, reopen, and compare semantic graph hash,
   entity IDs, projection, solution, and BOM.
7. Delete/corrupt geometry caches and reopen; semantic projection remains
   equal and diagnostics report only rebuild/cache state.
8. HTTP `/rpc` subprocess coverage exercises the same verbs and envelopes as
   direct bridge tests.
9. The frontend can render empty, populated, filtered-empty, read-only,
   missing-source, validation-error, unconverged, and background-save states
   solely from capabilities, projection data, and diagnostics.

## Drawing dependency

The Drawing workbench remains downstream. It may consume Assembly and BOM IDs
from this contract, but base/projected/section/detail vector geometry must come
from the exact Core contract in
[`Aether_CAD_Drawing_Projection.md`](Aether_CAD_Drawing_Projection.md). CAD
must not derive technical drawing curves from the display mesh.
