import { describe, expect, it, vi } from "vitest";
import {
  DrawingBridgeClient,
  DrawingBridgeError,
  DrawingProjectionDecodeError,
  decodeDrawingMutationResult,
  decodeDrawingProjection,
} from "./cad-drawing-bridge";

const line = {
  primitive_id: "primitive-line-1",
  kind: "line",
  layer_id: "layer-visible",
  visibility_class: "visible",
  source_entity_ids: ["part-1"],
  source_topology_ids: ["edge-1"],
  start_sheet_mm: [20, 30],
  end_sheet_mm: [80, 30],
};

const drawing = {
  schema_version: 1,
  workspace_id: "workspace-1",
  revision: "revision-9",
  drawing_id: "drawing-1",
  name: "Drive Drawing",
  capabilities: {
    can_edit_sheets: true,
    supported_view_type_ids: ["base", "projected", "section"],
    supported_annotation_type_ids: ["linear_dimension", "note"],
    can_project_hidden_lines: true,
    can_project_sections: true,
    can_project_bom: true,
    can_rebuild: true,
    can_save_workspace: true,
    export_format_ids: ["pdf", "svg"],
    unavailable_reasons: [{ capability_id: "export_dxf", reason: "DXF export is not available." }],
  },
  active_sheet_id: "sheet-1",
  sheets: [{
    id: "sheet-1",
    name: "Sheet 1",
    index: 0,
    width_mm: 420,
    height_mm: 297,
    orientation: "landscape",
    projection_standard: "third_angle",
    default_scale_ratio: 1,
    border: { margin_left_mm: 20, margin_right_mm: 10, margin_top_mm: 10, margin_bottom_mm: 10, zone_rows: 4, zone_columns: 6 },
    title_block: {
      id: "title-1",
      template_id: "template-default",
      origin_sheet_mm: [300, 247],
      width_mm: 110,
      height_mm: 40,
      fields: [{ field_id: "field-drawn", label: "Drawn by", value: "", editable: true }],
    },
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
      state: "current",
      geometry: {
        geometry_version: 1,
        source_exact_geometry_hash: "geometry-hash-1",
        primitives: [line],
        hatch_regions: [{ region_id: "hatch-1", boundary_primitive_loops: [["primitive-line-1"]], style_id: "style-default", angle_rad: 0.785, spacing_mm: 2.5 }],
        snap_points: [{ snap_id: "snap-1", kind: "endpoint", point_sheet_mm: [20, 30], primitive_ids: ["primitive-line-1"], source_entity_ids: ["part-1"], source_topology_ids: ["edge-1"] }],
        bounds_sheet_mm: [20, 30, 80, 30],
      },
      diagnostic_ids: [],
    }],
    annotations: [{
      id: "note-1",
      type_id: "note",
      view_id: null,
      layer_id: "layer-visible",
      style_id: "style-default",
      text: "",
      text_origin_sheet_mm: [40, 240],
      leader_points_sheet_mm: [],
      references: [],
      measurement: null,
      state: "current",
      diagnostic_ids: [],
    }],
    bom_tables: [{
      id: "bom-table-1",
      assembly_id: "assembly-1",
      bom_revision: "revision-8",
      mode: "flattened",
      origin_sheet_mm: [240, 40],
      width_mm: 160,
      visible_column_ids: ["item", "part_number", "quantity"],
      rows: [{ row_key: "row-1", item_number: "1", part_definition_id: "part-1", quantity: 2, cells: [{ column_id: "description", display_text: "" }] }],
      diagnostic_ids: [],
    }],
    layers: [{ id: "layer-visible", name: "Visible", visible: true, printable: true, locked: false, style_id: "style-default" }],
    revision: "revision-9",
  }],
  styles: [{ id: "style-default", name: "Default", line_weight_mm: 0.25, line_pattern: "solid", dash_pattern_mm: [], color_rgba: [0, 0, 0, 1], text_height_mm: 3.5, font_family: "Inter", arrow_size_mm: 2.5, decimal_places: 2 }],
  issues: [],
};

