import { validateSketchDrawing, type SketchDrawing } from "../drawing";
import type { SketchEntityRef } from "../solver/types";

/** A selectable origin uses ordinary construction geometry and a fix relation.
 * No second origin representation is introduced into the saved format. */
export function addSketchOrigin(source: SketchDrawing): {
  drawing: SketchDrawing;
  origin: SketchEntityRef;
} {
  validateSketchDrawing(source);
  const drawing = structuredClone(source);
  for (const c of drawing.constraints ?? []) {
    const path = drawing.contours[c.a.contour];
    if (
      c.kind === "fix" &&
      c.a.kind === "point" &&
      c.a.index === 0 &&
      c.a.control === undefined &&
      c.point?.[0] === 0 &&
      c.point[1] === 0 &&
      path?.type === "path" &&
      path.construction &&
      !path.segments.length &&
      Math.hypot(...path.start) < 1e-7
    ) {
      return { drawing, origin: { ...c.a } };
    }
  }
  const origin: SketchEntityRef = {
    contour: drawing.contours.length,
    kind: "point",
    index: 0,
  };
  drawing.contours.push({
    type: "path",
    construction: true,
    start: [0, 0],
    segments: [],
  });
  const constraints = (drawing.constraints ??= []);
  const ids = new Set(constraints.map((c) => c.id));
  let n = 1;
  while (ids.has(`sketch-origin-${n}`)) n++;
  constraints.push({
    id: `sketch-origin-${n}`,
    kind: "fix",
    a: origin,
    point: [0, 0],
  });
  validateSketchDrawing(drawing);
  return { drawing, origin };
}
