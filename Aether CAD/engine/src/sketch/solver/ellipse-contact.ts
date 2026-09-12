import { angularSpanDistance } from "../curves/angular-span";
import type { SketchPoint } from "../drawing";
import type { resolve } from "./entities";
type Ellipse = NonNullable<ReturnType<typeof resolve>["ellipse"]>;
export function ellipseQuadrant(e: Ellipse, index: number): SketchPoint {
  if (!Number.isInteger(index) || index < 0 || index > 3)
    throw Error("Choose one of the four ellipse quadrants.");
  const a = (index * Math.PI) / 2,
    x = e.radiusX * Math.cos(a),
    y = e.radiusY * Math.sin(a),
    c = Math.cos(e.rotation),
    s = Math.sin(e.rotation);
  return [e.center[0] + c * x - s * y, e.center[1] + s * x + c * y];
}
export function nearestEllipseQuadrant(
  e: Ellipse,
  p: SketchPoint,
  span?: { startAngle: number; sweep: number },
): 0 | 1 | 2 | 3 {
  let best = 0,
    distance = Infinity;
  for (let i = 0; i < 4; i++) {
    if (
      span &&
      angularSpanDistance(span.startAngle, span.sweep, (i * Math.PI) / 2) > 0
    )
      continue;
    const q = ellipseQuadrant(e, i),
      d = Math.hypot(q[0] - p[0], q[1] - p[1]);
    if (d < distance) {
      distance = d;
      best = i;
    }
  }
  if (!Number.isFinite(distance))
    throw Error("The selected arc contains no axis quadrant.");
  return best as 0 | 1 | 2 | 3;
}
/** Radial zero set of the supporting ellipse, in millimeter-scaled residuals. */
export function pointOnEllipse(e: Ellipse, p: SketchPoint): number {
  const dx = p[0] - e.center[0],
    dy = p[1] - e.center[1],
    c = Math.cos(e.rotation),
    s = Math.sin(e.rotation);
  return (
    (Math.hypot((c * dx + s * dy) / e.radiusX, (-s * dx + c * dy) / e.radiusY) -
      1) *
    Math.min(e.radiusX, e.radiusY)
  );
}

/** Circular quadrants use sketch axes; ellipse quadrants use its local axes. */
export function quadrantFrame(
  entity: ReturnType<typeof resolve>,
): Ellipse | undefined {
  if (entity.ellipse) return entity.ellipse;
  if (entity.circle)
    return {
      center: entity.circle.center,
      radiusX: entity.circle.radius,
      radiusY: entity.circle.radius,
      rotation: 0,
    };
  return undefined;
}

/** Whole ellipse shape relations resolve without a finite span. */
export function quadrantSpan(
  entity: ReturnType<typeof resolve>,
): { startAngle: number; sweep: number } | undefined {
  if (entity.arc) return entity.arc;
  const ellipse = entity.ellipse;
  if (
    ellipse &&
    "startAngle" in ellipse &&
    "sweep" in ellipse &&
    typeof ellipse.startAngle === "number" &&
    typeof ellipse.sweep === "number"
  )
    return { startAngle: ellipse.startAngle, sweep: ellipse.sweep };
  return undefined;
}
