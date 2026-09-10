import { parseExpression, type ExpressionNode } from "../expressions/parser";
import type { SketchDrawing } from "../sketch/drawing";
import { evaluateDocumentVariables, type DocumentVariable } from "./variables";

/** Only referenced definitions and their transitive dependencies travel with a selection. */
export function clipboardVariables(
  drawing: SketchDrawing,
  definitions: readonly DocumentVariable[] = [],
): DocumentVariable[] {
  evaluateDocumentVariables(definitions);
  const byName = new Map(definitions.map((value) => [value.name, value])),
    needed = new Set<string>();
  const visit = (node: ExpressionNode): void => {
    if (node.kind === "variable") {
      if (needed.has(node.name)) return;
      const definition = byName.get(node.name);
      if (!definition) throw Error(`Unknown variable #${node.name}.`);
      needed.add(node.name);
      visit(parseExpression(definition.expression));
    } else if (node.kind === "binary") {
      visit(node.left);
      visit(node.right);
    } else if (node.kind === "unary") visit(node.value);
    else if (node.kind === "call") node.arguments.forEach(visit);
  };
  for (const item of drawing.textItems ?? [])
    if (item.expression !== undefined) visit(parseExpression(item.expression));
  for (const constraint of drawing.constraints ?? [])
    if (constraint.valueExpression !== undefined)
      visit(parseExpression(constraint.valueExpression));
  return structuredClone(definitions.filter((value) => needed.has(value.name)));
}

export function mergeClipboardVariables(
  existing: readonly DocumentVariable[] = [],
  incoming: readonly DocumentVariable[],
): DocumentVariable[] {
  const result = structuredClone([...existing]),
    byName = new Map(result.map((value) => [value.name, value]));
  for (const value of incoming) {
    const prior = byName.get(value.name);
    if (
      prior &&
      (prior.kind !== value.kind || prior.expression !== value.expression)
    )
      throw Error(
        `Variable #${value.name} has a different definition in this document. Rename or reconcile it before pasting.`,
      );
    if (!prior) {
      const copy = structuredClone(value);
      result.push(copy);
      byName.set(copy.name, copy);
    }
  }
  evaluateDocumentVariables(result);
  return result;
}
