import type { SketchPoint } from "../drawing";
import type { CurveJet } from "../curves/derivatives";
/** Contact on the supporting circle may slide; the other curve retains its
 * chosen parameter. Signed curvature distinguishes osculation from an S bend. */
export function circleContinuityResiduals(
  circle: { center: SketchPoint; radius: number },
  curve: CurveJet,
  curvature = false,
): number[] {
  const dx = circle.center[0] - curve.point[0],
    dy = circle.center[1] - curve.point[1],
    distance = Math.hypot(dx, dy),
    speed = Math.hypot(...curve.first),
    r = circle.radius;
  if (!Number.isFinite(r) || r <= 0 || distance < 1e-10 || speed < 1e-10)
    throw Error(
      "Circle continuity requires a positive radius and a nonstationary contact away from its center.",
    );
  const residuals = [
    distance - r,
    (dx * curve.first[0] + dy * curve.first[1]) / (distance * speed),
  ];
  if (curvature) {
    const k =
      (curve.first[0] * curve.second[1] - curve.first[1] * curve.second[0]) /
      speed ** 3;
    const circleK =
      (curve.first[0] * dy - curve.first[1] * dx) / (speed * r * r);
    residuals.push((k - circleK) * r);
  }
  return residuals;
}
