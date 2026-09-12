import { evaluateExpression } from "../../expressions/evaluate";
import { expressionText, type ExpressionValue } from "../../expressions/values";
import { normalizeSketchText } from "./content";

/** Ephemeral resolved document variables. Never persisted inside a sketch. */
export type TextExpressionVariables = ReadonlyMap<string, ExpressionValue>;

export function resolveSketchTextExpression(
  expression: string,
  variables: TextExpressionVariables = new Map(),
): string {
  return normalizeSketchText(
    expressionText(
      evaluateExpression(expression, {
        resolveVariable(name) {
          const value = variables.get(name);
          if (value === undefined) throw Error(`Unknown variable #${name}.`);
          return value;
        },
      }),
    ),
  );
}
