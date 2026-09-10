import {
  ProjectionDecodeError,
  array,
  boolean,
  nullableNumber,
  nullableString,
  number,
  oneOf,
  record,
  string,
  stringArray,
  text,
  tuple,
} from "./cad-bridge-decode";

export type DrawingStableID = string;
export type SheetPoint = readonly [number, number];
export type SheetBounds = readonly [number, number, number, number];

export interface DrawingCapabilities {
  readonly can_edit_sheets: boolean;
  readonly supported_view_type_ids: readonly string[];
  readonly supported_annotation_type_ids: readonly string[];
  readonly can_project_hidden_lines: boolean;
  readonly can_project_sections: boolean;
  readonly can_project_bom: boolean;
  readonly can_rebuild: boolean;
  readonly can_save_workspace: boolean;
  readonly export_format_ids: readonly string[];
  readonly unavailable_reasons: readonly {
    readonly capability_id: string;
    readonly reason: string;
  }[];
}

export interface DrawingDiagnostic {
  readonly id: DrawingStableID;
  readonly severity: "info" | "warning" | "error";
  readonly code: string;
  readonly message: string;
  readonly entity_ids: readonly DrawingStableID[];
  readonly field_path: string | null;
  readonly recoverable: boolean;
}

export interface DrawingStyleProjection {
  readonly id: DrawingStableID;
  readonly name: string;
  readonly line_weight_mm: number;
  readonly line_pattern: "solid" | "dashed" | "dash_dot" | "center";
  readonly dash_pattern_mm: readonly number[];
  readonly color_rgba: readonly [number, number, number, number];
  readonly text_height_mm: number;
  readonly font_family: string;
  readonly arrow_size_mm: number;
  readonly decimal_places: number;
}

export interface DrawingLayerProjection {
  readonly id: DrawingStableID;
  readonly name: string;
  readonly visible: boolean;
  readonly printable: boolean;
  readonly locked: boolean;
  readonly style_id: DrawingStableID;
}

interface DrawingPrimitiveCommon {
  readonly primitive_id: string;
  readonly layer_id: DrawingStableID;
  readonly visibility_class: "visible" | "hidden" | "tangent" | "center" | "section";
  readonly source_entity_ids: readonly DrawingStableID[];
  readonly source_topology_ids: readonly DrawingStableID[];
}

export type DrawingPrimitive =
  | (DrawingPrimitiveCommon & {
      readonly kind: "line";
      readonly start_sheet_mm: SheetPoint;
      readonly end_sheet_mm: SheetPoint;
    })
  | (DrawingPrimitiveCommon & {
      readonly kind: "arc";
      readonly center_sheet_mm: SheetPoint;
      readonly radius_mm: number;
      readonly start_angle_rad: number;
      readonly end_angle_rad: number;
      readonly counterclockwise: boolean;
    })
  | (DrawingPrimitiveCommon & {
      readonly kind: "circle";
      readonly center_sheet_mm: SheetPoint;
      readonly radius_mm: number;
    })
  | (DrawingPrimitiveCommon & {
      readonly kind: "ellipse";
      readonly center_sheet_mm: SheetPoint;
      readonly major_axis_sheet_mm: SheetPoint;
      readonly minor_radius_mm: number;
      readonly start_parameter_rad: number;
      readonly end_parameter_rad: number;
    })
  | (DrawingPrimitiveCommon & {
      readonly kind: "nurbs";
      readonly degree: number;
      readonly control_points_sheet_mm: readonly SheetPoint[];
      readonly knots: readonly number[];
      readonly weights: readonly number[];
    });

export interface HatchRegionProjection {
  readonly region_id: string;
  readonly boundary_primitive_loops: readonly (readonly string[])[];
  readonly style_id: DrawingStableID;
  readonly angle_rad: number;
  readonly spacing_mm: number;
}

