# Aether CAD exact Drawing bridge projection

**Status:** frozen frontend integration contract; exact Core producer,
workspace persistence, and exporters are planned.  
**Owner:** Aether Core owns Drawing semantics, exact projection, hidden-line
classification, section construction, associative measurement, validation,
rebuild state, and deterministic export. Aether CAD owns sheet presentation,
selection, command dispatch, and uncommitted placement drafts.

## Purpose

This is the seam required to finish the Drawing workbench without tracing the
display mesh or creating a browser-owned technical-drawing model. It projects
canonical `.aether` Drawing entities and exact derived sheet vectors into a
renderer-free read model.

The projection is disposable transport data. The canonical sheet, view,
annotation, and style definitions live in `state/graph.json`; exact view curves
are rebuildable derived data. The UI never serializes this projection as an
independent document.

## Non-negotiable boundaries

- View geometry comes from exact B-Rep topology and Core camera/view
  definitions, never WebGPU triangles, screen pixels, or canvas paths.
- Core performs visible/hidden-line classification, tangent-edge policy,
  section intersections and hatching boundaries, detail clipping, break
  transforms, center-mark inference, and view dependency rebuild.
- Core measures associative dimensions from referenced exact entities. CAD may
  edit text position, witness-line placement, and style, but not the measured
  value.
- Core owns projection-standard meaning (first-angle or third-angle), view
  orientation, scale composition, sheet bounds, and export fidelity.
- Drawing annotations reference stable semantic/topology IDs. They do not
  reference OCCT handles, mesh indexes, SVG element IDs, or row positions.
- BOM content is the Core-derived Assembly BOM projection. Drawing owns only
  table placement, visible columns, split points, balloons, and item-number
  presentation tied to BOM row keys/Part IDs.
- Every field names its unit. Canonical sheet geometry uses millimetres;
  model-space geometry keeps its native explicit unit fields.
- CAD retains only presentation state and an uncommitted command draft. A
  successful mutation returns a fresh authoritative projection.

## Transport and concurrency

The existing local `/rpc` bridge envelope is retained. Reads use:

```json
{
  "id": "request-uuid",
  "method": "describe_drawing",
  "params": { "handle": "workspace-handle", "drawing_id": "drawing-uuid" }
}
```

Every mutation takes `handle`, `expected_revision`, and its typed payload. A
stale revision returns `revision_conflict` without partial mutation. Successful
mutations return:

```text
DrawingMutationResultV1
  handle: string
  revision: string
  drawing: DrawingProjectionV1
  rebuild: DrawingRebuildProjection
```

`preview_*` verbs are non-mutating and do not increment revision. They return
draft sheet geometry and diagnostics that may be discarded without rollback.

## Read projection

```text
DrawingProjectionV1
  schema_version: 1
  workspace_id: StableID
  revision: string
  drawing_id: StableID
  name: string
  capabilities: DrawingCapabilities
  active_sheet_id: StableID | null
  sheets: DrawingSheetProjection[]
  styles: DrawingStyleProjection[]
  issues: DrawingDiagnostic[]
```

Core returns deterministic array ordering. UI sorting/filtering must retain
semantic IDs.

### Capabilities

```text
DrawingCapabilities
  can_edit_sheets: boolean
  supported_view_type_ids: string[]
  supported_annotation_type_ids: string[]
  can_project_hidden_lines: boolean
  can_project_sections: boolean
  can_project_bom: boolean
  can_rebuild: boolean
  can_save_workspace: boolean
  export_format_ids: string[]
  unavailable_reasons: { capability_id: string, reason: string }[]
```

The UI never guesses availability from existing content. False/missing
capabilities remove or disable commands with the Core reason.

## Sheets and title blocks

