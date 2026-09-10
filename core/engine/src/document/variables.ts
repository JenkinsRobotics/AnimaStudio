import { evaluateExpression } from "../expressions/evaluate";
import {
  numeric,
  quantity,
  sameUnits,
  type ExpressionValue,
} from "../expressions/values";
export interface DocumentVariable {
  name: string;
  kind: "number" | "length" | "angle" | "string";
  expression: string;
}
/** Expressions are the saved truth. Resolved SI quantities are ephemeral. */
export function evaluateDocumentVariables(
  value: unknown,
): Map<string, ExpressionValue> {
  if (value === undefined) return new Map();
  if (!Array.isArray(value) || value.length > 256)
    throw Error("A Part supports at most 256 variables.");
  const definitions = new Map<string, DocumentVariable>();
  for (const variable of value) {
    if (
      !variable ||
      typeof variable.name !== "string" ||
      !/^[A-Za-z_][A-Za-z0-9_]{0,63}$/.test(variable.name) ||
      definitions.has(variable.name)
    )
      throw Error(
        "Variable names must be unique identifiers of at most 64 characters.",
      );
    if (
      !["number", "length", "angle", "string"].includes(variable.kind) ||
      typeof variable.expression !== "string"
    )
      throw Error(`Invalid definition for #${variable.name}.`);
    definitions.set(variable.name, variable);
  }
  const resolved = new Map<string, ExpressionValue>(),
    active = new Set<string>();
  const resolve = (name: string): ExpressionValue => {
    const cached = resolved.get(name);
    if (cached !== undefined) return cached;
    const variable = definitions.get(name);
    if (!variable) throw Error(`Unknown variable #${name}.`);
    if (active.has(name))
      throw Error(`Circular variable dependency at #${name}.`);
    if (active.size >= 64)
      throw Error("Variable dependencies are nested too deeply.");
    active.add(name);
    try {
      const result = evaluateExpression(variable.expression, {
        resolveVariable: resolve,
      });
      if (variable.kind === "string") {
        if (typeof result !== "string")
          throw Error(`#${name} must resolve to text.`);
      } else {
        const expected = quantity(
          0,
          variable.kind === "length" ? 1 : 0,
          variable.kind === "angle" ? 1 : 0,
        );
        if (!sameUnits(numeric(result), expected))
          throw Error(`#${name} has incompatible units for ${variable.kind}.`);
      }
      resolved.set(name, result);
      return result;
    } finally {
      active.delete(name);
    }
  };
  for (const name of definitions.keys()) resolve(name);
  return resolved;
}
