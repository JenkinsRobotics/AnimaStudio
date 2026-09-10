import type { SketchContour, SketchPoint } from "../drawing";
/** A planar similarity transform, with translation expressed in millimeters. */
export interface SketchTransform {
  a: number;
  b: number;
  c: number;
  d: number;
  tx: number;
  ty: number;
}
export function transformPoint(
  p: SketchPoint,
  t: SketchTransform,
): SketchPoint {
  return [t.a * p[0] + t.b * p[1] + t.tx, t.c * p[0] + t.d * p[1] + t.ty];
}
export function transformContour(
  source: SketchContour,
  t: SketchTransform,
): SketchContour {
  const scale = Math.hypot(t.a, t.c),
    det = t.a * t.d - t.b * t.c;
  if (
    !Object.values(t).every(Number.isFinite) ||
    scale < 1e-10 ||
    Math.abs(Math.hypot(t.b, t.d) - scale) > 1e-8 ||
    Math.abs(t.a * t.b + t.c * t.d) > 1e-8
  )
    throw new Error(
      "Sketch transforms require a finite, uniform, nonzero scale.",
    );
  const contour = structuredClone(source);
  if (contour.type === "circle") {
    contour.center = transformPoint(contour.center, t);
    contour.radius *= scale;
  } else {
    contour.start = transformPoint(contour.start, t);
    for (const segment of contour.segments) {
      segment.end = transformPoint(segment.end, t);
      if (segment.type === "arc")
        segment.middle = transformPoint(segment.middle, t);
      if (segment.type === "bezier")
        segment.controls = segment.controls.map((p) =>
          transformPoint(p, t),
        ) as [SketchPoint, SketchPoint];
      if (segment.type === "ellipse") {
        const angle = (segment.rotationDegrees * Math.PI) / 180,
          x = Math.cos(angle),
          y = Math.sin(angle);
        segment.rotationDegrees =
          (Math.atan2(t.c * x + t.d * y, t.a * x + t.b * y) * 180) / Math.PI;
        segment.radiusX *= scale;
        segment.radiusY *= scale;
        if (det < 0) segment.sweep = !segment.sweep;
      }
    }
  }
  return contour;
}
export function similarityTransform(
  origin: SketchPoint,
  translation: SketchPoint,
  angleDegrees: number,
  scale = 1,
): SketchTransform {
  if (
    ![...origin, ...translation, angleDegrees, scale].every(Number.isFinite) ||
    scale <= 0
  )
    throw new Error("Enter finite coordinates and a positive scale.");
  const angle = (angleDegrees * Math.PI) / 180,
    a = scale * Math.cos(angle),
    b = -scale * Math.sin(angle),
    c = -b,
    d = a;
  return {
    a,
    b,
    c,
    d,
    tx: origin[0] + translation[0] - a * origin[0] - b * origin[1],
    ty: origin[1] + translation[1] - c * origin[0] - d * origin[1],
  };
}
