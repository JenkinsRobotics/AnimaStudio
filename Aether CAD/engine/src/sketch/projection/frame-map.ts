import type { SketchFrame, SketchPoint } from "../drawing";
type Vector = [number, number, number];
const dot = (a: Vector, b: Vector) => a.reduce((s, v, i) => s + v * b[i], 0);
const cross = (a: Vector, b: Vector): Vector => [
  a[1] * b[2] - a[2] * b[1],
  a[2] * b[0] - a[0] * b[2],
  a[0] * b[1] - a[1] * b[0],
];
function basis(frame: SketchFrame) {
  const { originMillimeters: o, xDirection: x, normal: n } = frame;
  if (
    ![o, x, n].every(
      (v) => Array.isArray(v) && v.length === 3 && v.every(Number.isFinite),
    ) ||
    Math.abs(Math.hypot(...x) - 1) > 1e-6 ||
    Math.abs(Math.hypot(...n) - 1) > 1e-6 ||
    Math.abs(dot(x, n)) > 1e-6
  )
    throw Error("Projection needs valid orthonormal sketch frames.");
  return { o, x, y: cross(n, x) };
}
/** Orthogonal projection along the target plane normal, expressed in target
 * sketch coordinates. Frame origins and points are millimeters. */
export function sketchFrameMap(source: SketchFrame, target: SketchFrame) {
  const a = basis(source),
    b = basis(target),
    delta = a.o.map((v, i) => v - b.o[i]) as Vector;
  const m = [
    dot(a.x, b.x),
    dot(a.y, b.x),
    dot(a.x, b.y),
    dot(a.y, b.y),
  ] as const;
  const offset: SketchPoint = [dot(delta, b.x), dot(delta, b.y)];
  const vector = (p: SketchPoint): SketchPoint => [
    m[0] * p[0] + m[1] * p[1],
    m[2] * p[0] + m[3] * p[1],
  ];
  return {
    determinant: m[0] * m[3] - m[1] * m[2],
    vector,
    point(p: SketchPoint): SketchPoint {
      const v = vector(p);
      return [v[0] + offset[0], v[1] + offset[1]];
    },
  };
}
export type SketchFrameMap = ReturnType<typeof sketchFrameMap>;