const rebuild = {
  drawing_id: "drawing-1",
  revision: "revision-9",
  status: "current",
  completed_view_count: 1,
  total_view_count: 1,
  cancellable: false,
  diagnostic_ids: [],
};

describe("exact Drawing projection decoder", () => {
  it("accepts exact sheet-space vectors and empty editable text", () => {
    const decoded = decodeDrawingProjection(drawing);
    expect(decoded.sheets[0].views[0].geometry.primitives[0]).toMatchObject({
      kind: "line",
      start_sheet_mm: [20, 30],
      source_topology_ids: ["edge-1"],
    });
    expect(decoded.sheets[0].title_block.fields[0].value).toBe("");
    expect(decoded.sheets[0].annotations[0].text).toBe("");
  });

  it("rejects unknown required Drawing and geometry versions", () => {
    expect(() => decodeDrawingProjection({ ...drawing, schema_version: 2 })).toThrowError(
      new DrawingProjectionDecodeError("drawing.schema_version", "unsupported schema version"),
    );
    const malformed = structuredClone(drawing);
    malformed.sheets[0].views[0].geometry.geometry_version = 2;
    expect(() => decodeDrawingProjection(malformed)).toThrow(
      "drawing.sheets[0].views[0].geometry.geometry_version: unsupported geometry version",
    );
  });

  it("reports the exact path of a malformed sheet-space point", () => {
    const malformed = structuredClone(drawing);
    malformed.sheets[0].views[0].geometry.primitives[0].start_sheet_mm = [20, 30, 40];
    expect(() => decodeDrawingProjection(malformed)).toThrow(
      "drawing.sheets[0].views[0].geometry.primitives[0].start_sheet_mm: expected 2 numbers",
    );
  });

  it("rejects an incoherent mutation refresh revision", () => {
    expect(() => decodeDrawingMutationResult({
      handle: "workspace-1",
      revision: "revision-10",
      drawing,
      rebuild,
    })).toThrow("result.drawing.revision: must match result.revision");
  });
});

describe("DrawingBridgeClient", () => {
  it("uses the shared rpc envelope and forwards abort signals", async () => {
    const signal = new AbortController().signal;
    const fetch = vi.fn<typeof globalThis.fetch>(async () => new Response(JSON.stringify({ ok: true, result: drawing }), { status: 200 }));
    const client = new DrawingBridgeClient({ baseURL: "http://127.0.0.1:8787/", fetch, nextRequestID: () => "drawing-request-1" });
    const result = await client.describeDrawing("handle-1", "drawing-1", signal);
    expect(result.revision).toBe("revision-9");
    const [url, init] = fetch.mock.calls[0];
    expect(url).toBe("http://127.0.0.1:8787/rpc");
    expect(init?.signal).toBe(signal);
    expect(JSON.parse(String(init?.body))).toEqual({
      id: "drawing-request-1",
      method: "describe_drawing",
      params: { handle: "handle-1", drawing_id: "drawing-1" },
    });
  });

  it("preserves typed Core error codes and paths", async () => {
    const fetch = vi.fn<typeof globalThis.fetch>(async () => new Response(JSON.stringify({
      ok: false,
      error: { code: "revision_conflict", message: "Drawing changed", path: "expected_revision" },
    }), { status: 200 }));
    const client = new DrawingBridgeClient({ baseURL: "http://core", fetch });
    const error: unknown = await client.mutate("add_drawing_view", {
      handle: "handle-1",
      expected_revision: "revision-8",
      view: {},
    }).catch((reason: unknown) => reason);
    expect(error).toBeInstanceOf(DrawingBridgeError);
    expect(error).toMatchObject({ code: "revision_conflict", path: "expected_revision", message: "Drawing changed" });
  });
});
