import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import type { DrawingPrimitive, DrawingSheetProjection, DrawingStyleProjection } from "../cad-drawing-bridge";
import { DrawingSheetCanvas, drawingPrimitivePath, sampleDrawingNURBS } from "./DrawingSheetCanvas";

const common = {
  layer_id: "layer-visible",
  visibility_class: "visible" as const,
  source_entity_ids: ["part-1"],
  source_topology_ids: ["edge-1"],
};

const primitives: DrawingPrimitive[] = [
  { ...common, primitive_id: "line-1", kind: "line", start_sheet_mm: [20, 20], end_sheet_mm: [80, 20] },
  { ...common, primitive_id: "line-2", kind: "line", start_sheet_mm: [80, 20], end_sheet_mm: [80, 60] },
  { ...common, primitive_id: "line-3", kind: "line", start_sheet_mm: [80, 60], end_sheet_mm: [20, 60] },
  { ...common, primitive_id: "line-4", kind: "line", start_sheet_mm: [20, 60], end_sheet_mm: [20, 20] },
  { ...common, primitive_id: "arc-1", kind: "arc", center_sheet_mm: [50, 40], radius_mm: 12, start_angle_rad: 0, end_angle_rad: Math.PI, counterclockwise: false },
  { ...common, primitive_id: "circle-1", kind: "circle", center_sheet_mm: [50, 40], radius_mm: 8 },
  { ...common, primitive_id: "ellipse-1", kind: "ellipse", center_sheet_mm: [50, 40], major_axis_sheet_mm: [15, 4], minor_radius_mm: 6, start_parameter_rad: 0, end_parameter_rad: Math.PI * 1.5 },
  {
    ...common,
    primitive_id: "nurbs-1",
    kind: "nurbs",
    degree: 2,
    control_points_sheet_mm: [[20, 70], [40, 90], [60, 50], [80, 70]],
    knots: [0, 0, 0, 1, 2, 2, 2],
    weights: [1, 1, 1, 1],
  },
  { ...common, primitive_id: "hidden-1", kind: "line", visibility_class: "hidden", start_sheet_mm: [20, 45], end_sheet_mm: [80, 45] },
];

const sheet: DrawingSheetProjection = {
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
    fields: [{ field_id: "field-title", label: "Title", value: "Drive Bracket", editable: true }],
  },
  views: [{
    id: "view-front",
    name: "Front",
    type_id: "base",
    source: { kind: "part", entity_id: "part-1", configuration_id: null, exploded_state_id: null },
    parent_view_id: null,
    origin_sheet_mm: [50, 40],
    boundary_sheet_mm: [15, 15, 90, 100],
    scale_ratio: 1,
    orientation_model_to_view_quaternion_xyzw: [0, 0, 0, 1],
    label: "FRONT",
    display: { hidden_lines: "visible", tangent_edges: "font", show_scale_label: false, show_view_label: true },
    state: "current",
    geometry: {
      geometry_version: 1,
      source_exact_geometry_hash: "exact-hash-1",
      primitives,
      hatch_regions: [{ region_id: "hatch-1", boundary_primitive_loops: [["line-1", "line-2", "line-3", "line-4"]], style_id: "style-default", angle_rad: Math.PI / 4, spacing_mm: 3 }],
      snap_points: [{ snap_id: "snap-1", kind: "endpoint", point_sheet_mm: [20, 20], primitive_ids: ["line-1"], source_entity_ids: ["part-1"], source_topology_ids: ["edge-1"] }],
      bounds_sheet_mm: [15, 15, 90, 100],
    },
    diagnostic_ids: [],
  }],
  annotations: [{
    id: "dimension-1",
    type_id: "linear_dimension",
    view_id: "view-front",
    layer_id: "layer-visible",
    style_id: "style-default",
    text: "",
    text_origin_sheet_mm: [45, 12],
    leader_points_sheet_mm: [[20, 16], [80, 16]],
    references: [],
    measurement: { kind: "length", value_mm: 60, value_rad: null, tolerance_upper_mm: null, tolerance_lower_mm: null, tolerance_upper_rad: null, tolerance_lower_rad: null, display_text: "60.00", overridden_text: false },
    state: "current",
    diagnostic_ids: [],
  }],
  bom_tables: [{
    id: "bom-1",
    assembly_id: "assembly-1",
    bom_revision: "revision-1",
    mode: "flattened",
    origin_sheet_mm: [220, 30],
    width_mm: 160,
    visible_column_ids: ["item", "part_number", "quantity"],
    rows: [{ row_key: "row-1", item_number: "1", part_definition_id: "part-1", quantity: 2, cells: [{ column_id: "part_number", display_text: "BR-100" }] }],
    diagnostic_ids: [],
  }],
  layers: [{ id: "layer-visible", name: "Visible", visible: true, printable: true, locked: false, style_id: "style-default" }],
  revision: "revision-1",
};

