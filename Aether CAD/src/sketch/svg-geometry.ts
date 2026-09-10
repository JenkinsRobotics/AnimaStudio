import type { SketchPoint, SketchContour } from "@aether/core/sketch";
export function arcPath(a: SketchPoint, m: SketchPoint, b: SketchPoint) {
  const d =
    2 * (a[0] * (m[1] - b[1]) + m[0] * (b[1] - a[1]) + b[0] * (a[1] - m[1]));
  if (Math.abs(d) < 1e-8) return `L${b}`;
  const sq = (p: SketchPoint) => p[0] * p[0] + p[1] * p[1];
  const cx =
    (sq(a) * (m[1] - b[1]) + sq(m) * (b[1] - a[1]) + sq(b) * (a[1] - m[1])) / d;
  const cy =
    (sq(a) * (b[0] - m[0]) + sq(m) * (a[0] - b[0]) + sq(b) * (m[0] - a[0])) / d;
  const angle = (p: SketchPoint) => Math.atan2(p[1] - cy, p[0] - cx);
  const tau = 2 * Math.PI,
    delta = (u: number, v: number) => (v - u + tau) % tau;
  const sweep = delta(angle(a), angle(m)) < delta(angle(a), angle(b));
  const extent = sweep ? delta(angle(a), angle(b)) : delta(angle(b), angle(a));
  return `A${Math.hypot(a[0] - cx, a[1] - cy)} ${Math.hypot(a[0] - cx, a[1] - cy)} 0 ${extent > Math.PI ? 1 : 0} ${sweep ? 1 : 0} ${b}`;
}
export function contourPath(c: Extract<SketchContour, { type: "path" }>) {
  let a = c.start,
    d = `M${a[0]},${-a[1]}`;
  for (const seg of c.segments) {
    const end: SketchPoint = [seg.end[0], -seg.end[1]];
    d +=
      seg.type === "line"
        ? `L${end}`
        : seg.type === "bezier"
          ? `C${seg.controls.map((p) => [p[0], -p[1]].join(",")).join(" ")} ${end}`
          : seg.type === "ellipse"
            ? `A${seg.radiusX} ${seg.radiusY} ${-seg.rotationDegrees} ${seg.largeArc ? 1 : 0} ${seg.sweep ? 0 : 1} ${end}`
            : arcPath([a[0], -a[1]], [seg.middle[0], -seg.middle[1]], end);
    a = seg.end;
  }
  return d;
}
