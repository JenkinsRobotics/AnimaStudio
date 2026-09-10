import type { ListBoxItem, TreeNode } from "@aether/ui";
import type { CADInspectorSection } from "./cad-workspace-store";
import type {
  DrawingAnnotationProjection,
  DrawingBOMTableProjection,
  DrawingDiagnostic,
  DrawingPrimitive,
  DrawingProjectionV1,
  DrawingRebuildProjection,
  DrawingSheetProjection,
  DrawingStableID,
  DrawingViewProjection,
} from "./cad-drawing-bridge";

export type DrawingPresentationTab = "sheets" | "annotations" | "bom" | "styles";

export type DrawingPresentationCommandID =
  | "add-sheet"
  | "add-view"
  | "add-section"
  | "add-annotation"
  | "add-bom"
  | "rebuild-drawing"
  | "save-workspace"
  | "export-pdf"
  | "export-dxf"
  | "export-svg";

export interface DrawingCommandAvailability {
  readonly id: DrawingPresentationCommandID;
  readonly enabled: boolean;
  readonly disabledReason?: string;
}

export interface DrawingPrimitiveRow {
  readonly primitive_id: string;
  readonly sheet_id: DrawingStableID;
  readonly view_id: DrawingStableID;
  readonly view_name: string;
  readonly kind: DrawingPrimitive["kind"];
  readonly visibility_class: DrawingPrimitive["visibility_class"];
  readonly layer_id: DrawingStableID;
  readonly source_entity_count: number;
  readonly source_topology_count: number;
  readonly primitive: DrawingPrimitive;
}

export interface DrawingBOMRow {
  readonly selection_id: string;
  readonly table_id: DrawingStableID;
  readonly row_key: string;
  readonly item_number: string;
  readonly part_definition_id: DrawingStableID;
  readonly quantity: number;
  readonly cells: DrawingBOMTableProjection["rows"][number]["cells"];
}

export interface CADDrawingPresentationProjection {
  readonly revision: string;
  readonly activeSheetID: DrawingStableID | null;
  readonly treeNodes: readonly TreeNode[];
  readonly sheetItems: readonly ListBoxItem[];
  readonly viewItems: readonly ListBoxItem[];
  readonly annotationItems: readonly ListBoxItem[];
  readonly styleItems: readonly ListBoxItem[];
  readonly problemItems: readonly ListBoxItem[];
  readonly inspectorSections: readonly CADInspectorSection[];
  readonly primitiveRows: readonly DrawingPrimitiveRow[];
  readonly bomRows: readonly DrawingBOMRow[];
  readonly commandAvailability: readonly DrawingCommandAvailability[];
  readonly summary: {
    readonly sheetCount: number;
    readonly viewCount: number;
    readonly annotationCount: number;
    readonly primitiveCount: number;
    readonly staleViewCount: number;
    readonly danglingAnnotationCount: number;
    readonly rebuildStatus: DrawingRebuildProjection["status"] | "not_rebuilt";
  };
}

function reasonFor(projection: DrawingProjectionV1, capabilityID: string, fallback: string): string {
  return projection.capabilities.unavailable_reasons.find(
    (item) => item.capability_id === capabilityID,
  )?.reason ?? fallback;
}

function availability(
  projection: DrawingProjectionV1,
  id: DrawingPresentationCommandID,
  enabled: boolean,
  capabilityID: string,
  fallback: string,
): DrawingCommandAvailability {
  return enabled
    ? { id, enabled: true }
    : { id, enabled: false, disabledReason: reasonFor(projection, capabilityID, fallback) };
}

function diagnosticItem(issue: DrawingDiagnostic): ListBoxItem {
  return {
    id: issue.id,
    label: issue.message,
    description: [issue.code, issue.field_path].filter(Boolean).join(" · "),
    icon: issue.severity === "error" ? "!" : issue.severity === "warning" ? "△" : "i",
    badge: issue.severity === "error" ? "Error" : issue.severity === "warning" ? "Warning" : "Info",
    group: issue.recoverable ? "Recoverable" : "Drawing",
  };
}

