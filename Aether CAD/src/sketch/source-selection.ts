import {
  patternSourceContour,
  type SketchDrawing,
  type SketchEntityRef,
} from "@aether/core/sketch";
import { contourPath } from "./svg-geometry";
/** Source highlights are separate from the generated mirror preview and saved drawing. */
export function renderModificationSourceSelection(
  svg: SVGSVGElement,
  drawing: SketchDrawing,
  refs: SketchEntityRef[],
) {
  svg.querySelector(".sketch-modification-source-selection")?.remove();
  if (!refs.length) return;
  const group = document.createElementNS("http://www.w3.org/2000/svg", "g");
  group.setAttribute("class", "sketch-modification-source-selection");
  group.setAttribute("aria-label", "Selected modification sources");
  group.setAttribute("pointer-events", "none");
  for (const ref of refs) {
    const c = patternSourceContour(drawing, ref),
      node = document.createElementNS(
        "http://www.w3.org/2000/svg",
        c.type === "circle" || !c.segments.length ? "circle" : "path",
      );
    if (c.type === "circle") {
      node.setAttribute("cx", String(c.center[0]));
      node.setAttribute("cy", String(-c.center[1]));
      node.setAttribute("r", String(c.radius));
    } else if (!c.segments.length) {
      node.setAttribute("cx", String(c.start[0]));
      node.setAttribute("cy", String(-c.start[1]));
      node.setAttribute(
        "r",
        String(
          (Number(svg.getAttribute("viewBox")?.split(/\s+/)[2]) || 120) / 150,
        ),
      );
    } else node.setAttribute("d", contourPath(c));
    group.append(node);
  }
  svg.append(group);
}
