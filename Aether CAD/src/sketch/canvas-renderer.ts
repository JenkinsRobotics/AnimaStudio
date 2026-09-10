import { renderGeometryConstraintColors } from "./geometry-constraint-colors";
import {
  contourClosed,
  sketchRegionOrder,
  type SketchDrawing,
  type SketchPoint,
} from "@aether/core/sketch";
import { contourPath } from "./svg-geometry";
import { renderDimensionAnnotations } from "./dimension-annotations";
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
  const gridStep = Math.max(10,10 ** Math.ceil(Math.log10(Math.max(bounds.width,bounds.height)/100)));
  for (
    let v = Math.ceil(bounds.x / gridStep) * gridStep;
    v < bounds.x + bounds.width;
    v += gridStep
  )
    el("line", {
      x1: v,
      y1: bounds.y,
      x2: v,
      y2: bounds.y + bounds.height,
      class: "sketch-grid",
    });
  for (
    let v = Math.ceil(bounds.y / gridStep) * gridStep;
    v < bounds.y + bounds.height;
    v += gridStep
  )
    el("line", {
      x1: bounds.x,
      y1: v,
      x2: bounds.x + bounds.width,
      y2: v,
      class: "sketch-grid",
    });
  el("line", {
    x1: bounds.x,
    y1: 0,
    x2: bounds.x + bounds.width,
    y2: 0,
    class: "sketch-axis",
  });
  el("line", {
    x1: 0,
    y1: bounds.y,
    x2: 0,
    y2: bounds.y + bounds.height,
    class: "sketch-axis",
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