export interface DrawingSnapPoint {
  readonly snap_id: string;
  readonly kind: "endpoint" | "midpoint" | "center" | "quadrant" | "intersection";
  readonly point_sheet_mm: SheetPoint;
  readonly primitive_ids: readonly string[];
  readonly source_entity_ids: readonly DrawingStableID[];
  readonly source_topology_ids: readonly DrawingStableID[];
}

export interface DrawingGeometryProjection {
  readonly geometry_version: 1;
  readonly source_exact_geometry_hash: string;
  readonly primitives: readonly DrawingPrimitive[];
  readonly hatch_regions: readonly HatchRegionProjection[];
  readonly snap_points: readonly DrawingSnapPoint[];
  readonly bounds_sheet_mm: SheetBounds;
}

export interface DrawingViewProjection {
  readonly id: DrawingStableID;
  readonly name: string;
  readonly type_id: "base" | "projected" | "section" | "detail" | "auxiliary" | "broken";
  readonly source: {
    readonly kind: "part" | "assembly";
    readonly entity_id: DrawingStableID;
    readonly configuration_id: DrawingStableID | null;
    readonly exploded_state_id: DrawingStableID | null;
  };
  readonly parent_view_id: DrawingStableID | null;
  readonly origin_sheet_mm: SheetPoint;
  readonly boundary_sheet_mm: SheetBounds;
  readonly scale_ratio: number;
  readonly orientation_model_to_view_quaternion_xyzw: readonly [number, number, number, number];
  readonly label: string | null;
  readonly display: {
    readonly hidden_lines: "removed" | "visible";
    readonly tangent_edges: "removed" | "visible" | "font";
    readonly show_scale_label: boolean;
    readonly show_view_label: boolean;
  };
  readonly state: "current" | "stale" | "rebuilding" | "failed" | "suppressed";
  readonly geometry: DrawingGeometryProjection;
  readonly diagnostic_ids: readonly DrawingStableID[];
}

export interface DrawingMeasurement {
  readonly kind: "length" | "angle" | "radius" | "diameter";
  readonly value_mm: number | null;
  readonly value_rad: number | null;
  readonly tolerance_upper_mm: number | null;
  readonly tolerance_lower_mm: number | null;
  readonly tolerance_upper_rad: number | null;
  readonly tolerance_lower_rad: number | null;
  readonly display_text: string;
  readonly overridden_text: boolean;
}

export interface DrawingAnnotationProjection {
  readonly id: DrawingStableID;
  readonly type_id:
    | "linear_dimension"
    | "angular_dimension"
    | "radial_dimension"
    | "diameter_dimension"
    | "ordinate_dimension"
    | "center_mark"
    | "centerline"
    | "note"
    | "datum"
    | "feature_control_frame"
    | "surface_finish"
    | "weld_symbol"
    | "balloon";
  readonly view_id: DrawingStableID | null;
  readonly layer_id: DrawingStableID;
  readonly style_id: DrawingStableID;
  readonly text: string;
  readonly text_origin_sheet_mm: SheetPoint;
  readonly leader_points_sheet_mm: readonly SheetPoint[];
  readonly references: readonly {
    readonly source_entity_id: DrawingStableID;
    readonly source_topology_id: DrawingStableID | null;
    readonly view_id: DrawingStableID;
    readonly attachment: "point" | "edge" | "center" | "tangent" | "quadrant";
  }[];
  readonly measurement: DrawingMeasurement | null;
  readonly state: "current" | "dangling" | "overridden" | "suppressed";
  readonly diagnostic_ids: readonly DrawingStableID[];
}

export interface DrawingBOMTableProjection {
  readonly id: DrawingStableID;
  readonly assembly_id: DrawingStableID;
  readonly bom_revision: string;
  readonly mode: "hierarchical" | "flattened";
  readonly origin_sheet_mm: SheetPoint;
  readonly width_mm: number;
  readonly visible_column_ids: readonly string[];
  readonly rows: readonly {
    readonly row_key: string;
    readonly item_number: string;
    readonly part_definition_id: DrawingStableID;
    readonly quantity: number;
    readonly cells: readonly {
      readonly column_id: string;
      readonly display_text: string;
    }[];
  }[];
  readonly diagnostic_ids: readonly DrawingStableID[];
}

