import type { SketchDrawing, SketchPoint } from "../drawing";
/** Standalone authored points can bound Extend. Implicit centers are not boundaries. */
export function sketchPointBoundaries(drawing: SketchDrawing): SketchPoint[] {
  return drawing.contours.flatMap((c) =>
    c.type === "path" && !c.segments.length ? [c.start] : [],
  );
}
export function pointOnLineParameter(
  point: SketchPoint,
  start: SketchPoint,
  end: SketchPoint,
): number | undefined {
  const dx = end[0] - start[0],
    dy = end[1] - start[1],
    length = Math.hypot(dx, dy);
  if (length < 1e-10) return;
  if (
    Math.abs((point[0] - start[0]) * dy - (point[1] - start[1]) * dx) / length >
    1e-7
  )
    return;
  return (
    ((point[0] - start[0]) * dx + (point[1] - start[1]) * dy) /
    (length * length)
  );
}
