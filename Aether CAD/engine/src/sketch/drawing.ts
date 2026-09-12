import { validateTextItems, type SketchTextItem } from "./text/records";
import { validatePatternGroups } from "./pattern-groups";
import {
  solveDrawingConstraints,
  type DrawingConstraint,
} from "./drawing-constraints";
/** Persisted freeform sketch geometry. All coordinates are millimeters. */
export type SketchPoint = [number, number];
export type SketchSegment = { id?: string; endVertexId?: string } & (
  | {
      type: "ellipse";
      end: SketchPoint;
      radiusX: number;
      radiusY: number;
      rotationDegrees: number;
      largeArc: boolean;
      sweep: boolean;
    }
  | { type: "bezier"; end: SketchPoint; controls: [SketchPoint, SketchPoint] }
  | { type: "line"; end: SketchPoint }
  | { type: "arc"; middle: SketchPoint; end: SketchPoint }
);
/** Source layer provenance; does not control visibility or solver behavior. */
export type SketchContour = { sourceLayer?: string } & (
  | {
      type: "circle";
      /** Stable identity within an authored sketch, assigned when externally referenced. */
      id?: string;
      center: SketchPoint;
      radius: number;
      hole?: boolean;
      construction?: boolean;
    }
  | {
      type: "path";
      id?: string;
      start: SketchPoint;
      startVertexId?: string;
      segments: SketchSegment[];
      hole?: boolean;
      construction?: boolean;
    }
);
export interface SketchDrawing {
  type: "drawing";
  contours: SketchContour[];
  constraints?: DrawingConstraint[];
  /** Resolved read-only editor context. Never persisted in a Part document. */
  projectionContext?: SketchContour[];
  textItems?: SketchTextItem[];
  patternGroups?: Record<string, import("./pattern-groups").SketchPatternGroup>;
}
export interface SketchFrame {
  originMillimeters: [number, number, number];
  xDirection: [number, number, number];
  normal: [number, number, number];
}
export const sameSketchPoint = (a: SketchPoint, b: SketchPoint) =>
  Math.hypot(a[0] - b[0], a[1] - b[1]) < 1e-6;
export function contourClosed(c: SketchContour): boolean {
  return (
    c.type === "circle" ||
    (c.segments.length > 0 && sameSketchPoint(c.start, c.segments.at(-1)!.end))
  );
}
export function validateSketchDrawing(input: SketchDrawing) {
  validatePatternGroups(input);
  validateTextItems(input);
  const d = solveDrawingConstraints(input);
  if (!Array.isArray(d.contours) || d.contours.length > 1000)
    throw new Error("Invalid sketch contours.");
  const point = (p: SketchPoint) => {
    if (!Array.isArray(p) || p.length !== 2 || !p.every(Number.isFinite))
      throw new Error("Sketch coordinates must be finite.");
  };
  const ids = new Set<string>();
  for (const c of d.contours) {
    if (
      c.sourceLayer !== undefined &&
      (typeof c.sourceLayer !== "string" ||
        !c.sourceLayer.length ||
        c.sourceLayer.length > 255)
    )
      throw Error(
        "Source layer must be a nonempty name of at most 255 characters.",
      );
    if (c.id !== undefined) {
      if (
        typeof c.id !== "string" ||
        !c.id.trim() ||
        c.id.length > 128 ||
        ids.has(c.id)
      )
        throw Error(
          "Sketch contour identities must be unique nonempty strings.",
        );
      ids.add(c.id);
    }
    if (c.construction !== undefined && typeof c.construction !== "boolean")
      throw new Error("Construction flag must be boolean.");
    if (c.type === "circle") {
      point(c.center);
      if (!Number.isFinite(c.radius) || c.radius <= 0)
        throw new Error("Circle radius must be positive.");
    } else if (c.type === "path") {
      point(c.start);
      if (!Array.isArray(c.segments) || c.segments.length > 1000)
        throw new Error("Invalid sketch path.");
      const vertexIds = new Set<string>();
      const vertex = (id: string | undefined) => {
        if (id === undefined) return;
        if (
          typeof id !== "string" ||
          !id.trim() ||
          id.length > 128 ||
          vertexIds.has(id)
        )
          throw Error(
            "Sketch vertex identities must be unique nonempty strings within a path.",
          );
        vertexIds.add(id);
      };
      vertex(c.startVertexId);
      c.segments.forEach((s, index) => {
        const closing =
          index === c.segments.length - 1 &&
          sameSketchPoint(s.end, c.start) &&
          s.endVertexId === c.startVertexId;
        if (!closing) vertex(s.endVertexId);
      });
      const segmentIds = new Set<string>();
      let previous = c.start;
      for (const s of c.segments) {
        if (s.id !== undefined) {
          if (
            typeof s.id !== "string" ||
            !s.id.trim() ||
            s.id.length > 128 ||
            segmentIds.has(s.id)
          )
            throw Error(
              "Sketch segment identities must be unique nonempty strings within a path.",
            );
          segmentIds.add(s.id);
        }
        point(s.end);
        if (sameSketchPoint(previous, s.end))
          throw new Error("Sketch segment has zero length.");
        if (s.type === "arc") {
          point(s.middle);
          const area =
            (s.middle[0] - previous[0]) * (s.end[1] - previous[1]) -
            (s.middle[1] - previous[1]) * (s.end[0] - previous[0]);
          if (Math.abs(area) < 1e-8)
            throw new Error("Arc points must not be collinear.");
        } else if (s.type === "bezier") {
          s.controls.forEach(point);
          if (s.controls.length !== 2)
            throw new Error("Cubic Bezier needs two controls.");
        } else if (s.type === "ellipse") {
          if (
            ![s.radiusX, s.radiusY, s.rotationDegrees].every(Number.isFinite) ||
            s.radiusX <= 0 ||
            s.radiusY <= 0
          )
            throw new Error("Ellipse radii must be positive.");
        } else if (s.type !== "line")
          throw new Error("Unsupported sketch segment.");
        previous = s.end;
      }
    } else throw new Error("Unsupported sketch contour.");
  }
}