export interface DrawingSheetProjection {
  readonly id: DrawingStableID;
  readonly name: string;
  readonly index: number;
  readonly width_mm: number;
  readonly height_mm: number;
  readonly orientation: "landscape" | "portrait";
  readonly projection_standard: "first_angle" | "third_angle";
  readonly default_scale_ratio: number;
  readonly border: {
    readonly margin_left_mm: number;
    readonly margin_right_mm: number;
    readonly margin_top_mm: number;
    readonly margin_bottom_mm: number;
    readonly zone_rows: number;
    readonly zone_columns: number;
  };
  readonly title_block: {
    readonly id: DrawingStableID;
    readonly template_id: DrawingStableID;
    readonly origin_sheet_mm: SheetPoint;
    readonly width_mm: number;
    readonly height_mm: number;
    readonly fields: readonly {
      readonly field_id: DrawingStableID;
      readonly label: string;
      readonly value: string;
      readonly editable: boolean;
    }[];
  };
  readonly views: readonly DrawingViewProjection[];
  readonly annotations: readonly DrawingAnnotationProjection[];
  readonly bom_tables: readonly DrawingBOMTableProjection[];
  readonly layers: readonly DrawingLayerProjection[];
  readonly revision: string;
}

export interface DrawingProjectionV1 {
  readonly schema_version: 1;
  readonly workspace_id: DrawingStableID;
  readonly revision: string;
  readonly drawing_id: DrawingStableID;
  readonly name: string;
  readonly capabilities: DrawingCapabilities;
  readonly active_sheet_id: DrawingStableID | null;
  readonly sheets: readonly DrawingSheetProjection[];
  readonly styles: readonly DrawingStyleProjection[];
  readonly issues: readonly DrawingDiagnostic[];
}

export interface DrawingRebuildProjection {
  readonly drawing_id: DrawingStableID;
  readonly revision: string;
  readonly status: "current" | "stale" | "rebuilding" | "partially_failed" | "failed";
  readonly completed_view_count: number;
  readonly total_view_count: number;
  readonly cancellable: boolean;
  readonly diagnostic_ids: readonly DrawingStableID[];
}

export interface DrawingMutationResultV1 {
  readonly handle: string;
  readonly revision: string;
  readonly drawing: DrawingProjectionV1;
  readonly rebuild: DrawingRebuildProjection;
}

export class DrawingProjectionDecodeError extends ProjectionDecodeError {
  override name = "DrawingProjectionDecodeError";
}

function numericArray(value: unknown, path: string): void {
  array(value, path).forEach((item, index) => number(item, `${path}[${index}]`));
}

function pointArray(value: unknown, path: string): void {
  array(value, path).forEach((item, index) => tuple(item, 2, `${path}[${index}]`));
}

function validateCapabilities(value: unknown, path: string): void {
  const item = record(value, path);
  [
    "can_edit_sheets",
    "can_project_hidden_lines",
    "can_project_sections",
    "can_project_bom",
    "can_rebuild",
    "can_save_workspace",
  ].forEach((key) => boolean(item[key], `${path}.${key}`));
  stringArray(item.supported_view_type_ids, `${path}.supported_view_type_ids`);
  stringArray(item.supported_annotation_type_ids, `${path}.supported_annotation_type_ids`);
  stringArray(item.export_format_ids, `${path}.export_format_ids`);
  array(item.unavailable_reasons, `${path}.unavailable_reasons`).forEach((entry, index) => {
    const reasonPath = `${path}.unavailable_reasons[${index}]`;
    const reason = record(entry, reasonPath);
    string(reason.capability_id, `${reasonPath}.capability_id`);
    string(reason.reason, `${reasonPath}.reason`);
  });
}

