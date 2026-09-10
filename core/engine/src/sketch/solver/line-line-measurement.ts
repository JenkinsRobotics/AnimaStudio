import type { SketchPoint } from "../drawing";
import { pointLineMeasurement } from "./point-line-measurement";
/** Parallel-line spacing uses infinite supporting lines, independent of endpoint order. */
export function lineLineMeasurement(
  a: [SketchPoint, SketchPoint],
  b: [SketchPoint, SketchPoint],
) {
  const u: SketchPoint = [a[1][0] - a[0][0], a[1][1] - a[0][1]];
  const v: SketchPoint = [b[1][0] - b[0][0], b[1][1] - b[0][1]];
  const la = Math.hypot(...u),
    lb = Math.hypot(...v);
  if (la < 1e-10 || lb < 1e-10)
    throw Error("Select two nonzero-length lines for distance.");
  const p: SketchPoint = [(a[0][0] + a[1][0]) / 2, (a[0][1] + a[1][1]) / 2];
  const measurement = pointLineMeasurement(p, b);
  return {
    ...measurement,
    point: p,
    parallelError: (u[0] / la) * (v[1] / lb) - (u[1] / la) * (v[0] / lb),
  };
}
