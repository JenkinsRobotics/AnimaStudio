import { validateSketchDrawing, type SketchDrawing } from "../drawing";
import { resolve } from "../solver/entities";
import type { SketchEntityRef } from "../solver/types";
/** A selectable center stays linked to the analytic ellipse, not a cached coordinate. */
export function addSketchEllipseCenter(
  source: SketchDrawing,
  ref: SketchEntityRef,
): SketchDrawing {
  if (ref.kind !== "ellipse")
    throw Error("Select an elliptical sketch segment.");
  const next = structuredClone(source),
    ellipse = resolve(next, ref).ellipse;
  if (!ellipse) throw Error("Select an elliptical sketch segment.");
  const existing = next.constraints?.find(
    (c) =>
      c.kind === "concentric" &&
      c.a.kind === "ellipse" &&
      c.a.contour === ref.contour &&
      c.a.index === ref.index &&
      c.b?.kind === "point" &&
      next.contours[c.b.contour]?.construction,
  );
  if (existing) {
    validateSketchDrawing(next);
    return next;
  }
  const contour = next.contours.length;
  next.contours.push({
    type: "path",
    construction: true,
    start: [...ellipse.center],
    segments: [],
  });
  const constraints = (next.constraints ??= []),
    ids = new Set(constraints.map((c) => c.id));
  let n = 1;
  while (ids.has(`ellipse-center-${n}`)) n++;
  constraints.push({
    id: `ellipse-center-${n}`,
    kind: "concentric",
    a: { ...ref },
    b: { contour, kind: "point", index: 0 },
  });
  validateSketchDrawing(next);
  return next;
}
