import type { SketchDrawing } from "@aether/core/sketch";
import { contourPath } from "./svg-geometry";
/** Overlay uses the same world-coordinate SVG paths as committed sketch geometry. */
export function renderPolygonPreview(
  svg: SVGSVGElement,
  drawing: SketchDrawing,
  indices: number[],
) {
  svg.querySelector(".sketch-polygon-preview")?.remove();
  const ns = "http://www.w3.org/2000/svg",
    group = document.createElementNS(ns, "g");
  group.setAttribute("class", "sketch-polygon-preview");
  group.setAttribute("pointer-events", "none");
  group.setAttribute("aria-label", "Polygon edit preview");
  for (const index of indices) {
    const c = drawing.contours[index],
      shape = document.createElementNS(
        ns,
        c.type === "circle" ? "circle" : "path",
      );
    shape.setAttribute("class", "sketch-preview");
    if (c.type === "circle") {
      shape.setAttribute("cx", String(c.center[0]));
      shape.setAttribute("cy", String(-c.center[1]));
      shape.setAttribute("r", String(c.radius));
      shape.style.fill = "none";
    } else shape.setAttribute("d", contourPath(c));
    group.append(shape);
  }
  svg.append(group);
}
