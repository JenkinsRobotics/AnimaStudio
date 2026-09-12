import type { SketchPoint, SketchSegment } from "../drawing";
import type { SketchFrameMap } from "./frame-map";
/** Principal axes of the projected conic via its 2x2 shape matrix. The
 * determinant form for the minor radius avoids cancellation near edge-on. */
export function projectedEllipse(
  map: SketchFrameMap,
  rx: number,
  ry: number,
  rotation: number,
) {
  const c = Math.cos(rotation),
    s = Math.sin(rotation),
    u = map.vector([rx * c, rx * s]),
    v = map.vector([-ry * s, ry * c]);
  // Normalize before squaring to avoid overflowing/underflowing the shape matrix.
  const scale = Math.max(...u.map(Math.abs), ...v.map(Math.abs));
  if (!Number.isFinite(scale) || scale === 0)
    throw Error("Conic mapping has no finite nonzero extent.");
  const ux = u[0] / scale,
    uy = u[1] / scale,
    vx = v[0] / scale,
    vy = v[1] / scale;
  const xx = ux * ux + vx * vx,
    xy = ux * uy + vx * vy,
    yy = uy * uy + vy * vy;
  const major = Math.sqrt((xx + yy + Math.hypot(xx - yy, 2 * xy)) / 2);
  const radiusX = major * scale;
  // det(A R diag(rx,ry)) = det(A) rx ry; avoid subtracting nearly equal products.
  const radiusY =
    (Math.abs(map.determinant * (rx / scale) * (ry / scale)) / major) * scale;
  if (!Number.isFinite(radiusX) || !Number.isFinite(radiusY) || radiusY < 1e-8)
    throw Error("Mapped conic is below the supported geometric resolution.");
  const rotationDegrees = (Math.atan2(2 * xy, xx - yy) * 90) / Math.PI;
  return { radiusX, radiusY, rotationDegrees };
}
export function projectedConicSegment(
  map: SketchFrameMap,
  axes: ReturnType<typeof projectedEllipse>,
  end: SketchPoint,
  sweep: number,
): SketchSegment {
  return {
    type: "ellipse",
    ...axes,
    end: map.point(end),
    largeArc: Math.abs(sweep) > Math.PI,
    sweep: sweep * map.determinant > 0,
  };
}