```text
DrawingSheetProjection
  id: StableID
  name: string
  index: number
  width_mm: number
  height_mm: number
  orientation: "landscape" | "portrait"
  projection_standard: "first_angle" | "third_angle"
  default_scale_ratio: number
  border: SheetBorderProjection
  title_block: TitleBlockProjection
  views: DrawingViewProjection[]
  annotations: DrawingAnnotationProjection[]
  bom_tables: DrawingBOMTableProjection[]
  layers: DrawingLayerProjection[]
  revision: string

SheetBorderProjection
  margin_left_mm: number
  margin_right_mm: number
  margin_top_mm: number
  margin_bottom_mm: number
  zone_rows: number
  zone_columns: number

TitleBlockProjection
  id: StableID
  template_id: StableID
  origin_sheet_mm: [number, number]
  width_mm: number
  height_mm: number
  fields: { field_id: StableID, label: string, value: string, editable: boolean }[]
```

Sheet index is presentation order; sheet ID is identity. Reordering sheets
does not rewrite references.

## Drawing views

```text
DrawingViewProjection
  id: StableID
  name: string
  type_id: "base" | "projected" | "section" | "detail" | "auxiliary" | "broken"
  source: DrawingViewSource
  parent_view_id: StableID | null
  origin_sheet_mm: [number, number]
  boundary_sheet_mm: [number, number, number, number]
  scale_ratio: number
  orientation_model_to_view_quaternion_xyzw: [number, number, number, number]
  label: string | null
  display: DrawingViewDisplay
  state: "current" | "stale" | "rebuilding" | "failed" | "suppressed"
  geometry: DrawingGeometryProjection
  diagnostic_ids: StableID[]

DrawingViewSource
  kind: "part" | "assembly"
  entity_id: StableID
  configuration_id: StableID | null
  exploded_state_id: StableID | null

DrawingViewDisplay
  hidden_lines: "removed" | "visible"
  tangent_edges: "removed" | "visible" | "font"
  show_scale_label: boolean
  show_view_label: boolean
```

Projected and auxiliary view orientation is derived by Core from parent view,
placement direction, and the sheet projection standard. The UI sends the
placement draft; it does not construct the resulting quaternion.

Section view definitions additionally persist cutting-line references,
direction, depth policy, and hatch style. Detail views persist the parent view
and exact sheet-space clipping boundary. Broken views persist break-line
definitions and gap, while Core owns the transformed exact curves.

## Exact sheet geometry

`DrawingGeometryProjection` is derived, disposable output:

```text
DrawingGeometryProjection
  geometry_version: 1
  source_exact_geometry_hash: string
  primitives: DrawingPrimitive[]
  hatch_regions: HatchRegionProjection[]
  snap_points: DrawingSnapPoint[]
  bounds_sheet_mm: [number, number, number, number]
```

All points are sheet-space millimetres after view scale. Each primitive has a
stable derived `primitive_id` within `(view_id, source_exact_geometry_hash)`
and carries source references for selection/associativity:

```text
DrawingPrimitive (common fields)
  primitive_id: string
  kind: "line" | "arc" | "circle" | "ellipse" | "nurbs"
  layer_id: StableID
  visibility_class: "visible" | "hidden" | "tangent" | "center" | "section"
  source_entity_ids: StableID[]
  source_topology_ids: StableID[]
```

Kind-specific geometry:

```text
line
  start_sheet_mm: [number, number]
  end_sheet_mm: [number, number]

arc
  center_sheet_mm: [number, number]
  radius_mm: number
  start_angle_rad: number
  end_angle_rad: number
  counterclockwise: boolean

circle
  center_sheet_mm: [number, number]
  radius_mm: number

ellipse
  center_sheet_mm: [number, number]
  major_axis_sheet_mm: [number, number]
  minor_radius_mm: number
  start_parameter_rad: number
  end_parameter_rad: number

nurbs
  degree: number
  control_points_sheet_mm: [number, number][]
  knots: number[]
  weights: number[]
```

```text
HatchRegionProjection
  region_id: string
  boundary_primitive_loops: string[][]
  style_id: StableID
  angle_rad: number
  spacing_mm: number

DrawingSnapPoint
  snap_id: string
  kind: "endpoint" | "midpoint" | "center" | "quadrant" | "intersection"
  point_sheet_mm: [number, number]
  primitive_ids: string[]
  source_entity_ids: StableID[]
  source_topology_ids: StableID[]
```

