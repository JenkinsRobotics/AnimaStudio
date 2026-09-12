import { dxfFilledFace } from "./filled-face";
import { dxfCoordinates } from "./coordinates";
import { dxfSpline } from "./spline";
import { dxfEllipse } from "./ellipse";
import type { SketchContour, SketchPoint, SketchSegment } from "../../drawing";
import { numberTag, type DxfTag } from "./tags";
export function dxfEntity(
  type: string,
  tags: DxfTag[],
  scale: number,
): SketchContour {
  const coordinates = dxfCoordinates(type, tags);
  return coordinates.toWorld(
    decodeDxfEntity(type, tags, scale, coordinates.normalSign),
  );
}
function decodeDxfEntity(
  type: string,
  tags: DxfTag[],
  scale: number,
  normalSign: number,
): SketchContour {
  const n = (code: number, fallback?: number) =>
    numberTag(tags, code, fallback);
  const point = (x: number, y: number): SketchPoint => [x * scale, y * scale];
  const xy = (code = 10) => point(n(code), n(code + 10));
  if (type === "SOLID" || type === "TRACE") return dxfFilledFace(tags, scale);
  if (type === "SPLINE") return dxfSpline(tags, scale);
  if (type === "ELLIPSE") return dxfEllipse(tags, scale, normalSign);
  if (type === "LINE")
    return {
      type: "path",
      start: xy(),
      segments: [{ type: "line", end: xy(11) }],
    };
  if (type === "POINT") return { type: "path", start: xy(), segments: [] };
  if (type === "CIRCLE" || type === "ARC") {
    const center = xy(),
      radius = n(40) * scale;
    if (radius <= 0) throw Error("DXF radius must be positive.");
    if (type === "CIRCLE") return { type: "circle", center, radius };
    const start = (n(50) * Math.PI) / 180,
      end = (n(51) * Math.PI) / 180,
      tau = 2 * Math.PI,
      sweep = (((end - start) % tau) + tau) % tau;
    if (sweep < 1e-10) throw Error("DXF arc has zero sweep.");
    const at = (a: number): SketchPoint => [
      center[0] + radius * Math.cos(a),
      center[1] + radius * Math.sin(a),
    ];
    return {
      type: "path",
      start: at(start),
      segments: [
        { type: "arc", middle: at(start + sweep / 2), end: at(start + sweep) },
      ],
    };
  }
  if (type === "LWPOLYLINE") {
    if (
      tags.some((t) => [40, 41, 43].includes(t.code) && Number(t.value) !== 0)
    )
      throw Error(
        "Wide DXF polylines need outline conversion before importing.",
      );
    const vertices: { point: SketchPoint; bulge: number }[] = [];
    for (let i = 0; i < tags.length; i++)
      if (tags[i].code === 10) {
        let end = i + 1;
        while (end < tags.length && tags[end].code !== 10) end++;
        const part = tags.slice(i, end);
        vertices.push({
          point: point(numberTag(part, 10), numberTag(part, 20)),
          bulge: numberTag(part, 42, 0),
        });
        i = end - 1;
      }
    if (vertices.length !== n(90) || vertices.length < 2)
      throw Error("DXF polyline vertex count is invalid.");
    const closed = (n(70, 0) & 1) !== 0,
      segments: SketchSegment[] = [];
    for (let i = 0; i < vertices.length - (closed ? 0 : 1); i++) {
      const a = vertices[i],
        b = vertices[(i + 1) % vertices.length],
        dx = b.point[0] - a.point[0],
        dy = b.point[1] - a.point[1];
      if (Math.hypot(dx, dy) < 1e-10)
        throw Error("DXF polyline contains a zero-length edge.");
      if (Math.abs(a.bulge) < 1e-12)
        segments.push({ type: "line", end: b.point });
      else
        segments.push({
          type: "arc",
          middle: [
            (a.point[0] + b.point[0]) / 2 + (dy * a.bulge) / 2,
            (a.point[1] + b.point[1]) / 2 - (dx * a.bulge) / 2,
          ],
          end: b.point,
        });
    }
    return { type: "path", start: vertices[0].point, segments };
  }
  throw Error(
    `DXF entity ${type} is not supported yet. No geometry was imported.`,
  );
}
