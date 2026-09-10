import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";
import type { DrawingProjectionV1 } from "../cad-drawing-bridge";
import { CADDrawingWorkspaceStore } from "../cad-drawing-workspace-store";
import { DrawingWorkspace } from "./DrawingWorkspace";

function fixture(rowCount = 1): DrawingProjectionV1 {
  return {
    schema_version: 1,
    workspace_id: "workspace-1",
    revision: "revision-1",
    drawing_id: "drawing-1",
    name: "Drive Bracket Drawing",
    capabilities: {
      can_edit_sheets: true,
      supported_view_type_ids: ["base", "section"],
      supported_annotation_type_ids: ["linear_dimension"],
      can_project_hidden_lines: true,
      can_project_sections: false,
      can_project_bom: true,
      can_rebuild: true,
      can_save_workspace: false,
      export_format_ids: ["pdf", "svg"],
      unavailable_reasons: [
        { capability_id: "can_project_sections", reason: "Exact section projection is unavailable." },
        { capability_id: "can_save_workspace", reason: "Workspace is linked read-only." },
        { capability_id: "export_dxf", reason: "DXF export is unavailable." },
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
      title_block: {
        id: "title-1",
        template_id: "template-1",
        origin_sheet_mm: [300, 247],
        width_mm: 110,
        height_mm: 40,
        fields: [{ field_id: "title-field", label: "Title", value: "Drive Bracket", editable: true }],
      },
      views: [{
        id: "view-front",
        name: "Front",
        type_id: "base",
        source: { kind: "part", entity_id: "part-1", configuration_id: null, exploded_state_id: null },
        parent_view_id: null,
        origin_sheet_mm: [100, 100],
        boundary_sheet_mm: [20, 20, 180, 180],
        scale_ratio: 1,
        orientation_model_to_view_quaternion_xyzw: [0, 0, 0, 1],
        label: "FRONT",
        display: { hidden_lines: "removed", tangent_edges: "font", show_scale_label: true, show_view_label: true },
        state: "stale",
        geometry: {
          geometry_version: 1,
          source_exact_geometry_hash: "exact-hash-1",
          primitives: [{ primitive_id: "line-1", kind: "line", layer_id: "layer-1", visibility_class: "visible", source_entity_ids: ["part-1"], source_topology_ids: ["edge-1"], start_sheet_mm: [20, 20], end_sheet_mm: [80, 20] }],
          hatch_regions: [],
          snap_points: [{ snap_id: "snap-1", kind: "endpoint", point_sheet_mm: [20, 20], primitive_ids: ["line-1"], source_entity_ids: ["part-1"], source_topology_ids: ["edge-1"] }],
          bounds_sheet_mm: [20, 20, 180, 180],
        },
        diagnostic_ids: ["issue-1"],
      }],
      annotations: [{
        id: "dimension-1",
        type_id: "linear_dimension",
        view_id: "view-front",
        layer_id: "layer-1",
        style_id: "style-1",
        text: "",
        text_origin_sheet_mm: [40, 15],
        leader_points_sheet_mm: [[20, 18], [80, 18]],
        references: [],
        measurement: { kind: "length", value_mm: 60, value_rad: null, tolerance_upper_mm: null, tolerance_lower_mm: null, tolerance_upper_rad: null, tolerance_lower_rad: null, display_text: "60.00", overridden_text: false },
        state: "current",
        diagnostic_ids: [],
      }],
      bom_tables: [{
        id: "bom-1",
        assembly_id: "assembly-1",
        bom_revision: "bom-revision-1",
        mode: "flattened",
        origin_sheet_mm: [220, 30],
        width_mm: 160,
        visible_column_ids: ["item", "part_number", "quantity"],
        rows: Array.from({ length: rowCount }, (_, index) => ({
          row_key: `row-${index}`,
          item_number: String(index + 1),
          part_definition_id: `part-${index}`,
          quantity: index + 1,
          cells: [{ column_id: "part_number", display_text: `BR-${String(index).padStart(4, "0")}` }],
        })),
        diagnostic_ids: [],
      }],
      layers: [{ id: "layer-1", name: "Visible", visible: true, printable: true, locked: false, style_id: "style-1" }],
      revision: "revision-1",
    }],
    styles: [{ id: "style-1", name: "Default", line_weight_mm: 0.25, line_pattern: "solid", dash_pattern_mm: [], color_rgba: [0, 0, 0, 1], text_height_mm: 3.5, font_family: "Inter", arrow_size_mm: 2.5, decimal_places: 2 }],
    issues: [{ id: "issue-1", severity: "warning", code: "view_stale", message: "Front view needs rebuild.", entity_ids: ["view-front"], field_path: null, recoverable: true }],
  };
}

