import { sketchArcGeometry } from "./arc-geometry";
import type { SketchContour, SketchDrawing, SketchPoint } from "./drawing";

/** Samples sketch geometry into mm polylines for renderer-neutral display
 * (the viewport draws finished sketches from these; no solver semantics). */

const TAU = Math.PI * 2;

function ellipsePoints(
  start: SketchPoint,
  segment: { end: SketchPoint; radiusX: number; radiusY: number; rotationDegrees: number; largeArc: boolean; sweep: boolean },
  steps: number,
): SketchPoint[] {
  // SVG endpoint parameterization (F.6.5) → center form, then uniform sweep.
  const phi = (segment.rotationDegrees * Math.PI) / 180;
  const cos = Math.cos(phi), sin = Math.sin(phi);
  let rx = Math.abs(segment.radiusX), ry = Math.abs(segment.radiusY);
  if (!rx || !ry) return [segment.end];
  const dx = (start[0] - segment.end[0]) / 2, dy = (start[1] - segment.end[1]) / 2;
  const x1 = cos * dx + sin * dy, y1 = -sin * dx + cos * dy;
  const lambda = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry);
  if (lambda > 1) { const scale = Math.sqrt(lambda); rx *= scale; ry *= scale; }
  const sign = segment.largeArc !== segment.sweep ? 1 : -1;
  const numerator = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1;
  const denominator = rx * rx * y1 * y1 + ry * ry * x1 * x1;
  const factor = sign * Math.sqrt(Math.max(0, numerator / denominator));
  const cxp = (factor * rx * y1) / ry, cyp = (-factor * ry * x1) / rx;
  const cx = cos * cxp - sin * cyp + (start[0] + segment.end[0]) / 2;
  const cy = sin * cxp + cos * cyp + (start[1] + segment.end[1]) / 2;
  const theta = (px: number, py: number) => Math.atan2(py / ry, px / rx);
  const start_theta = theta(x1 - cxp, y1 - cyp);
  const end_theta = theta(-x1 - cxp, -y1 - cyp);
  let sweep = end_theta - start_theta;
  if (segment.sweep && sweep < 0) sweep += TAU;
  if (!segment.sweep && sweep > 0) sweep -= TAU;
  const points: SketchPoint[] = [];
  for (let index = 1; index <= steps; index += 1) {
    const t = start_theta + (sweep * index) / steps;
    const ex = rx * Math.cos(t), ey = ry * Math.sin(t);
    points.push([cos * ex - sin * ey + cx, sin * ex + cos * ey + cy]);
  }
  points[points.length - 1] = segment.end;
  return points;
}

export function sketchContourPolyline(contour: SketchContour, arcSteps = 24): SketchPoint[] {
  if (contour.type === "circle") {
    const points: SketchPoint[] = [];
    for (let index = 0; index <= 48; index += 1) {
      const t = (TAU * index) / 48;
      points.push([
        contour.center[0] + contour.radius * Math.cos(t),
        contour.center[1] + contour.radius * Math.sin(t),
      ]);
    }
    return points;
  }
  const points: SketchPoint[] = [contour.start];
  let previous: SketchPoint = contour.start;
  for (const segment of contour.segments) {
    if (segment.type === "line") points.push(segment.end);
    else if (segment.type === "arc") {
      const geometry = sketchArcGeometry(previous, segment.middle, segment.end);
      for (let index = 1; index <= arcSteps; index += 1) {
        const t = geometry.startAngle + (geometry.sweep * index) / arcSteps;
        points.push([
          geometry.center[0] + geometry.radius * Math.cos(t),
          geometry.center[1] + geometry.radius * Math.sin(t),
        ]);
      }
      points[points.length - 1] = segment.end;
    } else if (segment.type === "bezier") {
      const [c1, c2] = segment.controls;
      for (let index = 1; index <= 16; index += 1) {
        const t = index / 16, s = 1 - t;
        points.push([
          s * s * s * previous[0] + 3 * s * s * t * c1[0] + 3 * s * t * t * c2[0] + t * t * t * segment.end[0],
          s * s * s * previous[1] + 3 * s * s * t * c1[1] + 3 * s * t * t * c2[1] + t * t * t * segment.end[1],
        ]);
      }
    } else {
      points.push(...ellipsePoints(previous, segment, arcSteps));
    }
    previous = segment.end;
  }
  return points;
}

export function sketchDrawingPolylines(
  drawing: SketchDrawing,
  options: { includeConstruction?: boolean; arcSteps?: number } = {},
): SketchPoint[][] {
  return drawing.contours
    .filter((contour) => options.includeConstruction || !contour.construction)
    .map((contour) => sketchContourPolyline(contour, options.arcSteps));
}

/** Polylines for any persisted sketch profile shape (drawing/circle/polygon). */
export function sketchProfilePolylines(profile: unknown): SketchPoint[][] {
  if (!profile || typeof profile !== "object") return [];
  const shape = profile as { type?: string };
  if (shape.type === "drawing") return sketchDrawingPolylines(profile as SketchDrawing);
  if (shape.type === "circle") {
    const circle = profile as { centerMillimeters?: [number, number]; radiusMillimeters?: number };
    if (!circle.centerMillimeters || !circle.radiusMillimeters) return [];
    return [sketchContourPolyline({ type: "circle", center: circle.centerMillimeters, radius: circle.radiusMillimeters })];
  }
  if (shape.type === "polygon") {
    const polygon = profile as { pointsMillimeters?: [number, number][] };
    if (!polygon.pointsMillimeters?.length) return [];
    return [[...polygon.pointsMillimeters, polygon.pointsMillimeters[0]]];
  }
  return [];
}
