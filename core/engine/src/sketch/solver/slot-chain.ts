import type { SketchContour } from "../drawing";
import { curveJet } from "../curves/derivatives";
import { sketchArcGeometry } from "../arc-geometry";
import { mixedOffsetResiduals } from "./offset-mixed";
type Path = Extract<SketchContour, { type: "path" }>;
/** Tangent/collinear chains keep shared boundary vertices. Locus equations avoid
 * generating microscopic corner arcs during solver finite differences. */
export function smoothSlotResiduals(
  source: Path,
  target: Path,
  width: number,
): number[] {
  const n = source.segments.length,
    p = [target.start, ...target.segments.map((s) => s.end)];
  if (target.segments.length !== 2 * n + 2)
    throw Error("Slot topology changed.");
  const left: Path = {
    type: "path",
    start: target.start,
    segments: target.segments.slice(0, n),
  };
  const right: Path = { type: "path", start: p[2 * n + 1], segments: [] };
  for (let i = 2 * n; i >= n + 1; i--)
    right.segments.push({ ...target.segments[i], end: p[i] });
  const result = [
    ...mixedOffsetResiduals(source, left, width / 2),
    ...mixedOffsetResiduals(source, right, -width / 2),
  ];
  const sp = [source.start, ...source.segments.map((s) => s.end)];
  for (let i = 0; i < n - 1; i++) {
    const a = curveJet({ start: sp[i], segment: source.segments[i] })(1).first;
    const b = curveJet({ start: sp[i + 1], segment: source.segments[i + 1] })(
      0,
    ).first;
    result.push(
      Math.atan2(a[0] * b[1] - a[1] * b[0], a[0] * b[0] + a[1] * b[1]),
    );
  }
  for (const [index, center] of [
    [n, source.segments.at(-1)!.end],
    [2 * n + 1, source.start],
  ] as const) {
    const s = target.segments[index];
    if (s.type !== "arc") throw Error("Slot cap must remain an arc.");
    const arc = sketchArcGeometry(p[index], s.middle, s.end);
    result.push(
      arc.center[0] - center[0],
      arc.center[1] - center[1],
      arc.radius - width / 2,
      arc.sweep + Math.PI,
    );
  }
  return result;
}
