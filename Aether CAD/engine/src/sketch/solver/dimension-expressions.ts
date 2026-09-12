import { evaluateExpression } from "../../expressions/evaluate";
import { parseExpression } from "../../expressions/parser";
import { numeric, type ExpressionValue } from "../../expressions/values";
import { dimensionUnit } from "./dimension-links";
import type { DrawingConstraint } from "./types";

export type DimensionExpressionVariables = ReadonlyMap<string, ExpressionValue>;
export function validateDimensionExpression(constraint: DrawingConstraint) {
  if (constraint.valueExpression === undefined) return;
  if (
    !dimensionUnit(constraint) ||
    constraint.reference ||
    constraint.valueFrom !== undefined
  )
    throw Error("Only independent driving dimensions support formulas.");
  parseExpression(constraint.valueExpression);
  if (!Number.isFinite(constraint.value))
    throw Error("Dimension formulas require a finite resolved value.");
}

/** Formula units are explicit and independent of document display preferences. */
export function resolveDimensionExpression(
  constraint: DrawingConstraint,
  expression: string,
  variables: DimensionExpressionVariables,
): number {
  const family = dimensionUnit(constraint);
  if (!family) throw Error("Select a dimensional constraint.");
  const value = numeric(
    evaluateExpression(expression, {
      allowText: false,
      resolveVariable(name) {
        const result = variables.get(name);
        if (result === undefined) throw Error(`Unknown variable #${name}.`);
        return result;
      },
    }),
  );
  if (
    value.lengthPower !== (family === "length" ? 1 : 0) ||
    value.anglePower !== (family === "angle" ? 1 : 0)
  )
    throw Error(
      `Dimension formula must resolve to ${family}; include explicit units.`,
    );
  const canonical =
    value.magnitudeSI / (family === "length" ? 0.001 : Math.PI / 180);
  if (!Number.isFinite(canonical))
    throw Error("Dimension formula is outside the numeric range.");
  return canonical;
}