function viewBadge(view: DrawingViewProjection): string {
  return view.state === "current" ? view.type_id : `${view.type_id} · ${view.state}`;
}

function annotationBadge(annotation: DrawingAnnotationProjection): string {
  return annotation.state === "current" ? annotation.type_id : `${annotation.type_id} · ${annotation.state}`;
}

function sheetTree(sheet: DrawingSheetProjection): TreeNode {
  const viewNodes: TreeNode[] = sheet.views.map((view) => ({
    id: view.id,
    label: view.name,
    icon: "▱",
    badge: viewBadge(view),
    dimmed: view.state === "suppressed" || view.state === "failed",
  }));
  const annotationNodes: TreeNode[] = sheet.annotations.map((annotation) => ({
    id: annotation.id,
    label: annotation.text || annotation.type_id.replaceAll("_", " "),
    icon: "T",
    badge: annotationBadge(annotation),
    dimmed: annotation.state === "suppressed" || annotation.state === "dangling",
  }));
  const bomNodes: TreeNode[] = sheet.bom_tables.map((table) => ({
    id: table.id,
    label: `BOM · ${table.mode}`,
    icon: "▦",
    badge: String(table.rows.length),
  }));
  const layerNodes: TreeNode[] = sheet.layers.map((layer) => ({
    id: layer.id,
    label: layer.name,
    icon: "≋",
    badge: layer.locked ? "Locked" : undefined,
    dimmed: !layer.visible,
  }));
  return {
    id: sheet.id,
    label: sheet.name,
    icon: "▤",
    badge: `${sheet.width_mm} × ${sheet.height_mm} mm`,
    children: [
      { id: `presentation/${sheet.id}/views`, label: "Views", icon: "▱", badge: String(viewNodes.length), children: viewNodes },
      { id: `presentation/${sheet.id}/annotations`, label: "Annotations", icon: "T", badge: String(annotationNodes.length), children: annotationNodes },
      { id: `presentation/${sheet.id}/bom`, label: "BOM tables", icon: "▦", badge: String(bomNodes.length), children: bomNodes },
      { id: `presentation/${sheet.id}/layers`, label: "Layers", icon: "≋", badge: String(layerNodes.length), children: layerNodes },
    ],
  };
}

function sheetItems(projection: DrawingProjectionV1): readonly ListBoxItem[] {
  return projection.sheets.map((sheet) => ({
    id: sheet.id,
    label: sheet.name,
    description: `${sheet.width_mm} × ${sheet.height_mm} mm · ${sheet.projection_standard.replace("_", " ")}`,
    icon: "▤",
    badge: sheet.id === projection.active_sheet_id ? "Active" : `#${sheet.index + 1}`,
  }));
}

function viewItems(projection: DrawingProjectionV1): readonly ListBoxItem[] {
  return projection.sheets.flatMap((sheet) => sheet.views.map((view) => ({
    id: view.id,
    label: view.name,
    description: `${sheet.name} · ${view.type_id} · scale ${view.scale_ratio}`,
    icon: "▱",
    badge: view.state,
    dimmed: view.state === "suppressed" || view.state === "failed",
    group: sheet.name,
  })));
}

function annotationItems(projection: DrawingProjectionV1): readonly ListBoxItem[] {
  return projection.sheets.flatMap((sheet) => sheet.annotations.map((annotation) => ({
    id: annotation.id,
    label: annotation.text || annotation.type_id.replaceAll("_", " "),
    description: `${sheet.name} · ${annotation.type_id.replaceAll("_", " ")}`,
    icon: "T",
    badge: annotation.state,
    dimmed: annotation.state === "suppressed" || annotation.state === "dangling",
    group: sheet.name,
  })));
}

function styleItems(projection: DrawingProjectionV1): readonly ListBoxItem[] {
  return projection.styles.map((style) => ({
    id: style.id,
    label: style.name,
    description: `${style.line_weight_mm} mm · ${style.line_pattern} · ${style.text_height_mm} mm text`,
    icon: "≋",
  }));
}

