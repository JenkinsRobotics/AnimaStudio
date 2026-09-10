import { describe, expect, it } from "vitest";
import type { DrawingProjectionV1, DrawingRebuildProjection } from "./cad-drawing-bridge";
import { buildCADDrawingPresentation } from "./cad-drawing-presentation";

function fixture(): DrawingProjectionV1 {
  return {
    schema_version: 1,
    workspace_id: "workspace-1",
    revision: "revision-3",
    drawing_id: "drawing-1",
    name: "Drive Drawing",
    capabilities: {
      can_edit_sheets: true,
      supported_view_type_ids: ["base", "section"],
      supported_annotation_type_ids: ["linear_dimension", "note"],
      can_project_hidden_lines: true,
      can_project_sections: false,
      can_project_bom: true,
      can_rebuild: true,
      can_save_workspace: false,
      export_format_ids: ["pdf", "svg"],
      unavailable_reasons: [
        { capability_id: "can_project_sections", reason: "Exact section projection is not available." },
        { capability_id: "can_save_workspace", reason: "Workspace is linked read-only." },
        { capability_id: "export_dxf", reason: "DXF export is not available." },
      ],
    },
    active_sheet_id: "sheet-1",
    sheets: [{
      id: "sheet-1",
      name: "A3 Layout",
      index: 0,
      width_mm: 420,
      height_mm: 297,
      orientation: "landscape",
      projection_standard: "third_angle",
      default_scale_ratio: 1,
      border: { margin_left_mm: 20, margin_right_mm: 10, margin_top_mm: 10, margin_bottom_mm: 10, zone_rows: 4, zone_columns: 6 },
      title_block: { id: "title-1", template_id: "template-1", origin_sheet_mm: [300, 247], width_mm: 110, height_mm: 40, fields: [] },
      views: [{
        id: "view-front",
        name: "Front",
        type_id: "base",
        source: { kind: "part", entity_id: "part-1", configuration_id: null, exploded_state_id: null },
        parent_view_id: null,
        origin_sheet_mm: [100, 120],
        boundary_sheet_mm: [20, 40, 160, 180],
        scale_ratio: 1,
        orientation_model_to_view_quaternion_xyzw: [0, 0, 0, 1],
        label: "FRONT",
        display: { hidden_lines: "removed", tangent_edges: "font", show_scale_label: true, show_view_label: true },
        state: "stale",
        geometry: {
          geometry_version: 1,
          source_exact_geometry_hash: "exact-hash-1",
          primitives: [{ primitive_id: "line-1", kind: "line", layer_id: "layer-1", visibility_class: "visible", source_entity_ids: ["part-1"], source_topology_ids: ["edge-1"], start_sheet_mm: [0, 0], end_sheet_mm: [50, 0] }],
          hatch_regions: [],
          snap_points: [],
          bounds_sheet_mm: [0, 0, 50, 0],
        },
        diagnostic_ids: ["issue-stale"],
      }],
      annotations: [{
        id: "dimension-1",
        type_id: "linear_dimension",
        view_id: "view-front",
        layer_id: "layer-1",
        style_id: "style-1",
        text: "",
        text_origin_sheet_mm: [30, 20],
        leader_points_sheet_mm: [],
        references: [],
        measurement: { kind: "length", value_mm: 50, value_rad: null, tolerance_upper_mm: null, tolerance_lower_mm: null, tolerance_upper_rad: null, tolerance_lower_rad: null, display_text: "50.00", overridden_text: false },
        state: "dangling",
        diagnostic_ids: ["issue-dangling"],
      }],
      bom_tables: [{ id: "bom-1", assembly_id: "assembly-1", bom_revision: "revision-2", mode: "flattened", origin_sheet_mm: [240, 40], width_mm: 160, visible_column_ids: ["item", "quantity"], rows: [{ row_key: "row-1", item_number: "1", part_definition_id: "part-1", quantity: 2, cells: [{ column_id: "quantity", display_text: "2" }] }], diagnostic_ids: [] }],
      layers: [{ id: "layer-1", name: "Visible", visible: true, printable: true, locked: true, style_id: "style-1" }],
      revision: "revision-3",
    }],
    styles: [{ id: "style-1", name: "Default", line_weight_mm: 0.25, line_pattern: "solid", dash_pattern_mm: [], color_rgba: [0, 0, 0, 1], text_height_mm: 3.5, font_family: "Inter", arrow_size_mm: 2.5, decimal_places: 2 }],
    issues: [
      { id: "issue-stale", severity: "warning", code: "view_stale", message: "Front view needs rebuild.", entity_ids: ["view-front"], field_path: null, recoverable: true },
      { id: "issue-dangling", severity: "error", code: "dimension_dangling", message: "Dimension reference is missing.", entity_ids: ["dimension-1"], field_path: "annotations[0].references", recoverable: true },
    ],
  };
}

