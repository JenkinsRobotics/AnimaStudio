import type { SketchPoint } from "./drawing";

/** Snap a three-point arc's curvature point onto the circle whose diameter is
 * its chosen endpoint chord. Retains the pointer's angular position. */
export function snapSemicircle(
  start: SketchPoint,
  end: SketchPoint,
  point: SketchPoint,
  tolerance: number,
): SketchPoint | undefined {
  if (
    ![...start, ...end, ...point, tolerance].every(Number.isFinite) ||
    tolerance < 0
  )
    return;
  const center: SketchPoint = [
    (start[0] + end[0]) / 2,
    (start[1] + end[1]) / 2,
  ];
  const radius = Math.hypot(end[0] - start[0], end[1] - start[1]) / 2;
  const dx = point[0] - center[0],
    dy = point[1] - center[1];
  const distance = Math.hypot(dx, dy);
  if (
    radius < 1e-8 ||
    distance < 1e-8 ||
    Math.abs(distance - radius) > tolerance
  )
    return;
  const result: SketchPoint = [
    center[0] + (dx * radius) / distance,
    center[1] + (dy * radius) / distance,
  ];
  // An endpoint or collinear third point does not define an arc.
  const cross =
    (end[0] - start[0]) * (result[1] - start[1]) -
    (end[1] - start[1]) * (result[0] - start[0]);
  if (Math.abs(cross) < 1e-8 * radius * radius) return;
  return result;
}
