import { solveProjectedConstraints } from "./projected-constraints";
import type { SketchDrawing } from "../sketch/drawing";

/** Authored references remain indexed within their own saved drawing. Resolve
 * its constraints before composing geometry so source topology never shifts them. */
export function composeProjectedDrawing(
  projected: SketchDrawing,
  authored?: SketchDrawing,
): SketchDrawing {
  if (!authored) return projected;
  const local = solveProjectedConstraints(authored, projected);
  const contours = [
    ...structuredClone(projected.contours),
    ...structuredClone(local.contours),
  ];
  const ids = new Set<string>();
  for (const contour of contours) {
    if (contour.id === undefined) continue;
    if (ids.has(contour.id))
      throw Error(
        `Mixed projection has duplicate contour identity: ${contour.id}.`,
      );
    ids.add(contour.id);
  }
  // Resolved geometry has no solver equations in the combined index space.
  return { type: "drawing", contours };
}
