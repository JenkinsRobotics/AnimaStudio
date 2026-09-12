import type { SketchContour } from "../drawing";
import { contourNestingDepths } from "./nesting";

/** Build each solid's holes before unioning disconnected regions. This avoids
 * subtracting an unrelated hole from an already compound 2D region. Returns
 * undefined for touching/intersecting loops, which need ordered Booleans. */
export function sketchRegionGroups(
  contours: readonly SketchContour[],
): { solid: number; holes: number[] }[] | undefined {
  if (!contours.some((c) => c.hole))
    return contours.map((_, solid) => ({ solid, holes: [] }));
  const depths = contourNestingDepths(contours);
  if (!depths) return;
  const contained = (outer: number, inner: number) => {
    const pair = contourNestingDepths([contours[outer], contours[inner]]);
    return pair?.[0] === 0 && pair?.[1] === 1;
  };
  return contours.flatMap((contour, solid) => {
    if (contour.hole) return [];
    const holes = contours.flatMap((c, i) =>
      c.hole && depths[i] > depths[solid] && contained(solid, i) ? [i] : [],
    );
    return [
      {
        solid,
        holes: holes.filter(
          (h) =>
            !holes.some(
              (outer) => depths[outer] < depths[h] && contained(outer, h),
            ),
        ),
      },
    ];
  });
}