function primitiveRows(projection: DrawingProjectionV1): readonly DrawingPrimitiveRow[] {
  return projection.sheets.flatMap((sheet) => sheet.views.flatMap((view) =>
    view.geometry.primitives.map((primitive) => ({
      primitive_id: primitive.primitive_id,
      sheet_id: sheet.id,
      view_id: view.id,
      view_name: view.name,
      kind: primitive.kind,
      visibility_class: primitive.visibility_class,
      layer_id: primitive.layer_id,
      source_entity_count: primitive.source_entity_ids.length,
      source_topology_count: primitive.source_topology_ids.length,
      primitive,
    })),
  ));
}

function bomRows(projection: DrawingProjectionV1): readonly DrawingBOMRow[] {
  return projection.sheets.flatMap((sheet) => sheet.bom_tables.flatMap((table) =>
    table.rows.map((row) => ({
      selection_id: `presentation/${table.id}/row/${row.row_key}`,
      table_id: table.id,
      row_key: row.row_key,
      item_number: row.item_number,
      part_definition_id: row.part_definition_id,
      quantity: row.quantity,
      cells: row.cells,
    })),
  ));
}

function point(values: readonly number[]): string {
  return values.map((value) => value.toLocaleString(undefined, { maximumFractionDigits: 4 })).join(", ");
}

function sheetInspector(sheet: DrawingSheetProjection): readonly CADInspectorSection[] {
  return [{
    id: "sheet",
    label: "Drawing sheet",
    badge: sheet.projection_standard.replace("_", " "),
    properties: [
      { id: "name", label: "Name", value: sheet.name },
      { id: "size", label: "Sheet size", value: `${sheet.width_mm} × ${sheet.height_mm} mm` },
      { id: "orientation", label: "Orientation", value: sheet.orientation },
      { id: "scale", label: "Default scale", value: String(sheet.default_scale_ratio) },
      { id: "views", label: "Views", value: String(sheet.views.length) },
      { id: "annotations", label: "Annotations", value: String(sheet.annotations.length) },
    ],
  }];
}

function inspector(
  projection: DrawingProjectionV1,
  rebuild: DrawingRebuildProjection | null,
  selectedID: DrawingStableID | null,
): readonly CADInspectorSection[] {
  for (const sheet of projection.sheets) {
    if (sheet.id === selectedID) return sheetInspector(sheet);
    const view = sheet.views.find((item) => item.id === selectedID);
    if (view) return [{
      id: "view",
      label: "Drawing view",
      badge: view.state,
      properties: [
        { id: "name", label: "Name", value: view.name },
        { id: "type", label: "Type", value: view.type_id },
        { id: "source", label: "Source", value: view.source.entity_id },
        { id: "origin", label: "Sheet origin", value: `${point(view.origin_sheet_mm)} mm` },
        { id: "scale", label: "Scale ratio", value: String(view.scale_ratio) },
        { id: "hidden", label: "Hidden lines", value: view.display.hidden_lines },
        { id: "primitives", label: "Exact primitives", value: String(view.geometry.primitives.length) },
        { id: "geometry-hash", label: "Exact geometry hash", value: view.geometry.source_exact_geometry_hash },
      ],
    }];
    const annotation = sheet.annotations.find((item) => item.id === selectedID);
    if (annotation) return [{
      id: "annotation",
      label: "Drawing annotation",
      badge: annotation.state,
      properties: [
        { id: "type", label: "Type", value: annotation.type_id },
        { id: "text", label: "Text", value: annotation.text || annotation.measurement?.display_text || "—" },
        { id: "origin", label: "Text origin", value: `${point(annotation.text_origin_sheet_mm)} mm` },
        { id: "references", label: "References", value: String(annotation.references.length) },
        { id: "measurement", label: "Measurement", value: annotation.measurement?.display_text ?? "Not measured" },
      ],
    }];
    const table = sheet.bom_tables.find((item) => item.id === selectedID);
    if (table) return [{
      id: "bom",
      label: "Drawing BOM table",
      badge: table.mode,
      properties: [
        { id: "assembly", label: "Assembly ID", value: table.assembly_id },
        { id: "revision", label: "BOM revision", value: table.bom_revision },
        { id: "origin", label: "Sheet origin", value: `${point(table.origin_sheet_mm)} mm` },
        { id: "width", label: "Width", value: `${table.width_mm} mm` },
        { id: "rows", label: "Rows", value: String(table.rows.length) },
      ],
    }];
  }
  const active = projection.sheets.find((sheet) => sheet.id === projection.active_sheet_id);
  return [{
    id: "drawing",
    label: "Drawing",
    badge: rebuild?.status ?? "not rebuilt",
    properties: [
      { id: "name", label: "Name", value: projection.name },
      { id: "revision", label: "Revision", value: projection.revision },
      { id: "sheets", label: "Sheets", value: String(projection.sheets.length) },
      { id: "active-sheet", label: "Active sheet", value: active?.name ?? "None" },
      { id: "views", label: "Views", value: String(projection.sheets.reduce((sum, sheet) => sum + sheet.views.length, 0)) },
    ],
  }];
}

