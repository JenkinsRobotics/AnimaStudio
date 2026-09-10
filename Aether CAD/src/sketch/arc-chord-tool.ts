import {
  contourClosed,
  type SketchDrawing,
  type SketchPoint,
} from "@aether/core/sketch";

/** A continued arc may drag from its existing start; other clicks still set its end. */
export function arcChordStart(
  drawing: SketchDrawing,
  activePath: number,
  point: SketchPoint,
  tolerance: number,
): SketchPoint | null {
  const path = drawing.contours[activePath];
  if (!path || path.type !== "path" || contourClosed(path)) return point;
  const start = path.segments.at(-1)?.end ?? path.start;
  return Math.hypot(start[0] - point[0], start[1] - point[1]) < tolerance
    ? [...start]
    : null;
}

/** Releasing sets the chord only. The curvature click owns the undo transaction. */
export function arcChordPoints(
  start: SketchPoint,
  end: SketchPoint,
): SketchPoint[] {
  if (
    !start.every(Number.isFinite) ||
    !end.every(Number.isFinite) ||
    Math.hypot(start[0] - end[0], start[1] - end[1]) < 1e-8
  )
    throw new Error("Arc endpoints must be distinct and finite.");
  return [[...start], [...end]];
}
