import type { SketchPoint } from "../drawing";
import type { Curve } from "./pairs";
import { ellipseFrame, ellipsePoint, segmentPoint } from "./parameterization";
import { sketchArcGeometry } from "../arc-geometry";
export interface CurveJet {
  point: SketchPoint;
  first: SketchPoint;
  second: SketchPoint;
}
/** Precompute curve frames and evaluate exact first/second derivatives. */
export function curveJet(curve: Curve): (t: number) => CurveJet {
  const s = curve.segment;
  if (s.type === "line")
    return (t) => ({
      point: segmentPoint(curve.start, s, t),
      first: [s.end[0] - curve.start[0], s.end[1] - curve.start[1]],
      second: [0, 0],
    });
  if (s.type === "bezier")
    return (t) => {
      const p = curve.start,
        [a, b] = s.controls,
        q = s.end;
      const first = [0, 1].map(
        (k) =>
          3 *
          ((1 - t) ** 2 * (a[k] - p[k]) +
            2 * (1 - t) * t * (b[k] - a[k]) +
            t * t * (q[k] - b[k])),
      ) as SketchPoint;
      const second = [0, 1].map(
        (k) =>
          6 *
          ((1 - t) * (b[k] - 2 * a[k] + p[k]) + t * (q[k] - 2 * b[k] + a[k])),
      ) as SketchPoint;
      return { point: segmentPoint(p, s, t), first, second };
    };
  const frame =
    s.type === "ellipse"
      ? ellipseFrame(curve.start, s)
      : (() => {
          const arc = sketchArcGeometry(curve.start, s.middle, s.end);
          return {
            ...arc,
            radiusX: arc.radius,
            radiusY: arc.radius,
            rotation: 0,
          };
        })();
  const c = Math.cos(frame.rotation),
    sn = Math.sin(frame.rotation),
    w = frame.sweep;
  const rotate = (x: number, y: number): SketchPoint => [
    c * x - sn * y,
    sn * x + c * y,
  ];
  return (t) => {
    const angle = frame.startAngle + t * w;
    return {
      point: ellipsePoint(frame, t),
      first: rotate(
        -frame.radiusX * Math.sin(angle) * w,
        frame.radiusY * Math.cos(angle) * w,
      ),
      second: rotate(
        -frame.radiusX * Math.cos(angle) * w * w,
        -frame.radiusY * Math.sin(angle) * w * w,
      ),
    };
  };
}