const styles: DrawingStyleProjection[] = [{
  id: "style-default",
  name: "Default",
  line_weight_mm: 0.25,
  line_pattern: "solid",
  dash_pattern_mm: [3, 2],
  color_rgba: [0, 0, 0, 1],
  text_height_mm: 3.5,
  font_family: "Inter",
  arrow_size_mm: 2.5,
  decimal_places: 2,
}];

describe("DrawingSheetCanvas", () => {
  it("turns every exact primitive family into sheet-space SVG path data", () => {
    expect(drawingPrimitivePath(primitives[0])).toBe("M 20 20 L 80 20");
    expect(drawingPrimitivePath(primitives[4])).toContain("A 12 12");
    expect(drawingPrimitivePath(primitives[5]).match(/ A /g)).toHaveLength(2);
    expect(drawingPrimitivePath(primitives[6])).toContain("A 15.524174696260024 6");
    expect(drawingPrimitivePath(primitives[7])).toContain("L");
  });

  it("samples projected NURBS for display without mutating its Core control data", () => {
    const nurbs = primitives[7];
    if (nurbs.kind !== "nurbs") throw new Error("fixture must be a NURBS");
    const controlPoints = structuredClone(nurbs.control_points_sheet_mm);
    const sampled = sampleDrawingNURBS(nurbs, 16);
    expect(sampled.length).toBeGreaterThan(4);
    expect(sampled[0][0]).toBeCloseTo(20);
    expect(sampled.at(-1)?.[0]).toBeCloseTo(80);
    expect(nurbs.control_points_sheet_mm).toEqual(controlPoints);
  });

  it("renders accessible exact sheet vectors, hatch, snaps, annotations, BOM, and title block", () => {
    const html = renderToStaticMarkup(<DrawingSheetCanvas
      sheet={sheet}
      styles={styles}
      selectedIDs={new Set(["line-1", "dimension-1"])}
      showSnapPoints
      onSelect={() => {}}
    />);
    expect(html).toContain('role="img"');
    expect(html).toContain('aria-label="A3 Layout technical drawing sheet"');
    expect(html).toContain('data-sheet-id="sheet-1"');
    expect(html).toContain('data-projection-standard="third_angle"');
    expect(html).toContain('data-view-id="view-front"');
    expect(html).toContain('data-view-selector-id="view-front"');
    expect(html).toContain('aria-label="Front drawing view"');
    expect(html).toContain('data-primitive-id="line-1"');
    expect(html).toContain('data-source-topology-ids="edge-1"');
    expect(html).toContain('data-hatch-region-id="hatch-1"');
    expect(html).toContain('data-snap-id="snap-1"');
    expect(html).toContain('data-annotation-id="dimension-1"');
    expect(html).toContain('data-bom-table-id="bom-1"');
    expect(html).toContain('data-title-block-id="title-1"');
    expect(html).toContain("60.00");
    expect(html).toContain("BR-100");
    expect(html).toContain("Drive Bracket");
    expect(html).toContain('stroke-dasharray="3 2"');
    expect(html).toContain("A3 Layout · 420 × 297 mm · third angle");
  });
});