function validateDiagnostic(value: unknown, path: string): void {
  const item = record(value, path);
  string(item.id, `${path}.id`);
  oneOf(item.severity, ["info", "warning", "error"], `${path}.severity`);
  string(item.code, `${path}.code`);
  string(item.message, `${path}.message`);
  stringArray(item.entity_ids, `${path}.entity_ids`);
  nullableString(item.field_path, `${path}.field_path`);
  boolean(item.recoverable, `${path}.recoverable`);
}

function validateStyle(value: unknown, path: string): void {
  const item = record(value, path);
  string(item.id, `${path}.id`);
  string(item.name, `${path}.name`);
  number(item.line_weight_mm, `${path}.line_weight_mm`);
  oneOf(item.line_pattern, ["solid", "dashed", "dash_dot", "center"], `${path}.line_pattern`);
  numericArray(item.dash_pattern_mm, `${path}.dash_pattern_mm`);
  tuple(item.color_rgba, 4, `${path}.color_rgba`);
  number(item.text_height_mm, `${path}.text_height_mm`);
  string(item.font_family, `${path}.font_family`);
  number(item.arrow_size_mm, `${path}.arrow_size_mm`);
  number(item.decimal_places, `${path}.decimal_places`);
}

function validateLayer(value: unknown, path: string): void {
  const item = record(value, path);
  string(item.id, `${path}.id`);
  string(item.name, `${path}.name`);
  boolean(item.visible, `${path}.visible`);
  boolean(item.printable, `${path}.printable`);
  boolean(item.locked, `${path}.locked`);
  string(item.style_id, `${path}.style_id`);
}

function validatePrimitive(value: unknown, path: string): void {
  const item = record(value, path);
  string(item.primitive_id, `${path}.primitive_id`);
  const kind = oneOf(item.kind, ["line", "arc", "circle", "ellipse", "nurbs"], `${path}.kind`);
  string(item.layer_id, `${path}.layer_id`);
  oneOf(item.visibility_class, ["visible", "hidden", "tangent", "center", "section"], `${path}.visibility_class`);
  stringArray(item.source_entity_ids, `${path}.source_entity_ids`);
  stringArray(item.source_topology_ids, `${path}.source_topology_ids`);
  switch (kind) {
    case "line":
      tuple(item.start_sheet_mm, 2, `${path}.start_sheet_mm`);
      tuple(item.end_sheet_mm, 2, `${path}.end_sheet_mm`);
      break;
    case "arc":
      tuple(item.center_sheet_mm, 2, `${path}.center_sheet_mm`);
      number(item.radius_mm, `${path}.radius_mm`);
      number(item.start_angle_rad, `${path}.start_angle_rad`);
      number(item.end_angle_rad, `${path}.end_angle_rad`);
      boolean(item.counterclockwise, `${path}.counterclockwise`);
      break;
    case "circle":
      tuple(item.center_sheet_mm, 2, `${path}.center_sheet_mm`);
      number(item.radius_mm, `${path}.radius_mm`);
      break;
    case "ellipse":
      tuple(item.center_sheet_mm, 2, `${path}.center_sheet_mm`);
      tuple(item.major_axis_sheet_mm, 2, `${path}.major_axis_sheet_mm`);
      number(item.minor_radius_mm, `${path}.minor_radius_mm`);
      number(item.start_parameter_rad, `${path}.start_parameter_rad`);
      number(item.end_parameter_rad, `${path}.end_parameter_rad`);
      break;
    case "nurbs":
      number(item.degree, `${path}.degree`);
      pointArray(item.control_points_sheet_mm, `${path}.control_points_sheet_mm`);
      numericArray(item.knots, `${path}.knots`);
      numericArray(item.weights, `${path}.weights`);
      break;
  }
}