const rebuild: DrawingRebuildProjection = {
  drawing_id: "drawing-1",
  revision: "revision-3",
  status: "stale",
  completed_view_count: 0,
  total_view_count: 1,
  cancellable: false,
  diagnostic_ids: ["issue-stale"],
};

describe("buildCADDrawingPresentation", () => {
  it("maps stable exact Drawing IDs and raw primitives into shared-widget datasets", () => {
    const source = fixture();
    const presentation = buildCADDrawingPresentation(source, rebuild, "view-front");
    expect(presentation.treeNodes[0]).toMatchObject({ id: "sheet-1", label: "A3 Layout", badge: "420 × 297 mm" });
    expect(presentation.viewItems[0]).toMatchObject({ id: "view-front", badge: "stale" });
    expect(presentation.annotationItems[0]).toMatchObject({ id: "dimension-1", badge: "dangling", dimmed: true });
    expect(presentation.primitiveRows[0]).toMatchObject({ primitive_id: "line-1", view_id: "view-front", kind: "line", visibility_class: "visible" });
    expect(presentation.primitiveRows[0].primitive).toBe(source.sheets[0].views[0].geometry.primitives[0]);
    expect(presentation.bomRows[0]).toMatchObject({ selection_id: "presentation/bom-1/row/row-1", row_key: "row-1", item_number: "1", quantity: 2 });
    expect(presentation.problemItems.map((item) => item.badge)).toEqual(["Warning", "Error"]);
    expect(presentation.inspectorSections[0]).toMatchObject({ id: "view", badge: "stale" });
    expect(presentation.summary).toEqual({ sheetCount: 1, viewCount: 1, annotationCount: 1, primitiveCount: 1, staleViewCount: 1, danglingAnnotationCount: 1, rebuildStatus: "stale" });
  });

  it("uses Core capability and export reasons without inferring support", () => {
    const presentation = buildCADDrawingPresentation(fixture(), rebuild);
    expect(presentation.commandAvailability.find((item) => item.id === "add-section")).toEqual({ id: "add-section", enabled: false, disabledReason: "Exact section projection is not available." });
    expect(presentation.commandAvailability.find((item) => item.id === "save-workspace")?.disabledReason).toBe("Workspace is linked read-only.");
    expect(presentation.commandAvailability.find((item) => item.id === "export-dxf")?.disabledReason).toBe("DXF export is not available.");
    expect(presentation.commandAvailability.find((item) => item.id === "export-pdf")?.enabled).toBe(true);
  });

  it("projects an empty Drawing without inventing views, primitives, or annotations", () => {
    const source = fixture();
    const presentation = buildCADDrawingPresentation({ ...source, active_sheet_id: null, sheets: [], issues: [] }, null);
    expect(presentation.treeNodes).toEqual([]);
    expect(presentation.viewItems).toEqual([]);
    expect(presentation.annotationItems).toEqual([]);
    expect(presentation.primitiveRows).toEqual([]);
    expect(presentation.bomRows).toEqual([]);
    expect(presentation.summary).toMatchObject({ sheetCount: 0, viewCount: 0, primitiveCount: 0, rebuildStatus: "not_rebuilt" });
  });

  it("maps 1,200 view projections in deterministic order without changing IDs", () => {
    const source = fixture();
    const template = source.sheets[0].views[0];
    const views = Array.from({ length: 1_200 }, (_, index) => ({ ...template, id: `view-${index}`, name: `View ${index + 1}`, geometry: { ...template.geometry, primitives: [] } }));
    const presentation = buildCADDrawingPresentation({ ...source, sheets: [{ ...source.sheets[0], views }] }, null);
    expect(presentation.viewItems).toHaveLength(1_200);
    expect(presentation.viewItems[0].id).toBe("view-0");
    expect(presentation.viewItems[1_199].id).toBe("view-1199");
  });
});
