import { ellipsePoint, type EllipseFrame } from "../curves/parameterization";
import type { SketchPoint } from "../drawing";
import type { SketchFrameMap } from "./frame-map";

/** Exact turning points of a rank-one conic image. Connecting these points
 * covers its complete line locus, including arcs that reverse direction. */
export function collapsedConicPoints(
  map: SketchFrameMap,
  frame: EllipseFrame,
): SketchPoint[] {
  const c = Math.cos(frame.rotation),
    s = Math.sin(frame.rotation);
  const u = map.vector([frame.radiusX * c, frame.radiusX * s]);
  const v = map.vector([-frame.radiusY * s, frame.radiusY * c]);
  const axis = Math.hypot(u[0], v[0]) >= Math.hypot(u[1], v[1]) ? 0 : 1;
  const phase = Math.atan2(v[axis], u[axis]);
  const parameters = [0, 1];
  for (let k = -6; k <= 6; k++) {
    const t = (phase + k * Math.PI - frame.startAngle) / frame.sweep;
    if (t > 1e-12 && t < 1 - 1e-12) parameters.push(t);
  }
  return parameters
    .sort((a, b) => a - b)
    .map((t) => map.point(ellipsePoint(frame, t)));
}

/** A closed collapsed contour has a single interval as its image, even when
 * its source traverses that interval more than once. */
export function collapsedInterval(
  points: readonly SketchPoint[],
): [SketchPoint, SketchPoint] {
  const axis =
    Math.max(...points.map((p) => p[0])) -
      Math.min(...points.map((p) => p[0])) >=
    Math.max(...points.map((p) => p[1])) - Math.min(...points.map((p) => p[1]))
      ? 0
      : 1;
  const sorted = [...points].sort((a, b) => a[axis] - b[axis]);
  return [sorted[0], sorted[sorted.length - 1]];
}
