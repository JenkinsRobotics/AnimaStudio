import {
  contourClosed,
  validateSketchDrawing,
  type SketchDrawing,
  type SketchPoint,
} from "../drawing";
import { breakLineCorner } from "./break-line-corner";
import { assertConstraintsSatisfied } from "./preserve-constraints";
export type ChamferSize =
  | { mode: "equal-distance"; distance: number }
  | { mode: "two-distances"; distance: number; secondDistance: number }
  | { mode: "distance-angle"; distance: number; angleDegrees: number };
/** Break a straight sketch corner, retaining the virtual sharp and driving dimensions. */
export function chamferSketchCorner(
  source: SketchDrawing,
  contour: number,
  vertex: number,
  size: ChamferSize,
  reverse = false,
): SketchDrawing {
  const path = source.contours[contour];
  if (path?.type !== "path") throw new Error("Choose a path corner.");
  const count = path.segments.length;
  if (
    !Number.isInteger(vertex) ||
    vertex < 0 ||
    vertex >= count ||
    (!contourClosed(path) && vertex === 0)
  )
    throw new Error("Choose a vertex between two lines.");
  const incoming = vertex === 0 ? count - 1 : vertex - 1,
    outgoing = vertex;
  if (
    path.segments[incoming].type !== "line" ||
    path.segments[outgoing].type !== "line"
  )
    throw new Error("Chamfer requires two straight lines.");
  const corner = vertex === 0 ? path.start : path.segments[vertex - 1].end,
    before = incoming === 0 ? path.start : path.segments[incoming - 1].end,
    after = path.segments[outgoing].end;
  const la = Math.hypot(before[0] - corner[0], before[1] - corner[1]),
    lb = Math.hypot(after[0] - corner[0], after[1] - corner[1]);
  const u: SketchPoint = [
      (before[0] - corner[0]) / la,
      (before[1] - corner[1]) / la,
    ],
    v: SketchPoint = [(after[0] - corner[0]) / lb, (after[1] - corner[1]) / lb];
  const theta = Math.acos(Math.max(-1, Math.min(1, u[0] * v[0] + u[1] * v[1])));
  if (!Number.isFinite(theta) || theta < 1e-6 || Math.PI - theta < 1e-6)
    throw new Error("The lines do not form a chamfer corner.");
  let d1 = size.distance;
  let d2 = size.mode === "two-distances" ? size.secondDistance : d1;
  if (size.mode === "distance-angle") {
    const angle = (size.angleDegrees * Math.PI) / 180;
    if (!Number.isFinite(angle) || angle <= 0 || angle >= Math.PI - theta)
      throw new Error("The chamfer angle must fit inside the corner triangle.");
    d2 = (d1 * Math.sin(angle)) / Math.sin(Math.PI - theta - angle);
  }
  if (reverse) [d1, d2] = [d2, d1];
  if (!Number.isFinite(d1) || !Number.isFinite(d2) || d1 <= 0 || d2 <= 0)
    throw new Error("Enter positive chamfer distances.");
  if (d1 >= la - 1e-7 || d2 >= lb - 1e-7)
    throw new Error("The chamfer is too large for this corner.");
  const a: SketchPoint = [corner[0] + u[0] * d1, corner[1] + u[1] * d1],
    b: SketchPoint = [corner[0] + v[0] * d2, corner[1] + v[1] * d2];
  const { next, sharp, bridge, first, second } = breakLineCorner(
    source,
    contour,
    vertex,
    a,
    b,
    { type: "line", end: b },
  );
  const used = new Set(next.constraints!.map((c) => c.id));
  const id = (kind: string) => {
    const base = `chamfer-${contour}-${vertex}-${kind}`;
    let result = base,
      n = 0;
    while (used.has(result)) result = `${base}-${++n}`;
    used.add(result);
    return result;
  };
  const p = { contour, kind: "point" as const, index: bridge.index! },
    q = { contour, kind: "point" as const, index: bridge.index! + 1 };
  const firstDistanceID = id("distance-a");
  next.constraints!.push(
    { id: id("sharp-a"), kind: "coincident", a: sharp, b: first },
    { id: id("sharp-b"), kind: "coincident", a: sharp, b: second },
    {
      id: firstDistanceID,
      kind: "distance",
      a: sharp,
      b: reverse ? q : p,
      value: size.distance,
    },
  );
  if (size.mode === "distance-angle") {
    const w: SketchPoint = [b[0] - a[0], b[1] - a[1]],
      incomingDirection: SketchPoint = reverse ? w : [-u[0], -u[1]],
      outgoingDirection: SketchPoint = reverse ? v : w;
    const degrees =
      (Math.atan2(
        incomingDirection[0] * outgoingDirection[1] -
          incomingDirection[1] * outgoingDirection[0],
        incomingDirection[0] * outgoingDirection[0] +
          incomingDirection[1] * outgoingDirection[1],
      ) *
        180) /
      Math.PI;
    next.constraints!.push({
      id: id("angle"),
      kind: "angle",
      a: reverse ? bridge : first,
      b: reverse ? second : bridge,
      value: degrees,
    });
  } else
    next.constraints!.push({
      id: id("distance-b"),
      kind: "distance",
      a: sharp,
      b: reverse ? p : q,
      ...(size.mode === "equal-distance"
        ? { valueFrom: firstDistanceID }
        : { value: reverse ? d1 : d2 }),
    });
  assertConstraintsSatisfied(next);
  validateSketchDrawing(next);
  return next;
}
