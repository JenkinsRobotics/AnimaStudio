import type { SketchPoint } from "./drawing";
import { ellipticalArcGuide } from "./elliptical-arc";
import { ellipseFrame } from "./curves/parameterization";
import { ellipseQuadrant } from "./solver/ellipse-contact";
/** Snap only the temporary construction ellipse; it is not an authored contour. */
export function snapEllipticalArcGuide(
  pending: SketchPoint[],
  point: SketchPoint,
  tolerance: number,
  options: {
    secondaryRadiusMillimeters?: number;
    rememberedRadiusMillimeters?: number;
  } = {},
) {
  if (
    (pending.length !== 2 && pending.length !== 3) ||
    !Number.isFinite(tolerance) ||
    tolerance < 0
  )
    return;
  const points = pending.length === 2 ? [...pending, point] : pending;
  let guide;
  try {
    guide = ellipticalArcGuide(
      points,
      options.secondaryRadiusMillimeters,
      options.rememberedRadiusMillimeters,
    );
  } catch {
    if (
      pending.length !== 2 ||
      options.secondaryRadiusMillimeters !== undefined ||
      options.rememberedRadiusMillimeters === undefined
    )
      return;
    try {
      guide = ellipticalArcGuide(points, options.rememberedRadiusMillimeters);
    } catch {
      return;
    }
  }
  const segment = guide.segments[0];
  if (segment.type !== "ellipse") return;
  const e = { ...ellipseFrame(guide.start, segment), center: pending[0] };
  let best: { point: SketchPoint; quadrant: 0 | 1 | 2 | 3 } | undefined,
    distance = tolerance;
  for (const quadrant of [0, 1, 2, 3] as const) {
    const p = ellipseQuadrant(e, quadrant),
      d = Math.hypot(p[0] - point[0], p[1] - point[1]);
    if (d <= distance) {
      distance = d;
      best = { point: p, quadrant };
    }
  }
  return best;
}
