import {
  sketchEntityPoint,
  type SketchDrawing,
  type SketchEntityRef,
} from "@aether/core/sketch";
import { contourPath } from "./svg-geometry";
export function renderSketchSelection(
  svg: SVGSVGElement,
  drawing: SketchDrawing,
  ref: SketchEntityRef | null,
  size: number,
) {
  svg.querySelector(".sketch-selection")?.remove();
  if (!ref) return;
  const c = ref.projectedContourId === undefined ? drawing.contours[ref.contour] : drawing.projectionContext?.find(c=>c.id===ref.projectedContourId);
  if (!c) return;
  const group = document.createElementNS("http://www.w3.org/2000/svg", "g");
  group.setAttribute("class", "sketch-selection");
  group.setAttribute("aria-label", "Selected sketch entity");
  group.setAttribute("pointer-events", "none");
  const point =
    ref.kind === "point" ? sketchEntityPoint(drawing, ref) : undefined;
  const node = document.createElementNS(
    "http://www.w3.org/2000/svg",
    point || c.type === "circle" ? "circle" : "path",
  );
  if (point) {
    node.setAttribute("cx", String(point[0]));
    node.setAttribute("cy", String(-point[1]));
    node.setAttribute("r", String(size));
  } else if (c.type === "circle") {
    node.setAttribute("cx", String(c.center[0]));
    node.setAttribute("cy", String(-c.center[1]));
    node.setAttribute("r", String(c.radius));
  } else {
    const index = ref.index!,
      segment = c.segments[index];
    if (!segment) return;
    node.setAttribute(
      "d",
      contourPath({
        type: "path",
        start: index === 0 ? c.start : c.segments[index - 1].end,
        segments: [segment],
      }),
    );
  }
  group.append(node);
  svg.append(group);
}
