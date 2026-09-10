import {
  inferCenterSnaps,
  inferProjectedSnaps,
  inferEllipseQuadrants,
  inferPointSnaps,
  inferLineAlignment,
  inferMidpointSnaps,
  type SketchDrawing,
  type SketchPoint,
} from "@aether/core/sketch";

/** One inference pass before the workspace's geometry/undo commit. Keep gesture
 * policy here; geometric relationships and solving belong in Core. */
export function inferDrawingPlacement(
  before: SketchDrawing,
  after: SketchDrawing,
  options: {
    pointer: boolean;
    tool: string;
    placedPoints: readonly SketchPoint[];
  },
) {
  let next = inferCenterSnaps(before, inferEllipseQuadrants(before, after));
  if (options.pointer) {
    next = inferPointSnaps(before, next, options.placedPoints);
    next = inferMidpointSnaps(before, next, options.placedPoints);
    next = inferProjectedSnaps(before, next, options.placedPoints);
    if (options.tool === "line" || options.tool === "midpoint-line")
      next = inferLineAlignment(before, next);
  }
  return next;
}
