import type { SketchPoint } from "../drawing";

/** Finite collinear contact, including a shared endpoint. Tolerance is a
 * distance in sketch units, independent of either segment's length. */
export function collinearLineContact(
  a: SketchPoint,
  b: SketchPoint,
  c: SketchPoint,
  d: SketchPoint,
  tolerance = 1e-8,
): boolean {
  const dx = b[0] - a[0],
    dy = b[1] - a[1];
  const length = Math.hypot(dx, dy);
  if (length <= tolerance) return false;
  const ux = dx / length,
    uy = dy / length;
  const perpendicular = (p: SketchPoint) =>
    Math.abs((p[0] - a[0]) * uy - (p[1] - a[1]) * ux);
  if (perpendicular(c) > tolerance || perpendicular(d) > tolerance)
    return false;
  const project = (p: SketchPoint) => (p[0] - a[0]) * ux + (p[1] - a[1]) * uy;
  const t = project(c),
    u = project(d);
  return (
    Math.max(0, Math.min(t, u)) <= Math.min(length, Math.max(t, u)) + tolerance
  );
}