function validateGeometry(value: unknown, path: string): void {
  const item = record(value, path);
  if (item.geometry_version !== 1) {
    throw new DrawingProjectionDecodeError(`${path}.geometry_version`, "unsupported geometry version");
  }
  string(item.source_exact_geometry_hash, `${path}.source_exact_geometry_hash`);
  array(item.primitives, `${path}.primitives`).forEach((entry, index) =>
    validatePrimitive(entry, `${path}.primitives[${index}]`),
  );
  array(item.hatch_regions, `${path}.hatch_regions`).forEach((entry, index) => {
    const regionPath = `${path}.hatch_regions[${index}]`;
    const region = record(entry, regionPath);
    string(region.region_id, `${regionPath}.region_id`);
    array(region.boundary_primitive_loops, `${regionPath}.boundary_primitive_loops`).forEach(
      (loop, loopIndex) => stringArray(loop, `${regionPath}.boundary_primitive_loops[${loopIndex}]`),
    );
    string(region.style_id, `${regionPath}.style_id`);
    number(region.angle_rad, `${regionPath}.angle_rad`);
    number(region.spacing_mm, `${regionPath}.spacing_mm`);
  });
  array(item.snap_points, `${path}.snap_points`).forEach((entry, index) => {
    const snapPath = `${path}.snap_points[${index}]`;
    const snap = record(entry, snapPath);
    string(snap.snap_id, `${snapPath}.snap_id`);
    oneOf(snap.kind, ["endpoint", "midpoint", "center", "quadrant", "intersection"], `${snapPath}.kind`);
    tuple(snap.point_sheet_mm, 2, `${snapPath}.point_sheet_mm`);
    stringArray(snap.primitive_ids, `${snapPath}.primitive_ids`);
    stringArray(snap.source_entity_ids, `${snapPath}.source_entity_ids`);
    stringArray(snap.source_topology_ids, `${snapPath}.source_topology_ids`);
  });
  tuple(item.bounds_sheet_mm, 4, `${path}.bounds_sheet_mm`);
}

function validateView(value: unknown, path: string): void {
  const item = record(value, path);
  string(item.id, `${path}.id`);
  string(item.name, `${path}.name`);
  oneOf(item.type_id, ["base", "projected", "section", "detail", "auxiliary", "broken"], `${path}.type_id`);
  const source = record(item.source, `${path}.source`);
  oneOf(source.kind, ["part", "assembly"], `${path}.source.kind`);
  string(source.entity_id, `${path}.source.entity_id`);
  nullableString(source.configuration_id, `${path}.source.configuration_id`);
  nullableString(source.exploded_state_id, `${path}.source.exploded_state_id`);
  nullableString(item.parent_view_id, `${path}.parent_view_id`);
  tuple(item.origin_sheet_mm, 2, `${path}.origin_sheet_mm`);
  tuple(item.boundary_sheet_mm, 4, `${path}.boundary_sheet_mm`);
  number(item.scale_ratio, `${path}.scale_ratio`);
  tuple(item.orientation_model_to_view_quaternion_xyzw, 4, `${path}.orientation_model_to_view_quaternion_xyzw`);
  nullableString(item.label, `${path}.label`);
  const display = record(item.display, `${path}.display`);
  oneOf(display.hidden_lines, ["removed", "visible"], `${path}.display.hidden_lines`);
  oneOf(display.tangent_edges, ["removed", "visible", "font"], `${path}.display.tangent_edges`);
  boolean(display.show_scale_label, `${path}.display.show_scale_label`);
  boolean(display.show_view_label, `${path}.display.show_view_label`);
  oneOf(item.state, ["current", "stale", "rebuilding", "failed", "suppressed"], `${path}.state`);
  validateGeometry(item.geometry, `${path}.geometry`);
  stringArray(item.diagnostic_ids, `${path}.diagnostic_ids`);
}

