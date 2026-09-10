import { validateSketchDrawing, type SketchDrawing } from "../drawing";
import { solveDrawingConstraints } from "../solver/solve";
import {
  resolveDimensionExpression,
  type DimensionExpressionVariables,
} from "../solver/dimension-expressions";
import { dimensionValue } from "../solver/dimension-links";

/** Bind this dimension explicitly, replacing any prior follower relationship.
 * Null removes the formula while retaining its current dimensional value. */
export function setDimensionExpression(
  source: SketchDrawing,
  id: string,
  expression: string | null,
  variables: DimensionExpressionVariables,
): SketchDrawing {
  validateSketchDrawing(source);
  const next = structuredClone(source),
    constraint = next.constraints?.find((c) => c.id === id);
  if (!constraint || constraint.reference)
    throw Error("Select a driving dimension.");
  const value =
    expression === null
      ? dimensionValue(next, constraint)
      : resolveDimensionExpression(constraint, expression, variables);
  delete constraint.valueFrom;
  delete constraint.valueScale;
  delete constraint.valueOffset;
  delete constraint.valueSign;
  if (expression === null) delete constraint.valueExpression;
  else constraint.valueExpression = expression;
  constraint.value = value;
  const solved = solveDrawingConstraints(next);
  validateSketchDrawing(solved);
  return solved;
}

/** Resolve every driver first, then solve once so mutually dependent geometry
 * never sees an intermediate set of dimensional values. */
export function regenerateDimensionExpressions(
  source: SketchDrawing,
  variables: DimensionExpressionVariables,
): SketchDrawing {
  validateSketchDrawing(source);
  const next = structuredClone(source);
  for (const constraint of next.constraints ?? []) {
    if (constraint.valueExpression !== undefined)
      constraint.value = resolveDimensionExpression(
        constraint,
        constraint.valueExpression,
        variables,
      );
  }
  const solved = solveDrawingConstraints(next);
  validateSketchDrawing(solved);
  return solved;
}
