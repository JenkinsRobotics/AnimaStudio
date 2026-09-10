import {
  contourClosed,
  type SketchContour,
  type SketchPoint,
} from "../drawing";
import { circleSegments } from "../curves/picking";
import { curveIntersections, type Curve } from "../curves/pairs";
import { curveJet } from "../curves/derivatives";
import { ellipseFrame } from "../curves/parameterization";
import { sketchArcGeometry } from "../arc-geometry";
function curves(c: SketchContour): Curve[] {
  if (c.type === "circle") return circleSegments(c.center, c.radius);
  return c.segments.map((segment, i) => ({
    start: i ? c.segments[i - 1].end : c.start,
    segment,
  }));
}
const distance = (a: SketchPoint, b: SketchPoint) =>
  Math.hypot(a[0] - b[0], a[1] - b[1]);
function bound(c: Curve, p: SketchPoint): number {
  const s = c.segment;
  if (s.type === "arc") {
    const a = sketchArcGeometry(c.start, s.middle, s.end);
    return distance(p, a.center) + a.radius;
  }
  if (s.type === "ellipse") {
    const a = ellipseFrame(c.start, s);
    return distance(p, a.center) + Math.max(a.radiusX, a.radiusY);
  }
  return Math.max(
    ...[c.start, s.end, ...(s.type === "bezier" ? s.controls : [])].map((q) =>
      distance(p, q),
    ),
  );
}
/** Retry ray directions which hit vertices or tangencies, avoiding double counts. */
function inside(p: SketchPoint, boundary: Curve[]): boolean | undefined {
  const length = 2 * (1 + Math.max(...boundary.map((c) => bound(c, p))));
  for (const angle of [
    0.123, 0.713, 1.337, 2.017, 2.731, 3.417, 4.193, 5.119,
  ]) {
    const direction: SketchPoint = [Math.cos(angle), Math.sin(angle)],
      ray: Curve = {
        start: p,
        segment: {
          type: "line",
          end: [p[0] + length * direction[0], p[1] + length * direction[1]],
        },
      };
    let crossings = 0,
      ambiguous = false;
    for (const c of boundary) {
      for (const hit of curveIntersections(ray, c)) {
        const tangent = curveJet(c)(hit.second).first,
          n = Math.hypot(...tangent);
        if (
          hit.first < 1e-9 ||
          hit.second < 1e-8 ||
          hit.second > 1 - 1e-8 ||
          n < 1e-12 ||
          Math.abs(direction[0] * tangent[1] - direction[1] * tangent[0]) / n <
            1e-8
        ) {
          ambiguous = true;
          break;
        }
        crossings++;
      }
      if (ambiguous) break;
    }
    if (!ambiguous) return crossings % 2 === 1;
  }
  return undefined;
}
/** Depth only for simple, mutually disjoint closed boundaries. Touching,
 * overlapping or numerically ambiguous boundaries return undefined for review. */
export function contourNestingDepths(
  contours: readonly SketchContour[],
): number[] | undefined {
  if (contours.some((c) => !contourClosed(c))) return;
  const boundaries = contours.map(curves);
  for (let i = 0; i < boundaries.length; i++) {
    const a = boundaries[i];
    for (let j = 0; j < a.length; j++)
      for (let k = j + 1; k < a.length; k++) {
        const allowed: SketchPoint[] = [];
        if (k === j + 1) allowed.push(a[j].segment.end);
        if (j === 0 && k === a.length - 1) allowed.push(a[0].start);
        if (
          curveIntersections(a[j], a[k]).some(
            (h) => !allowed.some((p) => distance(p, h.point) < 1e-7),
          )
        )
          return;
      }
    for (let j = i + 1; j < boundaries.length; j++)
      for (const c of a)
        for (const d of boundaries[j])
          if (curveIntersections(c, d).length) return;
  }
  const depths: number[] = [];
  for (let i = 0; i < boundaries.length; i++) {
    let depth = 0;
    for (let j = 0; j < boundaries.length; j++)
      if (i !== j) {
        const contained = inside(boundaries[i][0].start, boundaries[j]);
        if (contained === undefined) return;
        if (contained) depth++;
      }
    depths.push(depth);
  }
  return depths;
}
