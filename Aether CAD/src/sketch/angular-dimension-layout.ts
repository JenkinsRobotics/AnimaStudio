import type { SketchPoint } from "@aether/core/sketch";

/** Layout only: Core supplies the solved line endpoints and dimensional value.
 * Extend supporting lines to their intersection to locate the angle leader. */
export function angularDimensionLayout(
  a: [SketchPoint, SketchPoint],
  b: [SketchPoint, SketchPoint],
  radius: number,
) {
  const u: SketchPoint = [a[1][0] - a[0][0], a[1][1] - a[0][1]],
    v: SketchPoint = [b[1][0] - b[0][0], b[1][1] - b[0][1]];
  const lu = Math.hypot(...u),
    lv = Math.hypot(...v);
  if (lu < 1e-10 || lv < 1e-10)
    throw Error("Cannot annotate a zero-length line.");
  const cross = u[0] * v[1] - u[1] * v[0],
    dot = u[0] * v[0] + u[1] * v[1];
  let center: SketchPoint = [...a[0]];
  if (Math.abs(cross) / (lu * lv) > 1e-8) {
    const dx = b[0][0] - a[0][0],
      dy = b[0][1] - a[0][1],
      t = (dx * v[1] - dy * v[0]) / cross;
    center = [a[0][0] + t * u[0], a[0][1] + t * u[1]];
  }
  const startAngle = Math.atan2(u[1], u[0]),
    sweep = Math.atan2(cross, dot);
  const at = (angle: number, r = radius): SketchPoint => [
    center[0] + r * Math.cos(angle),
    center[1] + r * Math.sin(angle),
  ];
  const start = at(startAngle),
    end = at(startAngle + sweep),
    label = at(startAngle + sweep / 2, radius * 1.3);
  return {
    center,
    startAngle,
    sweep,
    start,
    end,
    label,
    path: `M ${start[0]} ${-start[1]} A ${radius} ${radius} 0 0 ${sweep >= 0 ? 0 : 1} ${end[0]} ${-end[1]}`,
  };
}
