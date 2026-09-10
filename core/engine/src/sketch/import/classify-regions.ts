import {
  contourClosed,
  validateSketchDrawing,
  type SketchDrawing,
} from "../drawing";
import { contourNestingDepths } from "../regions/nesting";
/** Imported simple boundaries alternate solid / hole / island by containment. */
export function classifyImportedRegions(source: SketchDrawing): SketchDrawing {
  const next = structuredClone(source),
    closed = next.contours.filter((c) => !c.construction && contourClosed(c));
  const depths = contourNestingDepths(closed);
  if (!depths)
    throw Error(
      "Intersecting, touching or ambiguous closed profiles need manual region selection. Disable automatic hole detection to import them unchanged.",
    );
  closed.forEach((c, i) => {
    c.hole = depths[i] % 2 === 1;
  });
  validateSketchDrawing(next);
  return next;
}
