import type { SketchContour } from "../drawing";
import { contourNestingDepths } from "./nesting";

/** Indices of closed region boundaries in Boolean/paint order. Does not mutate
 * contours or renumber entity references. Ambiguous loops retain the historical
 * solids-before-holes behavior; this function does not classify their regions. */
export function sketchRegionOrder(
  contours: readonly SketchContour[],
): number[] {
  const indices = contours.map((_, i) => i);
  if (!contours.some((c) => c.hole)) return indices;
  const depths = contourNestingDepths(contours);
  return indices.sort((a, b) =>
    depths
      ? depths[a] - depths[b]
      : Number(Boolean(contours[a].hole)) - Number(Boolean(contours[b].hole)),
  );
}
