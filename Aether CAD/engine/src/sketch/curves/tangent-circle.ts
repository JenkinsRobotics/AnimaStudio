import type { SketchPoint } from "../drawing";
import type { Curve } from "./pairs";
import { curveJet, type CurveJet } from "./derivatives";
export interface TangentCircle {
  center: SketchPoint;
  radius: number;
  firstParameter: number;
  secondParameter: number;
  firstPoint: SketchPoint;
  secondPoint: SketchPoint;
}
function offset(jet: CurveJet, radius: number, side: number) {
  const [dx, dy] = jet.first,
    speed = Math.hypot(dx, dy);
  if (speed < 1e-10) return;
  const tx = dx / speed,
    ty = dy / speed,
    along = tx * jet.second[0] + ty * jet.second[1];
  const dtx = (jet.second[0] - tx * along) / speed,
    dty = (jet.second[1] - ty * along) / speed;
  return {
    point: [
      jet.point[0] - side * radius * ty,
      jet.point[1] + side * radius * tx,
    ] as SketchPoint,
    derivative: [
      dx - side * radius * dty,
      dy + side * radius * dtx,
    ] as SketchPoint,
  };
}
/** Find finite-curve tangent circles by intersecting exact normal-offset curves. */
export function tangentCircles(
  first: Curve,
  second: Curve,
  radius: number,
  firstPick = 0.5,
  secondPick = 0.5,
): TangentCircle[] {
  if (![radius, firstPick, secondPick].every(Number.isFinite) || radius <= 0)
    throw new Error("Enter a positive finite fillet radius and finite picks.");
  const a = curveJet(first),
    b = curveJet(second),
    solutions: TangentCircle[] = [];
  const seeds = (pick: number) => [
    ...new Set([
      0,
      0.125,
      0.25,
      0.375,
      0.5,
      0.625,
      0.75,
      0.875,
      1,
      Math.max(0, Math.min(1, pick)),
    ]),
  ];
  const clamp = (t: number) => Math.max(0, Math.min(1, t));
  for (const sa of [-1, 1])
    for (const sb of [-1, 1])
      for (const t0 of seeds(firstPick))
        for (const u0 of seeds(secondPick)) {
          let t = t0,
            u = u0;
          for (let iteration = 0; iteration < 40; iteration++) {
            const p = offset(a(t), radius, sa),
              q = offset(b(u), radius, sb);
            if (!p || !q) break;
            const x = p.point[0] - q.point[0],
              y = p.point[1] - q.point[1],
              error = Math.hypot(x, y);
            if (error < 1e-7) {
              const ap = a(t).point,
                bp = b(u).point;
              if (
                Math.hypot(ap[0] - bp[0], ap[1] - bp[1]) > 1e-7 &&
                !solutions.some(
                  (s) =>
                    Math.abs(s.firstParameter - t) < 1e-6 &&
                    Math.abs(s.secondParameter - u) < 1e-6,
                )
              )
                solutions.push({
                  center: [
                    (p.point[0] + q.point[0]) / 2,
                    (p.point[1] + q.point[1]) / 2,
                  ],
                  radius,
                  firstParameter: t,
                  secondParameter: u,
                  firstPoint: ap,
                  secondPoint: bp,
                });
              break;
            }
            const d = p.derivative,
              e = q.derivative,
              det = e[0] * d[1] - d[0] * e[1];
            if (Math.abs(det) < 1e-12) break;
            const dt = (x * e[1] - e[0] * y) / det,
              du = (x * d[1] - d[0] * y) / det;
            let improved = false;
            for (let step = 1; step >= 1 / 1024; step /= 2) {
              const nt = clamp(t + dt * step),
                nu = clamp(u + du * step),
                np = offset(a(nt), radius, sa),
                nq = offset(b(nu), radius, sb);
              if (
                np &&
                nq &&
                Math.hypot(
                  np.point[0] - nq.point[0],
                  np.point[1] - nq.point[1],
                ) < error
              ) {
                t = nt;
                u = nu;
                improved = true;
                break;
              }
            }
            if (!improved) break;
          }
        }
  return solutions.sort(
    (a, b) =>
      (a.firstParameter - firstPick) ** 2 +
      (a.secondParameter - secondPick) ** 2 -
      (b.firstParameter - firstPick) ** 2 -
      (b.secondParameter - secondPick) ** 2,
  );
}
