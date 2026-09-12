import { evaluateExpression } from "./expressions/evaluate";
import { scalar } from "./expressions/values";
/** Numeric field calculations remain in the selected display unit. Shared typed
 * parsing adds functions; explicit units/variables/text belong to document expressions. */
export function evaluateQuantityExpression(source: string): number {
  if (!source.trim() || source.length > 512)
    throw Error("Enter a calculation of at most 512 characters.");
  try {
    return scalar(
      evaluateExpression(source, { allowUnits: false, allowText: false }),
    );
  } catch (error) {
    if (
      error instanceof Error &&
      error.message.startsWith("Invalid expression")
    )
      throw Error(
        "Enter numbers, pi, functions, parentheses and + − * / ^ operators.",
      );
    throw error;
  }
}