Hatch boundaries are exact closed primitive loops. The renderer clips and
draws the pattern; it does not infer section regions. Snap points are derived
interaction assistance, not persisted truth.

## Layers and styles

```text
DrawingLayerProjection
  id: StableID
  name: string
  visible: boolean
  printable: boolean
  locked: boolean
  style_id: StableID

DrawingStyleProjection
  id: StableID
  name: string
  line_weight_mm: number
  line_pattern: "solid" | "dashed" | "dash_dot" | "center"
  dash_pattern_mm: number[]
  color_rgba: [number, number, number, number]
  text_height_mm: number
  font_family: string
  arrow_size_mm: number
  decimal_places: number
```

Styles are canonical Drawing entities. Screen antialiasing, zoom, and backing
scale remain renderer presentation.

## Annotations and associative dimensions

```text
DrawingAnnotationProjection
  id: StableID
  type_id: "linear_dimension" | "angular_dimension" | "radial_dimension" |
           "diameter_dimension" | "ordinate_dimension" | "center_mark" |
           "centerline" | "note" | "datum" | "feature_control_frame" |
           "surface_finish" | "weld_symbol" | "balloon"
  view_id: StableID | null
  layer_id: StableID
  style_id: StableID
  text: string
  text_origin_sheet_mm: [number, number]
  leader_points_sheet_mm: [number, number][]
  references: DrawingReference[]
  measurement: DrawingMeasurement | null
  state: "current" | "dangling" | "overridden" | "suppressed"
  diagnostic_ids: StableID[]

DrawingReference
  source_entity_id: StableID
  source_topology_id: StableID | null
  view_id: StableID
  attachment: "point" | "edge" | "center" | "tangent" | "quadrant"

DrawingMeasurement
  kind: "length" | "angle" | "radius" | "diameter"
  value_mm: number | null
  value_rad: number | null
  tolerance_upper_mm: number | null
  tolerance_lower_mm: number | null
  tolerance_upper_rad: number | null
  tolerance_lower_rad: number | null
  display_text: string
  overridden_text: boolean
```

Exactly one measurement unit family is populated. Core produces formatted
dimension text from canonical value, tolerance, unit, and style settings. The
UI may submit an explicit text override command; it never overwrites the
canonical measured value.

## Drawing BOM tables and balloons

```text
DrawingBOMTableProjection
  id: StableID
  assembly_id: StableID
  bom_revision: string
  mode: "hierarchical" | "flattened"
  origin_sheet_mm: [number, number]
  width_mm: number
  visible_column_ids: string[]
  rows: DrawingBOMRowProjection[]
  diagnostic_ids: StableID[]

DrawingBOMRowProjection
  row_key: string
  item_number: string
  part_definition_id: StableID
  quantity: number
  cells: { column_id: string, display_text: string }[]
```

Balloon annotations reference the table ID and Part/BOM row identity. Core
reports stale tables when the Assembly revision changes; CAD does not compare
quantities itself.

## Rebuild and diagnostics

```text
DrawingRebuildProjection
  drawing_id: StableID
  revision: string
  status: "current" | "stale" | "rebuilding" | "partially_failed" | "failed"
  completed_view_count: number
  total_view_count: number
  cancellable: boolean
  diagnostic_ids: StableID[]

DrawingDiagnostic
  id: StableID
  severity: "info" | "warning" | "error"
  code: string
  message: string
  entity_ids: StableID[]
  field_path: string | null
  recoverable: boolean
```

Exact view rebuild may be a background task. Cancellation is cooperative:
Core finishes or discards the current non-abortable kernel operation and does
not publish a partial primitive set for that view. Other successfully rebuilt
views may remain current and the overall state becomes `partially_failed` or
`stale` with diagnostics.

## Command surface

