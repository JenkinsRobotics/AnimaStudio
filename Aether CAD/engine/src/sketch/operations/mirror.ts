import {
  validateSketchDrawing,
  type SketchDrawing,
  type SketchPoint,
} from "../drawing";
import type { SketchEntityRef } from "../solver/types";
import { resolve } from "../solver/entities";
import { mirrorTransform } from "../curves/reflection";
import { copyPatternContours } from "./pattern-relations";
export { mirrorTransform } from "../curves/reflection";
/** Numeric axes are fixed; an optional line reference stays live in the solver. */
export function mirrorSketch(
  drawing: SketchDrawing,
  selection: readonly number[],
  start: SketchPoint,
  end: SketchPoint,
  axis?: SketchEntityRef,
): SketchDrawing {
  const line = axis ? resolve(drawing, axis).line : undefined;
  if (axis && !line) throw Error("Select a sketch line as the mirror axis.");
  if (axis && selection.includes(axis.contour))
    throw Error("Exclude the axis contour from the mirror selection.");
  const next = copyPatternContours(drawing, selection, [
    mirrorTransform(line?.[0] ?? start, line?.[1] ?? end),
  ]);
  if (axis)
    for (const relation of next.constraints!.slice(
      drawing.constraints?.length ?? 0,
    )) {
      relation.axis = { ...axis };
      delete relation.transform;
    }
  validateSketchDrawing(next);
  return next;
}