function validateMeasurement(value: unknown, path: string): void {
  const item = record(value, path);
  oneOf(item.kind, ["length", "angle", "radius", "diameter"], `${path}.kind`);
  [
    "value_mm",
    "value_rad",
    "tolerance_upper_mm",
    "tolerance_lower_mm",
    "tolerance_upper_rad",
    "tolerance_lower_rad",
  ].forEach((key) => nullableNumber(item[key], `${path}.${key}`));
  string(item.display_text, `${path}.display_text`);
  boolean(item.overridden_text, `${path}.overridden_text`);
}

function validateAnnotation(value: unknown, path: string): void {
  const item = record(value, path);
  string(item.id, `${path}.id`);
  oneOf(item.type_id, [
    "linear_dimension", "angular_dimension", "radial_dimension", "diameter_dimension",
    "ordinate_dimension", "center_mark", "centerline", "note", "datum",
    "feature_control_frame", "surface_finish", "weld_symbol", "balloon",
  ], `${path}.type_id`);
  nullableString(item.view_id, `${path}.view_id`);
  string(item.layer_id, `${path}.layer_id`);
  string(item.style_id, `${path}.style_id`);
  text(item.text, `${path}.text`);
  tuple(item.text_origin_sheet_mm, 2, `${path}.text_origin_sheet_mm`);
  pointArray(item.leader_points_sheet_mm, `${path}.leader_points_sheet_mm`);
  array(item.references, `${path}.references`).forEach((entry, index) => {
    const referencePath = `${path}.references[${index}]`;
    const reference = record(entry, referencePath);
    string(reference.source_entity_id, `${referencePath}.source_entity_id`);
    nullableString(reference.source_topology_id, `${referencePath}.source_topology_id`);
    string(reference.view_id, `${referencePath}.view_id`);
    oneOf(reference.attachment, ["point", "edge", "center", "tangent", "quadrant"], `${referencePath}.attachment`);
  });
  if (item.measurement !== null) validateMeasurement(item.measurement, `${path}.measurement`);
  oneOf(item.state, ["current", "dangling", "overridden", "suppressed"], `${path}.state`);
  stringArray(item.diagnostic_ids, `${path}.diagnostic_ids`);
}

function validateBOM(value: unknown, path: string): void {
  const item = record(value, path);
  string(item.id, `${path}.id`);
  string(item.assembly_id, `${path}.assembly_id`);
  string(item.bom_revision, `${path}.bom_revision`);
  oneOf(item.mode, ["hierarchical", "flattened"], `${path}.mode`);
  tuple(item.origin_sheet_mm, 2, `${path}.origin_sheet_mm`);
  number(item.width_mm, `${path}.width_mm`);
  stringArray(item.visible_column_ids, `${path}.visible_column_ids`);
  array(item.rows, `${path}.rows`).forEach((entry, index) => {
    const rowPath = `${path}.rows[${index}]`;
    const row = record(entry, rowPath);
    string(row.row_key, `${rowPath}.row_key`);
    string(row.item_number, `${rowPath}.item_number`);
    string(row.part_definition_id, `${rowPath}.part_definition_id`);
    number(row.quantity, `${rowPath}.quantity`);
    array(row.cells, `${rowPath}.cells`).forEach((cellEntry, cellIndex) => {
      const cellPath = `${rowPath}.cells[${cellIndex}]`;
      const cell = record(cellEntry, cellPath);
      string(cell.column_id, `${cellPath}.column_id`);
      text(cell.display_text, `${cellPath}.display_text`);
    });
  });
  stringArray(item.diagnostic_ids, `${path}.diagnostic_ids`);
}

