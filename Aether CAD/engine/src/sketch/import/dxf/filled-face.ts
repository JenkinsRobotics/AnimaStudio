import type { SketchContour, SketchPoint } from "../../drawing";
import { numberTag, type DxfTag } from "./tags";

/** SOLID/TRACE store the last two quadrilateral corners in strip order.
 * Emit the boundary 0,1,3,2; a repeated third/fourth corner denotes a triangle. */
export function dxfFilledFace(tags: DxfTag[], scale: number): SketchContour {
  const points = [10, 11, 13, 12].map((code): SketchPoint => [
    numberTag(tags, code) * scale,
    numberTag(tags, code + 10) * scale,
  ]);
  if (points[2][0] === points[3][0] && points[2][1] === points[3][1])
    points.pop();
  const cross = (a: SketchPoint, b: SketchPoint, c: SketchPoint) =>
    (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]);
  let area = 0;
  for (let i = 0; i < points.length; i++) {
    const a = points[i],
      b = points[(i + 1) % points.length];
    if (Math.hypot(b[0] - a[0], b[1] - a[1]) < 1e-10)
      throw Error("DXF filled face has a degenerate boundary.");
    area += cross(points[0], a, b);
    for (let j = i + 2; j < points.length; j++) {
      if (i === 0 && j === points.length - 1) continue;
      const c = points[j],
        d = points[(j + 1) % points.length];
      if (
        cross(a, b, c) * cross(a, b, d) <= 0 &&
        cross(c, d, a) * cross(c, d, b) <= 0
      )
        throw Error("DXF filled face has a crossing boundary.");
    }
  }
  if (Math.abs(area) < 1e-12) throw Error("DXF filled face has zero area.");
  return {
    type: "path",
    start: points[0],
    segments: points.map((_, i) => ({
      type: "line",
      end: points[(i + 1) % points.length],
    })),
  };
}
