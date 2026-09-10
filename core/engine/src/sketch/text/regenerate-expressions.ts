import { validateSketchDrawing, type SketchDrawing } from "../drawing";
import { putSketchText } from "./edit";
import {
  resolveSketchTextExpression,
  type TextExpressionVariables,
} from "./expression";

/** Atomic draft operation: callers commit only the returned drawing. Resolve all
 * wording first, then regenerate changed items using their embedded fonts. Stable
 * construction frames keep their constraints; manually edited letters reject.
 * Unchanged wording does not replace edge identities or disturb manual edits. */
export async function regenerateSketchTextExpressions(
  source: SketchDrawing,
  variables: TextExpressionVariables,
): Promise<SketchDrawing> {
  validateSketchDrawing(source);
  // Snapshot caller-owned inputs before any asynchronous font work.
  let next = structuredClone(source);
  const resolvedVariables = structuredClone(new Map(variables));
  const changes = (next.textItems ?? []).flatMap((item) => {
    if (item.expression === undefined) return [];
    const text = resolveSketchTextExpression(
      item.expression,
      resolvedVariables,
    );
    return text === item.text ? [] : [{ id: item.id, text }];
  });
  for (const change of changes) {
    const item = next.textItems!.find((item) => item.id === change.id)!;
    next = await putSketchText(next, {
      ...item,
      text: change.text,
      expressionVariables: resolvedVariables,
    });
  }
  validateSketchDrawing(next);
  return next;
}
