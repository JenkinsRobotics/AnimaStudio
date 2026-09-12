import { validateSketchDrawing, type SketchDrawing } from "../drawing";
import {
  resolveDimensionLink,
  preserveRemovedDimensionDrivers,
} from "../solver/dimension-links";
import { solveDrawingConstraints } from "../solver/solve";
/** Editing a follower edits its shared driver, so every linked dimension stays consistent. */
export function editDrawingDimension(
  source: SketchDrawing,
  id: string,
  value: number,
): SketchDrawing {
  const next = structuredClone(source),
    constraint = next.constraints?.find((c) => c.id === id);
  if (!constraint) throw new Error("Select an existing dimension.");
  if (!Number.isFinite(value))
    throw new Error("Enter a finite dimension value.");
  const { driver, sign, offset } = resolveDimensionLink(next, constraint);
  if (driver.valueExpression !== undefined)
    throw Error(
      "Edit or remove the dimension formula before entering a numeric value.",
    );
  driver.value = (value - offset) / sign;
  const solved = solveDrawingConstraints(next);
  validateSketchDrawing(solved);
  return solved;
}
export function removeDrawingConstraint(
  source: SketchDrawing,
  id: string,
): SketchDrawing {
  const next = structuredClone(source);
  next.constraints = next.constraints?.filter((c) => c.id !== id);
  preserveRemovedDimensionDrivers(source, next);
  validateSketchDrawing(next);
  return next;
}