function validateSheet(value: unknown, path: string): void {
  const item = record(value, path);
  string(item.id, `${path}.id`);
  string(item.name, `${path}.name`);
  number(item.index, `${path}.index`);
  number(item.width_mm, `${path}.width_mm`);
  number(item.height_mm, `${path}.height_mm`);
  oneOf(item.orientation, ["landscape", "portrait"], `${path}.orientation`);
  oneOf(item.projection_standard, ["first_angle", "third_angle"], `${path}.projection_standard`);
  number(item.default_scale_ratio, `${path}.default_scale_ratio`);
  const border = record(item.border, `${path}.border`);
  ["margin_left_mm", "margin_right_mm", "margin_top_mm", "margin_bottom_mm", "zone_rows", "zone_columns"].forEach(
    (key) => number(border[key], `${path}.border.${key}`),
  );
  const title = record(item.title_block, `${path}.title_block`);
  string(title.id, `${path}.title_block.id`);
  string(title.template_id, `${path}.title_block.template_id`);
  tuple(title.origin_sheet_mm, 2, `${path}.title_block.origin_sheet_mm`);
  number(title.width_mm, `${path}.title_block.width_mm`);
  number(title.height_mm, `${path}.title_block.height_mm`);
  array(title.fields, `${path}.title_block.fields`).forEach((entry, index) => {
    const fieldPath = `${path}.title_block.fields[${index}]`;
    const field = record(entry, fieldPath);
    string(field.field_id, `${fieldPath}.field_id`);
    string(field.label, `${fieldPath}.label`);
    text(field.value, `${fieldPath}.value`);
    boolean(field.editable, `${fieldPath}.editable`);
  });
  array(item.views, `${path}.views`).forEach((entry, index) => validateView(entry, `${path}.views[${index}]`));
  array(item.annotations, `${path}.annotations`).forEach((entry, index) => validateAnnotation(entry, `${path}.annotations[${index}]`));
  array(item.bom_tables, `${path}.bom_tables`).forEach((entry, index) => validateBOM(entry, `${path}.bom_tables[${index}]`));
  array(item.layers, `${path}.layers`).forEach((entry, index) => validateLayer(entry, `${path}.layers[${index}]`));
  string(item.revision, `${path}.revision`);
}

export function decodeDrawingProjection(value: unknown): DrawingProjectionV1 {
  const path = "drawing";
  const root = record(value, path);
  if (root.schema_version !== 1) {
    throw new DrawingProjectionDecodeError(`${path}.schema_version`, "unsupported schema version");
  }
  string(root.workspace_id, `${path}.workspace_id`);
  string(root.revision, `${path}.revision`);
  string(root.drawing_id, `${path}.drawing_id`);
  string(root.name, `${path}.name`);
  validateCapabilities(root.capabilities, `${path}.capabilities`);
  nullableString(root.active_sheet_id, `${path}.active_sheet_id`);
  array(root.sheets, `${path}.sheets`).forEach((entry, index) => validateSheet(entry, `${path}.sheets[${index}]`));
  array(root.styles, `${path}.styles`).forEach((entry, index) => validateStyle(entry, `${path}.styles[${index}]`));
  array(root.issues, `${path}.issues`).forEach((entry, index) => validateDiagnostic(entry, `${path}.issues[${index}]`));
  return root as unknown as DrawingProjectionV1;
}

export function decodeDrawingRebuild(value: unknown): DrawingRebuildProjection {
  const path = "rebuild";
  const root = record(value, path);
  string(root.drawing_id, `${path}.drawing_id`);
  string(root.revision, `${path}.revision`);
  oneOf(root.status, ["current", "stale", "rebuilding", "partially_failed", "failed"], `${path}.status`);
  number(root.completed_view_count, `${path}.completed_view_count`);
  number(root.total_view_count, `${path}.total_view_count`);
  boolean(root.cancellable, `${path}.cancellable`);
  stringArray(root.diagnostic_ids, `${path}.diagnostic_ids`);
  return root as unknown as DrawingRebuildProjection;
}

