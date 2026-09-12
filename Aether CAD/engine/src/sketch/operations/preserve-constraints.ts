import type { SketchDrawing } from "../drawing";
import { constraintResiduals } from "../drawing-constraints";
/** Topology-preserving edits retain references. Do not let a solve undo the user's edit. */
export function assertConstraintsSatisfied(drawing: SketchDrawing): void {
  for (const constraint of drawing.constraints ?? []) {
    const residuals = constraintResiduals(drawing, constraint);
    if (
      residuals.some(
        (value) => !Number.isFinite(value) || Math.abs(value) > 1e-6,
      )
    )
      throw new Error(
        `This edit conflicts with constraint "${constraint.id}" (${constraint.kind}). Its geometry was not changed.`,
      );
  }
}
