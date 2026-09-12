import { ellipticalArcContour } from "./elliptical-arc";
import type { SketchContour, SketchPoint } from "./drawing";

export const sketchVariantTools = [
  "point",
  "ellipse",
  "elliptical-arc",
  "cubic-bezier",
  "midpoint-line",
  "center-rectangle",
  "aligned-rectangle",
  "three-point-circle",
  "center-arc",
  "inscribed-polygon",
  "circumscribed-polygon",
] as const;
export type SketchVariantTool = (typeof sketchVariantTools)[number];
export const sketchVariantPointCounts: Record<SketchVariantTool, number> = {
  point: 1,
  ellipse: 3,
  "elliptical-arc": 4,
  "cubic-bezier": 4,
  "midpoint-line": 2,
  "center-rectangle": 2,
  "aligned-rectangle": 3,
  "three-point-circle": 3,
  "center-arc": 3,
  "inscribed-polygon": 2,
  "circumscribed-polygon": 2,
};
/** The same exact geometry supplies both pointer previews and committed contours. Units: mm. */
export function sketchVariantContour(
  tool: SketchVariantTool,
  points: SketchPoint[],
  sides = 6,
  options: {
    clockwise?: boolean;
    secondaryRadiusMillimeters?: number;
    rememberedRadiusMillimeters?: number;
  } = {},
): SketchContour {
  if (
    points.length !== sketchVariantPointCounts[tool] ||
    !points.every((p) => p.length === 2 && p.every(Number.isFinite))
  )
    throw new Error("Select the required finite points.");
  if (tool === "elliptical-arc")
    return ellipticalArcContour(
      points,
      options.clockwise,
      options.secondaryRadiusMillimeters,
      options.rememberedRadiusMillimeters,
    );
  if (tool === "point")
    return { type: "path", start: [...points[0]], segments: [] };
  const [a, b, c] = points,
    dx = b[0] - a[0],
    dy = b[1] - a[1],
    length = Math.hypot(dx, dy);
  if (length < 1e-8) throw new Error("Choose distinct points.");
  const path = (vertices: SketchPoint[], closed = true): SketchContour => ({
    type: "path",
    start: vertices[0],
    segments: [...vertices.slice(1), ...(closed ? [vertices[0]] : [])].map(
      (end) => ({ type: "line", end: [...end] }),
    ),
  });
  if (tool === "cubic-bezier")
    return {
      type: "path",
      start: a,
      segments: [{ type: "bezier", controls: [b, c], end: points[3] }],
    };
  if (tool === "ellipse") {
    const radiusY = Math.abs(
      ((c[0] - a[0]) * -dy + (c[1] - a[1]) * dx) / length,
    );
    if (radiusY < 1e-8)
      throw new Error("Ellipse needs a nonzero minor radius.");
    const opposite: SketchPoint = [a[0] - dx, a[1] - dy];
    const ellipse = {
      type: "ellipse" as const,
      radiusX: length,
      radiusY,
      rotationDegrees: (Math.atan2(dy, dx) * 180) / Math.PI,
      largeArc: false,
      sweep: true,
    };
    return {
      type: "path",
      start: b,
      segments: [
        { ...ellipse, end: opposite },
        { ...ellipse, end: b },
      ],
    };
  }
  if (tool === "midpoint-line")
    return path([[2 * a[0] - b[0], 2 * a[1] - b[1]], b], false);
  if (tool === "center-rectangle") {
    if (Math.abs(dx * dy) < 1e-10)
      throw new Error("Rectangle needs width and height.");
    return path([
      [a[0] - dx, a[1] - dy],
      [b[0], a[1] - dy],
      b,
      [a[0] - dx, b[1]],
    ]);
  }
  if (tool === "aligned-rectangle") {
    const height = ((c[0] - a[0]) * -dy + (c[1] - a[1]) * dx) / length;
    if (Math.abs(height) < 1e-8)
      throw new Error("Choose a point away from the first edge.");
    const offset: SketchPoint = [
      (-dy / length) * height,
      (dx / length) * height,
    ];
    return path([
      a,
      b,
      [b[0] + offset[0], b[1] + offset[1]],
      [a[0] + offset[0], a[1] + offset[1]],
    ]);
  }
  if (tool === "three-point-circle") {
    const ux = c[0] - a[0],
      uy = c[1] - a[1],
      det = 2 * (dx * uy - dy * ux);
    if (Math.abs(det) < 1e-10)
      throw new Error("Circle points must not be collinear.");
    const q = dx * dx + dy * dy,
      r = ux * ux + uy * uy;
    const center: SketchPoint = [
      a[0] + (q * uy - r * dy) / det,
      a[1] + (dx * r - ux * q) / det,
    ];
    return {
      type: "circle",
      center,
      radius: Math.hypot(center[0] - a[0], center[1] - a[1]),
    };
  }
  if (tool === "center-arc") {
    if (Math.hypot(c[0] - a[0], c[1] - a[1]) < 1e-8)
      throw new Error("Choose an end direction away from the center.");
    const start = Math.atan2(dy, dx),
      end = Math.atan2(c[1] - a[1], c[0] - a[0]);
    const positiveSweep = (end - start + 2 * Math.PI) % (2 * Math.PI);
    const sweep = options.clockwise
      ? positiveSweep - 2 * Math.PI
      : positiveSweep;
    if (positiveSweep < 1e-8 || 2 * Math.PI - positiveSweep < 1e-8)
      throw new Error("Arc endpoints must differ.");
    const at = (angle: number): SketchPoint => [
      a[0] + length * Math.cos(angle),
      a[1] + length * Math.sin(angle),
    ];
    return {
      type: "path",
      start: b,
      segments: [{ type: "arc", middle: at(start + sweep / 2), end: at(end) }],
    };
  }
  if (!Number.isInteger(sides) || sides < 3 || sides > 100)
    throw new Error("Polygon sides must be an integer from 3 to 100.");
  const circumscribed = tool === "circumscribed-polygon";
  const radius = circumscribed ? length / Math.cos(Math.PI / sides) : length;
  const angle = Math.atan2(dy, dx) - (circumscribed ? Math.PI / sides : 0);
  return path(
    Array.from({ length: sides }, (_, i) => [
      a[0] + radius * Math.cos(angle + (i * 2 * Math.PI) / sides),
      a[1] + radius * Math.sin(angle + (i * 2 * Math.PI) / sides),
    ]),
  );
}
