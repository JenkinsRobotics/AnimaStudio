import { validateSketchDrawing, type SketchDrawing } from "../drawing";
import { sketchArcGeometry } from "../arc-geometry";
import {
  resolveSegmentReference,
  identifySegmentReference,
} from "../solver/segment-reference";
import type { SketchEntityRef } from "../solver/types";

/** Retain the center as a selectable construction point, linked to the arc's
 * analytic center by the existing concentric constraint. */
export function addSketchArcCenter(
  source: SketchDrawing,
  ref: SketchEntityRef,
): SketchDrawing {
  const next = structuredClone(source),
    path = next.contours[ref.contour];
  ref = resolveSegmentReference(path, ref);
  if (
    ref.kind !== "arc" ||
    !path ||
    path.type !== "path" ||
    !Number.isInteger(ref.index) ||
    ref.index! < 0
  )
    throw new Error("Select an existing circular sketch arc.");
  ref = identifySegmentReference(path, ref);
  const segment = path.segments[ref.index!];
  if (segment?.type !== "arc")
    throw new Error("Select an existing circular sketch arc.");
  const start =
    ref.index === 0 ? path.start : path.segments[ref.index! - 1].end;
  const arc = sketchArcGeometry(start, segment.middle, segment.end);
  const existing = next.constraints?.find(
    (c) =>
      c.kind === "concentric" &&
      c.a.kind === "arc" &&
      c.a.contour === ref.contour &&
      resolveSegmentReference(path, c.a).index === ref.index &&
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
    start: [...arc.center],
    segments: [],
  });
  const constraints = (next.constraints ??= []);
  const ids = new Set(constraints.map((c) => c.id));
  let sequence = 1;
  while (ids.has(`arc-center-${sequence}`)) sequence++;
  constraints.push({
    id: `arc-center-${sequence}`,
    kind: "concentric",
    a: { ...ref },
    b: { contour, kind: "point", index: 0 },
  });
  validateSketchDrawing(next);
  return next;
}