export function decodeDrawingMutationResult(value: unknown): DrawingMutationResultV1 {
  const root = record(value, "result");
  const handle = string(root.handle, "result.handle");
  const revision = string(root.revision, "result.revision");
  const drawing = decodeDrawingProjection(root.drawing);
  const rebuild = decodeDrawingRebuild(root.rebuild);
  if (drawing.revision !== revision) {
    throw new DrawingProjectionDecodeError("result.drawing.revision", "must match result.revision");
  }
  if (rebuild.revision !== revision) {
    throw new DrawingProjectionDecodeError("result.rebuild.revision", "must match result.revision");
  }
  return { handle, revision, drawing, rebuild };
}

interface BridgeEnvelope {
  readonly ok: boolean;
  readonly result?: unknown;
  readonly error?: unknown;
}

export class DrawingBridgeError extends Error {
  constructor(
    readonly code: string,
    message: string,
    readonly path: string | null,
  ) {
    super(message);
    this.name = "DrawingBridgeError";
  }
}

export type DrawingMutationMethod =
  | "add_sheet"
  | "update_sheet"
  | "remove_sheet"
  | "reorder_sheets"
  | "set_active_sheet"
  | "add_drawing_view"
  | "update_drawing_view"
  | "remove_drawing_view"
  | "rebuild_drawing"
  | "add_annotation"
  | "update_annotation"
  | "remove_annotation"
  | "add_drawing_bom"
  | "update_drawing_bom"
  | "remove_drawing_bom"
  | "refresh_drawing_bom"
  | "add_drawing_style"
  | "update_drawing_style"
  | "add_drawing_layer"
  | "update_drawing_layer";

export interface DrawingBridgeClientOptions {
  readonly baseURL: string;
  readonly fetch?: typeof globalThis.fetch;
  readonly nextRequestID?: () => string | number;
}

export class DrawingBridgeClient {
  private readonly baseURL: string;
  private readonly fetchImplementation: typeof globalThis.fetch;
  private readonly nextRequestID: () => string | number;

  constructor(options: DrawingBridgeClientOptions) {
    this.baseURL = (options.baseURL || (typeof window !== "undefined" && window.location.pathname.startsWith("/cad/") ? "/cad" : "")).replace(/\/$/, "");
    this.fetchImplementation = options.fetch ?? globalThis.fetch;
    let requestID = 0;
    this.nextRequestID = options.nextRequestID ?? (() => ++requestID);
  }

  async describeDrawing(
    handle: string,
    drawingID: DrawingStableID,
    signal?: AbortSignal,
  ): Promise<DrawingProjectionV1> {
    return decodeDrawingProjection(
      await this.rpc("describe_drawing", { handle, drawing_id: drawingID }, signal),
    );
  }

  async mutate(
    method: DrawingMutationMethod,
    params: Readonly<Record<string, unknown>> & {
      readonly handle: string;
      readonly expected_revision: string;
    },
    signal?: AbortSignal,
  ): Promise<DrawingMutationResultV1> {
    return decodeDrawingMutationResult(await this.rpc(method, params, signal));
  }

  private async rpc(
    method: string,
    params: Readonly<Record<string, unknown>>,
    signal?: AbortSignal,
  ): Promise<unknown> {
    const response = await this.fetchImplementation(`${this.baseURL}/rpc`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ id: this.nextRequestID(), method, params }),
      signal,
    });
    if (!response.ok) {
      throw new DrawingBridgeError("transport_error", `Core bridge returned HTTP ${response.status}`, null);
    }
    const envelope = record(await response.json(), "response") as unknown as BridgeEnvelope;
    if (typeof envelope.ok !== "boolean") {
      throw new DrawingProjectionDecodeError("response.ok", "expected boolean");
    }
    if (!envelope.ok) {
      const error = record(envelope.error, "response.error");
      throw new DrawingBridgeError(
        string(error.code, "response.error.code"),
        string(error.message, "response.error.message"),
        nullableString(error.path, "response.error.path"),
      );
    }
    if (envelope.result === undefined) {
      throw new DrawingProjectionDecodeError("response.result", "missing successful result");
    }
    return envelope.result;
  }
}
