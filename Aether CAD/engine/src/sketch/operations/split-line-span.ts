import { linkSplitSpanEndpoints } from "./split-span-links";
import type { SketchDrawing } from "../drawing";
import type { DrawingConstraint, SketchEntityRef } from "../solver/types";

export function needsSplitLineSpan(c: DrawingConstraint): boolean {
  return c.kind === "midpoint" || c.kind === "equal";
}

/** Finite-length relations retain the original span, not either shortened child.
 * Construction endpoints are linked to the split path's outer endpoints. */
export function retainSplitLineSpan(
  drawing: SketchDrawing,
  contour: number,
  segment: number,
): void {
  const constraints = drawing.constraints ?? [];
  const matches = (r: SketchEntityRef | undefined) =>
    r?.contour === contour && r.kind === "line" && r.index === segment;
  if (
    !constraints.some(
      (c) => needsSplitLineSpan(c) && (matches(c.a) || matches(c.b)),
    )
  )
    return;
  const path = drawing.contours[contour];
  if (path.type !== "path") throw Error("Expected split line path.");
  const helper = drawing.contours.length;
  drawing.contours.push({
    type: "path",
    construction: true,
    start: [...(segment === 0 ? path.start : path.segments[segment - 1].end)],
    segments: [{ type: "line", end: [...path.segments[segment + 1].end] }],
  });
  for (const c of constraints) {
    if (!needsSplitLineSpan(c)) continue;
    if (matches(c.a)) c.a = { contour: helper, kind: "line", index: 0 };
    if (matches(c.b)) c.b = { contour: helper, kind: "line", index: 0 };
  }
  linkSplitSpanEndpoints(constraints, helper, contour, segment);
}
