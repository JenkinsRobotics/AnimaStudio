import type { SketchPoint } from "./drawing";
/** Exact circumcircle and directed arc through three points, in millimeters/radians. */
export function sketchArcGeometry(
  start: SketchPoint,
  middle: SketchPoint,
  end: SketchPoint,
) {
  const u: [number, number] = [middle[0] - start[0], middle[1] - start[1]],
    v: [number, number] = [end[0] - start[0], end[1] - start[1]];
  const det = 2 * (u[0] * v[1] - u[1] * v[0]);
  if (Math.abs(det) < 1e-12)
    throw new Error("Arc points must not be collinear.");
  const a = u[0] ** 2 + u[1] ** 2,
    b = v[0] ** 2 + v[1] ** 2;
  const center: SketchPoint = [
    start[0] + (a * v[1] - b * u[1]) / det,
    start[1] + (u[0] * b - v[0] * a) / det,
  ];
  const radius = Math.hypot(start[0] - center[0], start[1] - center[1]);
  const angle = (p: SketchPoint) =>
      Math.atan2(p[1] - center[1], p[0] - center[0]),
    tau = 2 * Math.PI;
  const delta = (a: number, b: number) => (b - a + tau) % tau;
  const startAngle = angle(start),
    endAngle = angle(end),
    counterclockwise =
      delta(startAngle, angle(middle)) < delta(startAngle, endAngle);
  const sweep = counterclockwise
    ? delta(startAngle, endAngle)
    : -delta(endAngle, startAngle);
  const midpoint: SketchPoint = [
    center[0] + radius * Math.cos(startAngle + sweep / 2),
    center[1] + radius * Math.sin(startAngle + sweep / 2),
  ];
  return { center, radius, midpoint, startAngle, sweep };
}
