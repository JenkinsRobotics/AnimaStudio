import type { CurveJet } from "../curves/derivatives";

/** Geometric continuity at fixed curve parameters; independent of parameter speed.
 * Curvature is signed 1/mm, adjusted for opposite curve orientations and scaled
 * by a local length for the numerical solver. Only one curvature equation is
 * needed once tangent directions coincide.
 */
export function curveContinuityResiduals(
  p: CurveJet,
  q: CurveJet,
  curvature = false,
): number[] {
  const lp = Math.hypot(...p.first),
    lq = Math.hypot(...q.first);
  if (lp < 1e-10 || lq < 1e-10)
    throw new Error("A stationary curve point has no continuity direction.");
  const cross = (a: number[], b: number[]) => a[0] * b[1] - a[1] * b[0];
  const residuals = [
    p.point[0] - q.point[0],
    p.point[1] - q.point[1],
    cross(p.first, q.first) / (lp * lq),
  ];
  if (curvature) {
    const orientation =
      (p.first[0] * q.first[0] + p.first[1] * q.first[1]) / (lp * lq);
    const kp = cross(p.first, p.second) / lp ** 3;
    const kq = cross(q.first, q.second) / lq ** 3;
    residuals.push((kp - orientation * kq) * Math.sqrt(lp * lq));
  }
  return residuals;
}