| Group | Required verbs |
|---|---|
| Drawing lifecycle | `add_drawing`, `describe_drawing`, `remove_drawing` |
| Sheets | `add_sheet`, `update_sheet`, `remove_sheet`, `reorder_sheets`, `set_active_sheet` |
| Views | `preview_drawing_view`, `add_drawing_view`, `update_drawing_view`, `remove_drawing_view`, `rebuild_drawing` |
| Annotations | `preview_annotation`, `add_annotation`, `update_annotation`, `remove_annotation` |
| BOM | `add_drawing_bom`, `update_drawing_bom`, `remove_drawing_bom`, `refresh_drawing_bom` |
| Styles/layers | `add_drawing_style`, `update_drawing_style`, `add_drawing_layer`, `update_drawing_layer` |
| Export | `export_drawing_pdf`, `export_drawing_dxf`, `export_drawing_svg` |

Mutation payloads use stable IDs and explicit units. Every mutation is atomic
and returns a refreshed Drawing projection plus rebuild state. Existing Core
workspace load/save verbs persist the canonical definitions in `.aether`.

Export verbs return a task/result descriptor and bytes or a bridge-managed
file handle. PDF/DXF/SVG generation consumes the same exact primitives and
styles; the browser does not independently regenerate technical geometry.

## Frontend integration sequence

1. Add a strict structural decoder and injected `/rpc` client. Reject unknown
   required schema/geometry versions before publishing UI state.
2. Add one Drawing presentation store for load/rebuild state, active sheet,
   selection, expanded tree rows, active tool, and uncommitted placement.
3. Render Sheets/Views/Annotations/BOM with shared Tree/ListBox/DataTable and
   read-only PropertyGrid projections.
4. Render exact primitives in a sheet canvas/SVG adapter that consumes only
   sheet-space data. Rendering code does no hidden-line or section analysis.
5. Build typed view/annotation property popovers from Core catalogs and
   capabilities. Preview and commit remain separate.
6. Enable Drawing in New/Open/Export only after persistence, exact projection,
   rebuild, and at least PDF/SVG acceptance gates pass.

## Backend acceptance gates

1. Create a Drawing with A3 and A4 sheets; reorder, save `.aether`, reopen, and
   preserve all IDs, sizes, projection standards, title-block fields, and
   deterministic graph hash.
2. Project a deterministic stepped exact Part into base Front/Top/Right and
   isometric views. Primitive hashes and visible/hidden classification are
   stable across runs and do not depend on tessellation settings.
3. Add a projected view under both first-angle and third-angle standards;
   placement/orientation matches the standard and round-trips.
4. Create a full and offset section through known holes. Exact section curves,
   hatch region boundaries, and source references remain stable after reopen.
5. Add detail, auxiliary, and broken views; parent dependencies and stale
   propagation rebuild in deterministic order.
6. Add linear, angular, radial, and diameter dimensions. Core measurements
   match exact geometry, use the correct unit family, survive a non-breaking
   source edit, and become typed dangling diagnostics when topology disappears.
7. Add a flattened Assembly BOM plus balloons. Quantity/item mapping comes
   from the Assembly BOM projection and becomes stale after an Assembly change.
8. A stale `expected_revision` returns `revision_conflict` without mutation;
   preview verbs do not change revision.
9. Delete/corrupt Drawing and geometry caches, reopen, and reproduce identical
   semantic IDs plus exact primitive hashes after rebuild.
10. Export PDF, DXF, and SVG fixtures; parse each output, verify sheet size,
    layer/style mapping, visible/hidden/section geometry, text, and stable BOM
    content. No exporter reads the display mesh.
11. HTTP `/rpc` subprocess coverage exercises the same envelopes, background
    rebuild state, cancellation, diagnostics, and export results as direct
    bridge tests.
12. The frontend can render empty, loading, populated, filtered-empty,
    read-only, stale, partially failed, dangling-annotation, missing-source,
    background-rebuild, and unavailable-capability states solely from the
    projection and diagnostics.

## Explicit deferrals

- Real-time collaborative Drawing operations are deferred; later operation
  logs mutate the same graph.
- Freehand raster markup is not technical Drawing geometry and, if added,
  remains a separate media/annotation type.
- DWG export is not promised without a licensed implementation.
- Print-driver integration is presentation/platform work after deterministic
  PDF output exists.
