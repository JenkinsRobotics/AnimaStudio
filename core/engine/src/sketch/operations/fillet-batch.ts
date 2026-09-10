import { filletConnectedCurves } from "./fillet-connected-curves";
import type { SketchDrawing } from "../drawing";
import { filletSketchCorner } from "./fillet";
import { assertConstraintsSatisfied } from "./preserve-constraints";
import { validateSketchDrawing } from "../drawing";
export interface FilletCorner {
  contour: number;
  vertex: number;
}
/** Descending original indices avoid selection drift as new arcs are inserted. */
export function filletSketchCorners(
  source: SketchDrawing,
  corners: FilletCorner[],
  radius: number,
): SketchDrawing {
  if (!corners.length) throw new Error("Select at least one corner.");
  const unique = [
    ...new Map(corners.map((c) => [`${c.contour}:${c.vertex}`, c])).values(),
  ].sort((a, b) => b.contour - a.contour || b.vertex - a.vertex);
  const originalIDs = new Set(source.constraints?.map((c) => c.id));
  let next = source;
  for (const corner of unique) {
    const path = next.contours[corner.contour];
    if (path?.type !== "path") throw new Error("Choose a path corner.");
    const incoming =
      corner.vertex === 0 ? path.segments.length - 1 : corner.vertex - 1;
    if (
      path.segments[incoming]?.type === "line" &&
      path.segments[corner.vertex]?.type === "line"
    )
      next = filletSketchCorner(next, corner.contour, corner.vertex, radius);
    else
      next = filletConnectedCurves(
        next,
        { contour: corner.contour, segment: incoming, parameter: 0 },
        { contour: corner.contour, segment: corner.vertex, parameter: 1 },
        radius,
      );
  }
  const radii = next.constraints!.filter(
    (c) => c.kind === "radius" && !originalIDs.has(c.id),
  );
  const master = radii[0];
  // Keep one driving dimension; other fillet arcs follow it via equal-radius relations.
  for (const dimension of radii.slice(1)) {
    dimension.kind = "equal";
    dimension.b = { ...master.a };
    delete dimension.value;
  }
  assertConstraintsSatisfied(next);
  validateSketchDrawing(next);
  return next;
}
