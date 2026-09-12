import type { resolve } from "./entities";
type Ellipse = NonNullable<ReturnType<typeof resolve>["ellipse"]>;
/** Compare the supporting conic, independent of axis swapping or circle rotation. */
export function ellipseLocusResiduals(a: Ellipse, b: Ellipse): number[] {
  const scale = Math.max(a.radiusX, a.radiusY, b.radiusX, b.radiusY, 1e-8);
  const matrix = (e: Ellipse) => {
    const c = Math.cos(e.rotation),
      s = Math.sin(e.rotation),
      x = e.radiusX / scale,
      y = e.radiusY / scale;
    return [
      x * x * c * c + y * y * s * s,
      (x * x - y * y) * c * s,
      x * x * s * s + y * y * c * c,
    ];
  };
  const x = matrix(a),
    y = matrix(b);
  return [
    a.center[0] - b.center[0],
    a.center[1] - b.center[1],
    ...x.map((v, i) => (v - y[i]) * scale),
  ];
}
