import type { SketchDrawing, SketchPoint } from "../drawing";
import type { CornerLine } from "./line-corner-selection";
import { assertConstraintsSatisfied } from "./preserve-constraints";
/** Extend/trim each selected line to a virtual intersection, retaining the picked side. */
export function prepareFilletIntersection(
  source: SketchDrawing,
  a: CornerLine,
  b: CornerLine,
): SketchDrawing {
  const first = source.contours[a.contour],
    second = source.contours[b.contour];
  if (first.type !== "path" || second.type !== "path")
    throw new Error("Select line contours.");
  const p = first.start,
    q = second.start,
    pe = first.segments[0].end,
    qe = second.segments[0].end;
  const d: SketchPoint = [pe[0] - p[0], pe[1] - p[1]],
    e: SketchPoint = [qe[0] - q[0], qe[1] - q[1]];
  const cross = (u: SketchPoint, v: SketchPoint) => u[0] * v[1] - u[1] * v[0],
    det = cross(d, e);
  if (Math.abs(det) < 1e-10 * Math.hypot(...d) * Math.hypot(...e))
    throw new Error("Parallel lines do not define a fillet corner.");
  const offset: SketchPoint = [q[0] - p[0], q[1] - p[1]],
    t = cross(offset, e) / det,
    u = cross(offset, d) / det;
  const intersection: SketchPoint = [p[0] + t * d[0], p[1] + t * d[1]];
  if (!intersection.every(Number.isFinite))
    throw new Error("The line intersection is not finite.");
  const movedEnd = (parameter: number, picked: number) =>
    parameter <= 0 ? 0 : parameter >= 1 ? 1 : picked < parameter ? 1 : 0;
  const next = structuredClone(source);
  for (const [selection, parameter] of [
    [a, t],
    [b, u],
  ] as const) {
    const c = next.contours[selection.contour];
    if (c.type !== "path") throw Error("path");
    if (movedEnd(parameter, selection.parameter ?? 0.5) === 0)
      c.start = [...intersection];
    else c.segments[0].end = [...intersection];
  }
  assertConstraintsSatisfied(next);
  return next;
}
