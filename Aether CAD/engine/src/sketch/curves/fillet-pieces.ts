import type { SketchPoint, SketchSegment } from "../drawing";
import type { Curve } from "./pairs";
import { curveJet } from "./derivatives";
import { subdivideSegment } from "./subdivide";
import { tangentCircles } from "./tangent-circle";
function reverse(curve: Curve): Curve {
  const s = curve.segment;
  const segment: SketchSegment =
    s.type === "bezier"
      ? { ...s, controls: [s.controls[1], s.controls[0]], end: curve.start }
      : s.type === "ellipse"
        ? { ...s, sweep: !s.sweep, end: curve.start }
        : { ...s, end: curve.start };
  return { start: s.end, segment };
}
function portion(curve: Curve, t: number, lower: boolean): Curve | undefined {
  if (lower) {
    if (t < 1e-7) return;
    return t > 1 - 1e-7
      ? curve
      : {
          start: curve.start,
          segment: subdivideSegment(curve.start, curve.segment, t)[0],
        };
  }
  if (t > 1 - 1e-7) return;
  if (t < 1e-7) return curve;
  const [left, right] = subdivideSegment(curve.start, curve.segment, t);
  return { start: left.end, segment: right };
}
/** Exact retained curve portions and a tangent circular bridge; drawing references are handled separately. */
export function filletCurvePieces(
  first: Curve,
  second: Curve,
  radius: number,
  firstPick: number,
  secondPick: number,
): {
  start: SketchPoint;
  segments: SketchSegment[];
  firstParameter: number;
  secondParameter: number;
} {
  const tau = Math.PI * 2;
  for (const candidate of tangentCircles(
    first,
    second,
    radius,
    firstPick,
    secondPick,
  )) {
    const lowerA = firstPick < candidate.firstParameter,
      lowerB = secondPick < candidate.secondParameter;
    let a = portion(first, candidate.firstParameter, lowerA),
      b = portion(second, candidate.secondParameter, lowerB);
    if (!a || !b) continue;
    if (!lowerA) a = reverse(a);
    if (lowerB) b = reverse(b);
    const incoming = curveJet(a)(1).first,
      outgoing = curveJet(b)(0).first;
    const p = a.segment.end,
      q = b.start,
      center = candidate.center;
    const angle = Math.atan2(p[1] - center[1], p[0] - center[0]),
      endAngle = Math.atan2(q[1] - center[1], q[0] - center[0]);
    const direction =
      -(p[1] - center[1]) * incoming[0] + (p[0] - center[0]) * incoming[1] >= 0
        ? 1
        : -1;
    const tangent: SketchPoint = [
      -direction * (q[1] - center[1]),
      direction * (q[0] - center[0]),
    ];
    if (
      (tangent[0] * outgoing[0] + tangent[1] * outgoing[1]) /
        (Math.hypot(...tangent) * Math.hypot(...outgoing)) <
      1 - 1e-6
    )
      continue;
    const sweep =
      direction * ((((direction * (endAngle - angle)) % tau) + tau) % tau);
    if (Math.abs(sweep) < 1e-7) continue;
    const middle: SketchPoint = [
      center[0] + radius * Math.cos(angle + sweep / 2),
      center[1] + radius * Math.sin(angle + sweep / 2),
    ];
    return {
      start: [...a.start],
      segments: [
        structuredClone(a.segment),
        { type: "arc", middle, end: [...q] },
        structuredClone(b.segment),
      ],
      firstParameter: candidate.firstParameter,
      secondParameter: candidate.secondParameter,
    };
  }
  throw new Error(
    "No finite tangent fillet fits the selected curve sides and radius.",
  );
}
