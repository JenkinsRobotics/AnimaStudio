import { resolveDimensionExpression } from "../sketch/solver/dimension-expressions";
import type { PartFeature } from "./part-document";
import type { TextExpressionVariables } from "../sketch/text/expression";
import { resolveSketchTextExpression } from "../sketch/text/expression";
import type { SketchDrawing } from "../sketch/drawing";

/** Authored text only. Projected source text is resolved from its own feature. */
export function authoredTextDrawing(
  feature: PartFeature,
): SketchDrawing | undefined {
  if (feature.type !== "profile") return undefined;
  if (feature.profile.type === "drawing") return feature.profile;
  if (feature.profile.type === "projection") return feature.profile.authored;
  return undefined;
}

/** Call after feature structure validation, including suppressed/rolled-back work.
 * A saved formula may never silently disagree with its cached generated wording. */
export function validateDocumentTextExpressions(
  features: readonly PartFeature[],
  variables: TextExpressionVariables,
): void {
  for (const feature of features) {
    const drawing = authoredTextDrawing(feature);
    for (const constraint of drawing?.constraints ?? []) {
      if (constraint.valueExpression === undefined) continue;
      const expected = resolveDimensionExpression(
        constraint,
        constraint.valueExpression,
        variables,
      );
      if (constraint.value !== expected)
        throw Error(
          `Stale dimension expression in ${feature.name} (${constraint.id}). Regenerate before saving.`,
        );
    }
    for (const item of drawing?.textItems ?? []) {
      if (item.expression === undefined) continue;
      const expected = resolveSketchTextExpression(item.expression, variables);
      if (expected !== item.text)
        throw Error(
          `Stale text expression in ${feature.name} (${item.id}). Regenerate text before saving.`,
        );
    }
  }
}
