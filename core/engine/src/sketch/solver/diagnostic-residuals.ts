import type { SketchDrawing } from "../drawing";
import type { DrawingConstraint } from "./types";
import { constraintResiduals } from "./residuals";

/** Mobility rank uses equalities. A quadrant's finite-span bound restricts
 * the direction of motion at an endpoint, but does not fix that endpoint.
 * Satisfaction/conflict checks must continue using the complete residual. */
export function diagnosticResiduals(
  drawing: SketchDrawing,
  constraint: DrawingConstraint,
): number[] {
  const residual = constraintResiduals(drawing, constraint);
  return constraint.kind === "quadrant" ? residual.slice(0, 2) : residual;
}