function render(store: CADDrawingWorkspaceStore, onCommand = vi.fn()): string {
  return renderToStaticMarkup(<DrawingWorkspace
    snapshot={store.snapshot()}
    onAction={(action) => store.dispatch(action)}
    onCommand={onCommand}
  />);
}

describe("DrawingWorkspace", () => {
  it("renders explicit unavailable, loading, and error dependency states", () => {
    const store = new CADDrawingWorkspaceStore();
    expect(render(store)).toContain("Exact Drawing engine unavailable");
    store.setLoading("Reading exact sheets…");
    expect(render(store)).toContain("Loading exact Drawing");
    expect(render(store)).toContain("Reading exact sheets…");
    store.setError("Core rejected the Drawing projection.");
    const errorHTML = render(store);
    expect(errorHTML).toContain('role="alert"');
    expect(errorHTML).toContain("Core rejected the Drawing projection.");
  });

  it("composes the ready workbench from shared widgets and the exact sheet canvas", () => {
    const store = new CADDrawingWorkspaceStore();
    store.setReady(fixture(), null);
    store.dispatch({ type: "set-show-snap-points", visible: true });
    store.dispatch({ type: "select-entities", ids: ["view-front"], mode: "single" });
    const html = render(store);
    expect(html).toContain('aria-label="Drawing workspace"');
    expect(html).toContain('aria-label="Drawing commands"');
    expect(html).toContain('aria-label="Drawing sheets and views"');
    expect(html).toContain('aria-label="Filter Drawing browser"');
    expect(html).toContain("9 results");
    expect(html).toContain('aria-label="Drawing properties"');
    expect(html).toContain('aria-label="Drawing diagnostics"');
    expect(html).toContain('data-sheet-id="sheet-1"');
    expect(html).toContain('data-primitive-id="line-1"');
    expect(html).toContain('data-snap-id="snap-1"');
    expect(html).toContain("60.00");
    expect(html).toContain("Drive Bracket");
    expect(html).toContain("1 sheets · 1 views · 1 exact primitives");
    expect(html).toContain("Exact section projection is unavailable.");
    expect(html).toContain("Workspace is linked read-only.");
    expect(store.snapshot().data?.commandAvailability.find((item) => item.id === "export-dxf")?.disabledReason).toBe("DXF export is unavailable.");
  });

  it("renders each shared browser collection and preserves scale metadata", () => {
    const store = new CADDrawingWorkspaceStore();
    store.setReady(fixture(1_200), null);
    store.dispatch({ type: "select-tab", tab: "annotations" });
    expect(render(store)).toContain('aria-label="Drawing annotations"');
    store.dispatch({ type: "select-tab", tab: "styles" });
    expect(render(store)).toContain('aria-label="Drawing styles"');
    store.dispatch({ type: "select-tab", tab: "bom" });
    const bomHTML = render(store);
    expect(bomHTML).toContain('aria-label="Drawing bill of materials"');
    expect(bomHTML).toContain('aria-rowcount="1201"');
  });

  it("fails closed when presentation and exact sheet revisions diverge", () => {
    const store = new CADDrawingWorkspaceStore();
    store.setReady(fixture(), null);
    const snapshot = store.snapshot();
    const mismatched = { ...snapshot, projection: { ...snapshot.projection!, revision: "revision-2" } };
    const html = renderToStaticMarkup(<DrawingWorkspace snapshot={mismatched} onAction={() => {}} onCommand={() => {}} />);
    expect(html).toContain("Drawing revision mismatch");
    expect(html).not.toContain('data-sheet-id="sheet-1"');
  });

  it("adds route recovery and transport-gates otherwise supported commands", () => {
    const store = new CADDrawingWorkspaceStore();
    store.setReady(fixture(), null);
    const html = renderToStaticMarkup(<DrawingWorkspace
      snapshot={store.snapshot()}
      onAction={() => {}}
      onCommand={() => {}}
      commandsConnected={false}
      onExit={() => {}}
    />);
    expect(html).toContain('aria-label="Drawing workspace navigation"');
    expect(html).toContain("← 3D model");
    expect(html).toContain('data-drawing-command="add-sheet" disabled="" title="Drawing command transport is not connected."');
  });
});
