import type { SketchPoint } from "../drawing";
import type { SketchTransform } from "./similarity";
/** Reflect about an arbitrary line in the sketch plane, not just an axis. */
export function mirrorTransform(
  start: SketchPoint,
  end: SketchPoint,
): SketchTransform {
  const dx = end[0] - start[0],
    dy = end[1] - start[1],
    length = Math.hypot(dx, dy);
  if (![...start, ...end].every(Number.isFinite) || length < 1e-8)
    throw new Error("Mirror needs two distinct points on its axis.");
  const x = dx / length,
    y = dy / length,
    a = 2 * x * x - 1,
    b = 2 * x * y,
    c = b,
    d = 2 * y * y - 1;
  return {
    a,
    b,
    c,
    d,
    tx: start[0] - a * start[0] - b * start[1],
    ty: start[1] - c * start[0] - d * start[1],
  };
}
