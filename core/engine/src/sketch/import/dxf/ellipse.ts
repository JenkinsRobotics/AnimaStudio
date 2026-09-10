import type { SketchContour, SketchPoint, SketchSegment } from "../../drawing";
import { numberTag, type DxfTag } from "./tags";
/** DXF parameters are radians in the ellipse frame, not polar angles. */
export function dxfEllipse(
  tags: DxfTag[],
  scale: number,
  normalSign = 1,
): SketchContour {
  const n = (code: number) => numberTag(tags, code),
    cx = n(10) * scale,
    cy = n(20) * scale,
    dx = n(11) * scale,
    dy = n(21) * scale;
  const rx = Math.hypot(dx, dy),
    ratio = n(40),
    ry = rx * ratio,
    rotation = Math.atan2(dy, dx),
    tau = 2 * Math.PI;
  if (rx <= 0 || ratio <= 0 || ratio > 1)
    throw Error("DXF ellipse needs a nonzero major axis and a ratio in (0,1].");
  const start = n(41),
    end = n(42),
    delta = end - start;
  if (start < 0 || start > tau + 1e-10 || end < 0 || end > tau + 1e-10)
    throw Error("DXF ellipse parameters must be between zero and 2π.");
  const full = Math.abs(delta - tau) < 1e-10,
    sweep = full ? tau : ((delta % tau) + tau) % tau;
  if (sweep < 1e-10) throw Error("DXF ellipse has zero sweep.");
  const at = (a: number): SketchPoint => [
    cx +
      rx * Math.cos(a) * Math.cos(rotation) -
      normalSign * ry * Math.sin(a) * Math.sin(rotation),
    cy +
      rx * Math.cos(a) * Math.sin(rotation) +
      normalSign * ry * Math.sin(a) * Math.cos(rotation),
  ];
  const segment = (a: number, span: number): SketchSegment => ({
    type: "ellipse",
    end: at(a),
    radiusX: rx,
    radiusY: ry,
    rotationDegrees: (rotation * 180) / Math.PI,
    largeArc: span > Math.PI,
    sweep: normalSign > 0,
  });
  return {
    type: "path",
    start: at(start),
    segments: full
      ? [
          segment(start + Math.PI, Math.PI),
          { ...segment(start + tau, Math.PI), end: at(start) },
        ]
      : [segment(start + sweep, sweep)],
  };
}
