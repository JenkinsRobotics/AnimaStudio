import { contourClosed, type SketchContour } from "../drawing";
import { sketchArcGeometry } from "../arc-geometry";
import { offsetSketchContour } from "./offset";
/** Signed area of exact line/arc geometry chooses the interior side without sampling. */
export function closedSlotOffset(
  source: SketchContour,
  side: "inner" | "outer",
  width: number,
): number {
  if (!Number.isFinite(width) || width <= 1e-8)
    throw Error("Slot width must be positive and finite.");
  if (source.type === "circle") {
    if (width >= 2 * source.radius - 1e-8)
      throw Error(
        "Circular slot width must be smaller than its centerline diameter.",
      );
    return ((side === "inner" ? -1 : 1) * width) / 2;
  }
  if (
    !contourClosed(source) ||
    !source.segments.length ||
    source.segments.some((s) => s.type !== "line" && s.type !== "arc")
  )
    throw Error("Select a closed line/arc chain.");
  let area = 0,
    start = source.start;
  for (const s of source.segments) {
    area += start[0] * s.end[1] - start[1] * s.end[0];
    if (s.type === "arc") {
      const arc = sketchArcGeometry(start, s.middle, s.end);
      area += arc.radius ** 2 * (arc.sweep - Math.sin(arc.sweep));
    }
    start = s.end;
  }
  if (Math.abs(area) < 1e-8)
    throw Error("Closed slot centerline has no enclosed area.");
  return (Math.sign(area) * (side === "inner" ? 1 : -1) * width) / 2;
}
export function closedSlotBoundary(
  source: SketchContour,
  side: "inner" | "outer",
  width: number,
): SketchContour {
  const result = offsetSketchContour(
    source,
    closedSlotOffset(source, side, width),
  );
  return { ...result, construction: false, hole: side === "inner" };
}
