export const instructions: Record<string, string> = {
  "fit-spline":
    "Click points along the curve. Press Enter or Finish spline for an open curve; click the first point or Close spline for a smooth closed loop. Escape cancels the unfinished curve.",
  "tangent-arc":
    "Click an existing curve endpoint, then the arc endpoint, or drag from the endpoint and release. Escape cancels.",
  "insert-spline-point":
    "Click inside a cubic spline span to insert a smooth editable point without changing its shape.",
  split: "Click inside a curve to split it; choose two positions for a circle.",
  trim: "Click a curve portion or drag across curves to trim between boundaries.",
  extend:
    "Click near a free line, arc, or ellipse end to extend to a boundary, or click a new endpoint when no boundary exists.",
  point: "Click to place a sketch point.",
  "elliptical-arc":
    "Click center, primary radius, then arc start to size the second radius; click the end direction. For an axis start, first move to size the ellipse or set Secondary radius. Choose clockwise or counterclockwise.",
  ellipse: "Click center, major axis endpoint, then minor axis width.",
  "cubic-bezier": "Click start, first control, second control, then end.",
  "midpoint-line": "Click the midpoint, then one endpoint.",
  "center-rectangle": "Click the center, then a corner.",
  "aligned-rectangle":
    "Click the first edge endpoints, then set the perpendicular width.",
  "three-point-circle": "Click three points on the circumference.",
  "center-arc":
    "Click the center, start, then end direction. Choose clockwise or counterclockwise.",
  "inscribed-polygon": "Set the side count; click the center, then a vertex.",
  "circumscribed-polygon":
    "Set the side count; click the center, then the midpoint of a side.",
  select:
    "Click a point, line or circle for Entity A, then another for Entity B. Choose a constraint to apply.",
  line: "Click connected endpoints; click the starting point to close. New contour starts another chain.",
  arc: "Click start and end, or drag to set both endpoints. Then move and click to set curvature. Switch to Line to continue.",
  circle: "Click center, then a point on the circumference.",
  rectangle: "Click opposite corners.",
};

export const modificationTools = [
  "offset",
  "slot",
  "chamfer",
  "fillet",
  "mirror",
  "linear-pattern",
  "circular-pattern",
  "transform",
] as const;
export type ModificationTool = (typeof modificationTools)[number];

export const directModificationTools = [
  "trim",
  "extend",
  "split",
  "insert-spline-point",
] as const;
export type DirectModificationTool = (typeof directModificationTools)[number];

export function isDirectModificationTool(
  tool: string,
): tool is DirectModificationTool {
  return (directModificationTools as readonly string[]).includes(tool);
}
