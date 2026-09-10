import { describe, expect, it, vi } from "vitest";
import type { DrawingProjectionV1 } from "./cad-drawing-bridge";
import { CADDrawingWorkspaceStore } from "./cad-drawing-workspace-store";

const projection: DrawingProjectionV1 = {
  schema_version: 1,
  workspace_id: "workspace-1",
  revision: "revision-1",
  drawing_id: "drawing-1",
  name: "Drawing 1",
  capabilities: {
    can_edit_sheets: true,
    supported_view_type_ids: ["base"],
    supported_annotation_type_ids: [],
    can_project_hidden_lines: true,
    can_project_sections: false,
    can_project_bom: false,
    can_rebuild: true,
    can_save_workspace: true,
    export_format_ids: [],
    unavailable_reasons: [],
  },
  active_sheet_id: "sheet-1",
  sheets: [{
    id: "sheet-1",
    name: "Sheet 1",
    index: 0,
    width_mm: 297,
    height_mm: 210,
    orientation: "landscape",
    projection_standard: "third_angle",
    default_scale_ratio: 1,
    border: { margin_left_mm: 10, margin_right_mm: 10, margin_top_mm: 10, margin_bottom_mm: 10, zone_rows: 4, zone_columns: 6 },
    title_block: { id: "title-1", template_id: "template-1", origin_sheet_mm: [200, 170], width_mm: 87, height_mm: 30, fields: [] },
    views: [{
      id: "view-1",
      name: "Front",
      type_id: "base",
      source: { kind: "part", entity_id: "part-1", configuration_id: null, exploded_state_id: null },
      parent_view_id: null,
      origin_sheet_mm: [100, 90],
      boundary_sheet_mm: [20, 20, 180, 150],
      scale_ratio: 1,
      orientation_model_to_view_quaternion_xyzw: [0, 0, 0, 1],
      label: "FRONT",
      display: { hidden_lines: "removed", tangent_edges: "font", show_scale_label: true, show_view_label: true },
      state: "current",
      geometry: {
        geometry_version: 1,
        source_exact_geometry_hash: "hash-1",
        primitives: [{ primitive_id: "line-1", kind: "line", layer_id: "layer-1", visibility_class: "visible", source_entity_ids: ["part-1"], source_topology_ids: ["edge-1"], start_sheet_mm: [20, 20], end_sheet_mm: [80, 20] }],
        hatch_regions: [],
        snap_points: [],
        bounds_sheet_mm: [20, 20, 180, 150],
      },
      diagnostic_ids: [],
    }],
    annotations: [],
    bom_tables: [],
    layers: [{ id: "layer-1", name: "Visible", visible: true, printable: true, locked: false, style_id: "style-1" }],
    revision: "revision-1",
  }],
  styles: [{ id: "style-1", name: "Default", line_weight_mm: 0.25, line_pattern: "solid", dash_pattern_mm: [], color_rgba: [0, 0, 0, 1], text_height_mm: 3.5, font_family: "Inter", arrow_size_mm: 2.5, decimal_places: 2 }],
  issues: [],
};

describe("CADDrawingWorkspaceStore", () => {
  it("owns Drawing load, tab, filter, selection, and expansion presentation state", () => {
    const store = new CADDrawingWorkspaceStore();
    const listener = vi.fn();
    store.subscribe(listener);
    store.setLoading();
    store.setReady(projection, null);
    store.dispatch({ type: "select-tab", tab: "annotations" });
    store.dispatch({ type: "set-filter", filter: "front" });
    store.dispatch({ type: "set-show-snap-points", visible: true });
    store.dispatch({ type: "select-entities", ids: ["view-1"], mode: "single" });
    store.dispatch({ type: "toggle-entity", id: "sheet-1", expanded: false });
    expect(store.snapshot()).toMatchObject({ loadState: "ready", activeTab: "annotations", filter: "front", showSnapPoints: true, message: "Drawing revision revision-1", projection });
    expect(store.snapshot().selectedEntityIDs).toEqual(new Set(["view-1"]));
    expect(store.snapshot().data?.inspectorSections[0]).toMatchObject({ id: "view", badge: "current" });
    expect(store.snapshot().expandedEntityIDs.has("sheet-1")).toBe(false);
    expect(listener).toHaveBeenCalledTimes(7);
  });

  it("drops stale selection while preserving valid expansion across refreshed revisions", () => {
    const store = new CADDrawingWorkspaceStore();
    store.setReady(projection, null);
    store.dispatch({ type: "select-entities", ids: ["line-1"], mode: "single" });
    expect(store.snapshot().selectedEntityIDs).toEqual(new Set(["line-1"]));
    store.setReady({ ...projection, revision: "revision-2", sheets: [{ ...projection.sheets[0], revision: "revision-2", views: [] }] }, null);
    expect(store.snapshot().selectedEntityIDs).toEqual(new Set());
    expect(store.snapshot().expandedEntityIDs.has("sheet-1")).toBe(true);
  });

  it("exposes unavailable and error states without retaining canonical data", () => {
    const store = new CADDrawingWorkspaceStore();
    store.setReady(projection, null);
    store.setError("Exact projection failed.");
    expect(store.snapshot()).toMatchObject({ loadState: "error", message: "Exact projection failed.", projection: null, data: null });
    store.setUnavailable();
    expect(store.snapshot().loadState).toBe("unavailable");
    expect(store.snapshot().message).toContain("canonical Core projection engine");
  });
});
