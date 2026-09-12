import { referencedContour } from "./projected-context";
import { resolveSegmentReference } from "./segment-reference";
import type { SketchDrawing } from "../drawing";
import type { SketchEntityRef } from "./types";
import { resolve } from "./entities";
import { diagnosticCoordinates } from "./diagnostic-coordinates";
/** Geometric quantities whose local mobility defines the selected entity's DOF. */
export function entityObservables(
  d: SketchDrawing,
  ref: SketchEntityRef,
): number[] {
  const contour = referencedContour(d, ref);
  ref = resolveSegmentReference(contour, ref);
  const e = resolve(d, ref);
  if (e.point) return [...e.point];
  if (e.line) return e.line.flat();
  if (e.arc) {
    const c = contour;
    if (c?.type !== "path") throw Error("Missing arc.");
    return [
      ...(ref.index === 0 ? c.start : c.segments[ref.index! - 1].end),
      ...c.segments[ref.index!].end,
      ...e.arc.center,
      e.arc.radius,
    ];
  }
  if (e.circle) return [...e.circle.center, e.circle.radius];
  if (e.ellipse) {
    const c = contour;
    if (c?.type !== "path") throw Error("Missing ellipse.");
    return [
      ...(ref.index === 0 ? c.start : c.segments[ref.index! - 1].end),
      ...c.segments[ref.index!].end,
      ...e.ellipse.center,
      e.ellipse.radiusX,
      e.ellipse.radiusY,
      e.ellipse.rotation,
    ];
  }
  if (e.curve) return [...e.curve.point, ...e.curve.first, ...e.curve.second];
  if (e.contour)
    return diagnosticCoordinates({
      type: "drawing",
      contours: [structuredClone(e.contour)],
    }).map((v) => v.get());
  throw Error("Unsupported entity for constraint analysis.");
}
