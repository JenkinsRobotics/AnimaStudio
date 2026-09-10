import { cubicOverlap } from "./cubic-overlap";
import type { SketchPoint, SketchSegment } from "../drawing";
import {
  ellipseFrame,
  ellipsePoint,
  segmentPoint,
  closestSegmentParameter,
  type EllipseFrame,
} from "./parameterization";
import { sketchArcGeometry } from "../arc-geometry";
import { lineSegmentIntersections, polynomialRoots } from "./intersections";
import { subdivideSegment } from "./subdivide";
export interface Curve {
  start: SketchPoint;
  segment: SketchSegment;
}
export interface CurveIntersection {
  first: number;
  second: number;
  point: SketchPoint;
}
const tau = 2 * Math.PI;
const squaredPolynomial = (p: number[]) => {
  const out = Array(p.length * 2 - 1).fill(0) as number[];
  p.forEach((a, i) => p.forEach((b, j) => (out[i + j] += a * b)));
  return out;
};
const add = (a: number[], b: number[]) =>
  Array.from(
    { length: Math.max(a.length, b.length) },
    (_, i) => (a[i] ?? 0) + (b[i] ?? 0),
  );
function conic(curve: Curve): EllipseFrame | null {
  const s = curve.segment;
  if (s.type === "ellipse") return ellipseFrame(curve.start, s);
  if (s.type === "arc") {
    const arc = sketchArcGeometry(curve.start, s.middle, s.end);
    return { ...arc, radiusX: arc.radius, radiusY: arc.radius, rotation: 0 };
  }
  return null;
}
function onConic(frame: EllipseFrame, p: SketchPoint): number | null {
  const x = p[0] - frame.center[0],
    y = p[1] - frame.center[1],
    cos = Math.cos(frame.rotation),
    sin = Math.sin(frame.rotation);
  const angle = Math.atan2(
    (-sin * x + cos * y) / frame.radiusY,
    (cos * x + sin * y) / frame.radiusX,
  );
  let extent =
    frame.sweep >= 0
      ? (angle - frame.startAngle + tau) % tau
      : (frame.startAngle - angle + tau) % tau;
  if (Math.abs(extent - tau) < 1e-7) extent = 0;
  const t = extent / Math.abs(frame.sweep);
  return t >= -1e-8 && t <= 1 + 1e-8 ? Math.max(0, Math.min(1, t)) : null;
}
function local(frame: EllipseFrame, p: SketchPoint): SketchPoint {
  const x = p[0] - frame.center[0],
    y = p[1] - frame.center[1],
    c = Math.cos(frame.rotation),
    s = Math.sin(frame.rotation);
  return [(c * x + s * y) / frame.radiusX, (-s * x + c * y) / frame.radiusY];
}
/** Roots of a cubic against an implicit ellipse/circle equation (degree at most six). */
function bezierConic(curve: Curve, frame: EllipseFrame): number[] {
  if (curve.segment.type !== "bezier")
    throw new Error("Expected a cubic curve.");
  const p = [curve.start, ...curve.segment.controls, curve.segment.end].map(
    (p) => local(frame, p),
  );
  const coefficients = (axis: number) => [
    p[0][axis],
    3 * (p[1][axis] - p[0][axis]),
    3 * (p[2][axis] - 2 * p[1][axis] + p[0][axis]),
    p[3][axis] - 3 * p[2][axis] + 3 * p[1][axis] - p[0][axis],
  ];
  const polynomial = add(
    squaredPolynomial(coefficients(0)),
    squaredPolynomial(coefficients(1)),
  );
  polynomial[0] -= 1;
  return polynomialRoots(polynomial);
}
/** Rational tan-half-angle substitution gives a quartic for conic/conic intersections. */
function conicConic(first: EllipseFrame, second: EllipseFrame): SketchPoint[] {
  const c = Math.cos(first.rotation),
    s = Math.sin(first.rotation);
  const center = local(second, first.center),
    x = local(second, [
      first.center[0] + c * first.radiusX,
      first.center[1] + s * first.radiusX,
    ]),
    y = local(second, [
      first.center[0] - s * first.radiusY,
      first.center[1] + c * first.radiusY,
    ]);
  const u: SketchPoint = [x[0] - center[0], x[1] - center[1]],
    v: SketchPoint = [y[0] - center[0], y[1] - center[1]];
  const px = [center[0] + u[0], 2 * v[0], center[0] - u[0]],
    py = [center[1] + u[1], 2 * v[1], center[1] - u[1]];
  const polynomial = add(squaredPolynomial(px), squaredPolynomial(py));
  polynomial[0] -= 1;
  polynomial[2] -= 2;
  polynomial[4] -= 1;
  while (polynomial.length > 1 && Math.abs(polynomial.at(-1)!) < 1e-12)
    polynomial.pop();
  if (polynomial.every((v) => Math.abs(v) < 1e-10)) {
    const firstPoints = [0, 1].map((t) => ellipsePoint(first, t)),
      secondPoints = [0, 1].map((t) => ellipsePoint(second, t));
    return [...firstPoints, ...secondPoints].filter(
      (p) => onConic(first, p) !== null && onConic(second, p) !== null,
    );
  }
  if (polynomial.length === 1) return [];
  const leading = Math.abs(polynomial.at(-1)!),
    bound =
      1 +
      Math.max(...polynomial.slice(0, -1).map((v) => Math.abs(v) / leading));
  const angles = polynomialRoots(polynomial, -bound, bound).map(
    (t) => 2 * Math.atan(t),
  );
  // The tan-half-angle representation omits pi; check that point explicitly.
  const piPoint: SketchPoint = [
      first.center[0] - c * first.radiusX,
      first.center[1] - s * first.radiusX,
    ],
    piLocal = local(second, piPoint);
  if (Math.abs(piLocal[0] ** 2 + piLocal[1] ** 2 - 1) < 1e-8)
    angles.push(Math.PI);
  return angles.map((angle) => [
    first.center[0] +
      c * first.radiusX * Math.cos(angle) -
      s * first.radiusY * Math.sin(angle),
    first.center[1] +
      s * first.radiusX * Math.cos(angle) +
      c * first.radiusY * Math.sin(angle),
  ]);
}
function derivative(curve: Curve, t: number): SketchPoint {
  const h = 1e-6,
    a = segmentPoint(curve.start, curve.segment, t - h),
    b = segmentPoint(curve.start, curve.segment, t + h);
  return [(b[0] - a[0]) / (2 * h), (b[1] - a[1]) / (2 * h)];
}
function bezierPairs(first: Curve, second: Curve): CurveIntersection[] {
  type Piece = { curve: Curve; lo: number; hi: number };
  const box = (curve: Curve) => {
    const s = curve.segment;
    if (s.type !== "bezier") throw new Error("Expected cubic.");
    const p = [curve.start, ...s.controls, s.end];
    return {
      x0: Math.min(...p.map((p) => p[0])),
      x1: Math.max(...p.map((p) => p[0])),
      y0: Math.min(...p.map((p) => p[1])),
      y1: Math.max(...p.map((p) => p[1])),
    };
  };
  const halves = (piece: Piece): [Piece, Piece] => {
    const [a, b] = subdivideSegment(
        piece.curve.start,
        piece.curve.segment,
        0.5,
      ),
      mid = (piece.lo + piece.hi) / 2;
    return [
      {
        curve: { start: piece.curve.start, segment: a },
        lo: piece.lo,
        hi: mid,
      },
      { curve: { start: a.end, segment: b }, lo: mid, hi: piece.hi },
    ];
  };
  const overlap = cubicOverlap(first, second);
  if (overlap) return overlap;
  const queue: [Piece, Piece][] = [
      [
        { curve: first, lo: 0, hi: 1 },
        { curve: second, lo: 0, hi: 1 },
      ],
    ],
    hits: CurveIntersection[] = [];
  let iterations = 0;
  while (queue.length) {
    if (++iterations > 50000)
      throw new Error(
        "Overlapping or unresolved cubic intersections; no geometry was changed.",
      );
    const [a, b] = queue.pop()!,
      ab = box(a.curve),
      bb = box(b.curve);
    if (
      ab.x1 < bb.x0 - 1e-9 ||
      bb.x1 < ab.x0 - 1e-9 ||
      ab.y1 < bb.y0 - 1e-9 ||
      bb.y1 < ab.y0 - 1e-9
    )
      continue;
    const as = Math.max(ab.x1 - ab.x0, ab.y1 - ab.y0),
      bs = Math.max(bb.x1 - bb.x0, bb.y1 - bb.y0);
    if (Math.max(as, bs) < 1e-5) {
      let t = (a.lo + a.hi) / 2,
        u = (b.lo + b.hi) / 2;
      for (let i = 0; i < 20; i++) {
        const p = segmentPoint(first.start, first.segment, t),
          q = segmentPoint(second.start, second.segment, u),
          d = derivative(first, t),
          e = derivative(second, u),
          dx = p[0] - q[0],
          dy = p[1] - q[1],
          det = e[0] * d[1] - d[0] * e[1];
        if (Math.abs(det) < 1e-12) break;
        const dt = (dx * e[1] - e[0] * dy) / det,
          du = (dx * d[1] - d[0] * dy) / det;
        t = Math.max(0, Math.min(1, t + dt));
        u = Math.max(0, Math.min(1, u + du));
      }
      const p = segmentPoint(first.start, first.segment, t),
        q = segmentPoint(second.start, second.segment, u);
      if (Math.hypot(p[0] - q[0], p[1] - q[1]) < 1e-7)
        hits.push({ first: t, second: u, point: p });
      continue;
    }
    if (as >= bs) {
      const [left, right] = halves(a);
      queue.push([left, b], [right, b]);
    } else {
      const [left, right] = halves(b);
      queue.push([a, left], [a, right]);
    }
  }
  return hits;
}
/** Intersections are numerical roots of exact curve representations, never polygon intersections. */
export function curveIntersections(
  first: Curve,
  second: Curve,
): CurveIntersection[] {
  let hits: CurveIntersection[] = [];
  if (first.segment.type === "line") {
    if (second.segment.type === "line" || second.segment.type === "bezier") {
      const dx = first.segment.end[0] - first.start[0],
        dy = first.segment.end[1] - first.start[1],
        length = dx * dx + dy * dy;
      const points = [
        second.start,
        ...(second.segment.type === "bezier" ? second.segment.controls : []),
        second.segment.end,
      ];
      if (
        length > 1e-20 &&
        points.every(
          (p) =>
            Math.abs(
              dx * (p[1] - first.start[1]) - dy * (p[0] - first.start[0]),
            ) /
              Math.sqrt(length) <
            1e-8,
        )
      ) {
        const t = points.map(
          (p) =>
            ((p[0] - first.start[0]) * dx + (p[1] - first.start[1]) * dy) /
            length,
        );
        if (second.segment.type === "line") {
          const lo = Math.max(0, Math.min(...t)),
            hi = Math.min(1, Math.max(...t));
          if (hi < lo - 1e-8) return [];
          return (Math.abs(hi - lo) < 1e-8 ? [lo] : [lo, hi]).map(
            (parameter) => ({
              first: parameter,
              second: (parameter - t[0]) / (t[1] - t[0]),
              point: segmentPoint(first.start, first.segment, parameter),
            }),
          );
        }
        if (Math.min(1, Math.max(...t)) - Math.max(0, Math.min(...t)) > 1e-8)
          throw new Error(
            "Coincident curves need overlap handling before trimming.",
          );
      }
    }
    for (const t of lineSegmentIntersections(
      first.start,
      first.segment.end,
      second.start,
      second.segment,
    ))
      if (t >= -1e-8 && t <= 1 + 1e-8) {
        const point = segmentPoint(first.start, first.segment, t);
        hits.push({
          first: Math.max(0, Math.min(1, t)),
          second: closestSegmentParameter(second.start, second.segment, point)
            .parameter,
          point,
        });
      }
  } else if (second.segment.type === "line")
    return curveIntersections(second, first).map((h) => ({
      first: h.second,
      second: h.first,
      point: h.point,
    }));
  else {
    const a = conic(first),
      b = conic(second);
    if (a && b) {
      for (const point of conicConic(a, b)) {
        const t = onConic(a, point),
          u = onConic(b, point);
        if (t !== null && u !== null) hits.push({ first: t, second: u, point });
      }
    } else if (b) {
      for (const t of bezierConic(first, b)) {
        const point = segmentPoint(first.start, first.segment, t),
          u = onConic(b, point);
        if (u !== null) hits.push({ first: t, second: u, point });
      }
    } else if (a)
      return curveIntersections(second, first).map((h) => ({
        first: h.second,
        second: h.first,
        point: h.point,
      }));
    else hits = bezierPairs(first, second);
  }
  return hits
    .sort((a, b) => a.first - b.first)
    .filter(
      (h, i, list) =>
        !list
          .slice(0, i)
          .some(
            (p) =>
              Math.abs(p.first - h.first) < 1e-5 &&
              Math.abs(p.second - h.second) < 1e-5,
          ),
    );
}
