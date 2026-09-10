import { prepareFilletIntersection } from "./fillet-line-intersection";
import {
  contourClosed,
  type SketchDrawing,
  type SketchPoint,
} from "../drawing";
import type { SketchEntityRef } from "../drawing-constraints";
export interface CornerLine {
  contour: number;
  segment: number;
  parameter?: number;
}
/** Connect selected straight lines at their existing shared endpoint, preserving references. */
export function applyLineCorner(
  source: SketchDrawing,
  a: CornerLine,
  b: CornerLine,
  apply: (
    drawing: SketchDrawing,
    contour: number,
    vertex: number,
    firstIsIncoming: boolean,
  ) => SketchDrawing,
): SketchDrawing {
  if (a.contour === b.contour) {
    const path = source.contours[a.contour];
    if (path?.type !== "path") throw new Error("Select two lines.");
    const lo = Math.min(a.segment, b.segment),
      hi = Math.max(a.segment, b.segment);
    if (lo === 0 && hi === path.segments.length - 1 && contourClosed(path))
      return apply(source, a.contour, 0, a.segment === hi);
    if (hi - lo !== 1)
      throw new Error("Select adjacent lines sharing a corner.");
    return apply(source, a.contour, hi, a.segment === lo);
  }
  const first = source.contours[a.contour],
    second = source.contours[b.contour];
  if (
    first?.type !== "path" ||
    second?.type !== "path" ||
    first.segments.length !== 1 ||
    second.segments.length !== 1 ||
    a.segment !== 0 ||
    b.segment !== 0 ||
    first.segments[0].type !== "line" ||
    second.segments[0].type !== "line"
  )
    throw new Error(
      "Separate-contour corner operations currently require two single lines.",
    );
  if (!!first.construction !== !!second.construction)
    throw new Error(
      "Both selected lines must have the same construction mode.",
    );
  const p = [first.start, first.segments[0].end],
    q = [second.start, second.segments[0].end];
  let ai = -1,
    bi = -1;
  for (let i = 0; i < 2; i++)
    for (let j = 0; j < 2; j++)
      if (Math.hypot(p[i][0] - q[j][0], p[i][1] - q[j][1]) < 1e-7) {
        ai = i;
        bi = j;
      }
  if (ai < 0)
    return applyLineCorner(
      prepareFilletIntersection(source, a, b),
      a,
      b,
      apply,
    );
  const lower = Math.min(a.contour, b.contour),
    upper = Math.max(a.contour, b.contour),
    next = structuredClone(source);
  const copy = (p: SketchPoint): SketchPoint => [...p];
  next.contours.splice(upper, 1);
  next.contours.splice(lower, 1, {
    type: "path",
    construction: first.construction,
    start: copy(p[1 - ai]),
    segments: [
      { type: "line", end: copy(p[ai]) },
      { type: "line", end: copy(q[1 - bi]) },
    ],
  });
  const map = (r: SketchEntityRef): SketchEntityRef => {
    if (r.contour !== a.contour && r.contour !== b.contour)
      return { ...r, contour: r.contour > upper ? r.contour - 1 : r.contour };
    const isFirst = r.contour === a.contour;
    if (r.kind === "line")
      return { contour: lower, kind: "line", index: isFirst ? 0 : 1 };
    if (r.kind === "point" && r.control === undefined)
      return {
        contour: lower,
        kind: "point",
        index: r.index === (isFirst ? ai : bi) ? 1 : isFirst ? 0 : 2,
      };
    throw new Error("Unsupported selected-line reference.");
  };
  next.constraints = source.constraints?.map((c) => ({
    ...c,
    a: map(c.a),
    ...(c.b ? { b: map(c.b) } : {}),
    ...(c.axis ? { axis: map(c.axis) } : {}),
  }));
  return apply(next, lower, 1, true);
}