export function buildCADDrawingPresentation(
  projection: DrawingProjectionV1,
  rebuild: DrawingRebuildProjection | null,
  selectedID: DrawingStableID | null = null,
): CADDrawingPresentationProjection {
  const views = projection.sheets.flatMap((sheet) => sheet.views);
  const annotations = projection.sheets.flatMap((sheet) => sheet.annotations);
  const primitiveData = primitiveRows(projection);
  const supportsView = projection.capabilities.supported_view_type_ids.length > 0;
  const supportsSection = projection.capabilities.supported_view_type_ids.includes("section") && projection.capabilities.can_project_sections;
  const supportsAnnotation = projection.capabilities.supported_annotation_type_ids.length > 0;
  const exports = new Set(projection.capabilities.export_format_ids);
  return {
    revision: projection.revision,
    activeSheetID: projection.active_sheet_id,
    treeNodes: projection.sheets.map(sheetTree),
    sheetItems: sheetItems(projection),
    viewItems: viewItems(projection),
    annotationItems: annotationItems(projection),
    styleItems: styleItems(projection),
    problemItems: projection.issues.map(diagnosticItem),
    inspectorSections: inspector(projection, rebuild, selectedID),
    primitiveRows: primitiveData,
    bomRows: bomRows(projection),
    commandAvailability: [
      availability(projection, "add-sheet", projection.capabilities.can_edit_sheets, "can_edit_sheets", "Core does not expose sheet editing."),
      availability(projection, "add-view", supportsView, "supported_view_type_ids", "Core does not expose Drawing view types."),
      availability(projection, "add-section", supportsSection, "can_project_sections", "Core does not expose exact section projection."),
      availability(projection, "add-annotation", supportsAnnotation, "supported_annotation_type_ids", "Core does not expose annotation types."),
      availability(projection, "add-bom", projection.capabilities.can_project_bom, "can_project_bom", "Core does not expose Drawing BOM projection."),
      availability(projection, "rebuild-drawing", projection.capabilities.can_rebuild, "can_rebuild", "Core does not expose exact Drawing rebuild."),
      availability(projection, "save-workspace", projection.capabilities.can_save_workspace, "can_save_workspace", "Core does not expose workspace persistence."),
      availability(projection, "export-pdf", exports.has("pdf"), "export_pdf", "Core does not expose PDF export."),
      availability(projection, "export-dxf", exports.has("dxf"), "export_dxf", "Core does not expose DXF export."),
      availability(projection, "export-svg", exports.has("svg"), "export_svg", "Core does not expose SVG export."),
    ],
    summary: {
      sheetCount: projection.sheets.length,
      viewCount: views.length,
      annotationCount: annotations.length,
      primitiveCount: primitiveData.length,
      staleViewCount: views.filter((view) => view.state === "stale" || view.state === "failed").length,
      danglingAnnotationCount: annotations.filter((annotation) => annotation.state === "dangling").length,
      rebuildStatus: rebuild?.status ?? "not_rebuilt",
    },
  };
}
