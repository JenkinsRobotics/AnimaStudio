import { renderGeometryConstraintColors } from "./geometry-constraint-colors";
import {
  contourClosed,
  sketchRegionOrder,
  type SketchDrawing,
  type SketchPoint,
} from "@aether/core/sketch";
import { contourPath } from "./svg-geometry";
import { renderDimensionAnnotations } from "./dimension-annotations";
/** The sketch plane square: half-width in millimetres, centred on the frame
 * origin. Larger than the 110 mm datum planes so it frames them. */
export const SKETCH_PLANE_HALF_MILLIMETRES = 80;
export const SKETCH_GRID_MILLIMETRES = 10;
export function renderSketchCanvas(
  svg: SVGSVGElement,
  drawing: SketchDrawing,
  bounds: { x: number; y: number; width: number; height: number },
  pending: SketchPoint[],
  dimensionPositions: Record<string,SketchPoint> = {},
) {
  const el = (tag: string, attrs: Record<string, string | number>) => {
    const node = document.createElementNS("http://www.w3.org/2000/svg", tag);
    for (const [key, value] of Object.entries(attrs))
      node.setAttribute(key, String(value));
    svg.append(node);
    return node;
  };
  svg.replaceChildren();
  svg.setAttribute(
    "viewBox",
    `${bounds.x} ${bounds.y} ${bounds.width} ${bounds.height}`,
  );
  // The sketch plane is one square: an origin, a size, an area. Everything that
  // describes the plane — face, grid, axes, origin — is drawn inside it, so it
  // reads as a drawn object, not as viewport decoration. It never moves or
  // resizes with pan/zoom; it is the selected plane (or planar face) frame.
  const half = SKETCH_PLANE_HALF_MILLIMETRES;
  el("rect", {
    x: -half,
    y: -half,
    width: half * 2,
    height: half * 2,
    class: "sketch-plane-face",
  });
  const name = svg.dataset.sketchName;
  if (name) {
    const label = el("text", {
      x: -half * 0.96,
      y: -half * 0.9,
      "font-size": half / 14,
      class: "sketch-plane-title",
    });
    label.textContent = name;
  }
  for (let v = -half + SKETCH_GRID_MILLIMETRES; v < half; v += SKETCH_GRID_MILLIMETRES) {
    el("line", { x1: v, y1: -half, x2: v, y2: half, class: "sketch-grid" });
    el("line", { x1: -half, y1: v, x2: half, y2: v, class: "sketch-grid" });
  }
  el("line", { x1: -half, y1: 0, x2: half, y2: 0, class: "sketch-axis" });
  el("line", { x1: 0, y1: -half, x2: 0, y2: half, class: "sketch-axis" });
  // The sketch origin IS the plane frame origin — mark it so the alignment is
  // visible, as Onshape does.
  el("circle", {
    cx: 0,
    cy: 0,
    r: half / 100,
    class: "sketch-origin",
  });
  const regions = drawing.contours
    .map((c, index) => ({ c, index }))
    .filter(({ c }) => !c.construction && contourClosed(c));
  const order = drawing.contours.some((c) => c.hole)
    ? [
        ...sketchRegionOrder(regions.map(({ c }) => c)).map(
          (i) => regions[i].index,
        ),
        ...drawing.contours.flatMap((c, i) =>
          c.construction || !contourClosed(c) ? [i] : [],
        ),
      ]
    : drawing.contours.map((_, i) => i);
  order.forEach((index) => {
    const c = drawing.contours[index];
    const attrs = {
      "data-contour-index": index,
      class: `sketch-contour ${contourClosed(c) ? "closed" : "open"}${c.hole ? " hole" : ""}${c.construction ? " construction" : ""}`,
    };
    if (c.type === "circle")
      el("circle", {
        cx: c.center[0],
        cy: -c.center[1],
        r: c.radius,
        ...attrs,
      });
    else if (!c.segments.length)
      el("circle", {
        cx: c.start[0],
        cy: -c.start[1],
        r: bounds.width / 180,
        ...attrs,
      });
    else el("path", { d: contourPath(c), ...attrs });
  });
  for (const c of drawing.contours) {
    const points =
      c.type === "circle"
        ? [c.center]
        : [c.start, ...c.segments.map((s) => s.end)];
    for (const p of points)
      el("circle", {
        cx: p[0],
        cy: -p[1],
        r: bounds.width / 250,
        class: "sketch-vertex",
      });
  }
  for (const c of drawing.contours)
    if (c.type === "path") {
      let previous = c.start;
      for (const segment of c.segments) {
        if (segment.type === "bezier") {
          for (const [a, b] of [
            [previous, segment.controls[0]],
            [segment.end, segment.controls[1]],
          ])
            el("line", {
              x1: a[0],
              y1: -a[1],
              x2: b[0],
              y2: -b[1],
              class: "sketch-preview-guide",
            });
          for (const p of segment.controls)
            el("circle", {
              cx: p[0],
              cy: -p[1],
              r: bounds.width / 180,
              class: "sketch-point",
            });
        }
        previous = segment.end;
      }
    }
  renderGeometryConstraintColors(svg, drawing);
  renderDimensionAnnotations(svg, drawing, bounds.width, dimensionPositions);
  for (const p of pending)
    el("circle", {
      cx: p[0],
      cy: -p[1],
      r: bounds.width / 180,
      class: "sketch-point",
    });
}
