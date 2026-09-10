import {
  contourClosed,
  validateSketchDrawing,
  type SketchDrawing,
  type SketchPoint,
} from "../drawing";
import { breakLineCorner } from "./break-line-corner";
import { assertConstraintsSatisfied } from "./preserve-constraints";
/** Exact circular fillet at a shared straight-line vertex, retaining a virtual sharp. */
export function filletSketchCorner(
  source: SketchDrawing,
  contourIndex: number,
  vertex: number,
  radius: number,
): SketchDrawing {
  const path = source.contours[contourIndex];
  if (path?.type !== "path") throw new Error("Choose a path corner.");
  const count = path.segments.length,
    closed = contourClosed(path);
  if (
    !Number.isInteger(vertex) ||
    vertex < 0 ||
    vertex >= count ||
    (!closed && vertex === 0)
  )
    throw new Error("Choose a vertex between two lines.");
  if (!Number.isFinite(radius) || radius <= 0)
    throw new Error("Enter a positive fillet radius.");
  const incoming = vertex === 0 ? count - 1 : vertex - 1,
    outgoing = vertex;
  if (
    path.segments[incoming].type !== "line" ||
    path.segments[outgoing].type !== "line"
  )
    throw new Error("This fillet requires two straight lines.");
  const corner = vertex === 0 ? path.start : path.segments[vertex - 1].end;
  const before = incoming === 0 ? path.start : path.segments[incoming - 1].end,
    after = path.segments[outgoing].end;
  const l0 = Math.hypot(before[0] - corner[0], before[1] - corner[1]),
    l1 = Math.hypot(after[0] - corner[0], after[1] - corner[1]);
  const u: SketchPoint = [
      (before[0] - corner[0]) / l0,
      (before[1] - corner[1]) / l0,
    ],
    v: SketchPoint = [(after[0] - corner[0]) / l1, (after[1] - corner[1]) / l1];
  const angle = Math.acos(Math.max(-1, Math.min(1, u[0] * v[0] + u[1] * v[1])));
  if (!Number.isFinite(angle) || angle < 1e-6 || Math.PI - angle < 1e-6)
    throw new Error("The selected lines do not form a fillet corner.");
  const setback = radius / Math.tan(angle / 2);
  if (setback >= Math.min(l0, l1) - 1e-7)
    throw new Error("The radius is too large for this corner.");
  const a: SketchPoint = [
      corner[0] + u[0] * setback,
      corner[1] + u[1] * setback,
    ],
    b: SketchPoint = [corner[0] + v[0] * setback, corner[1] + v[1] * setback];
  const norm = Math.hypot(u[0] + v[0], u[1] + v[1]),
    bisector: SketchPoint = [(u[0] + v[0]) / norm, (u[1] + v[1]) / norm];
  const centerDistance = radius / Math.sin(angle / 2),
    middle: SketchPoint = [
      corner[0] + bisector[0] * (centerDistance - radius),
      corner[1] + bisector[1] * (centerDistance - radius),
    ];
  const {
    next,
    sharp,
    bridge: arc,
    first,
    second,
  } = breakLineCorner(source, contourIndex, vertex, a, b, {
    type: "arc",
    middle,
    end: b,
  });
  const used = new Set(next.constraints!.map((c) => c.id));
  const id = (kind: string) => {
    const base = `fillet-${contourIndex}-${vertex}-${kind}`;
    let value = base,
      suffix = 0;
    while (used.has(value)) value = `${base}-${++suffix}`;
    used.add(value);
    return value;
  };
  next.constraints!.push(
    { id: id("radius"), kind: "radius", a: arc, value: radius },
    { id: id("tangent-a"), kind: "tangent", a: first, b: arc },
    { id: id("tangent-b"), kind: "tangent", a: second, b: arc },
    { id: id("sharp-a"), kind: "coincident", a: sharp, b: first },
    { id: id("sharp-b"), kind: "coincident", a: sharp, b: second },
  );
  assertConstraintsSatisfied(next);
  validateSketchDrawing(next);
  return next;
}
