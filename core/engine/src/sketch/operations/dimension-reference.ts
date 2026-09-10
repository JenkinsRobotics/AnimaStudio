import { validateSketchDrawing, type SketchDrawing } from "../drawing";
import { dimensionValue } from "../solver/dimension-links";
import { referenceDimensionKinds } from "../solver/measured-dimension";

/** Switching a driver to measurement freezes direct followers at their current
 * values. Their own followers stay linked; no link points at a reference value. */
export function setDimensionReference(
  source: SketchDrawing,
  id: string,
  reference: boolean,
): SketchDrawing {
  validateSketchDrawing(source);
  const next = structuredClone(source),
    c = next.constraints?.find((c) => c.id === id);
  if (!c || !referenceDimensionKinds.some((kind) => kind === c.kind))
    throw Error("Select a supported dimension.");
  if (!!c.reference === reference) return next;
  if (reference) {
    for (const follower of next.constraints ?? []) {
      if (follower.valueFrom !== id) continue;
      follower.value = dimensionValue(
        source,
        source.constraints!.find((c) => c.id === follower.id)!,
      );
      delete follower.valueFrom;
      delete follower.valueSign;
      delete follower.valueScale;
      delete follower.valueOffset;
    }
    c.reference = true;
    delete c.valueExpression;
    delete c.value;
    delete c.valueFrom;
    delete c.valueSign;
    delete c.valueScale;
    delete c.valueOffset;
  } else {
    c.value = dimensionValue(
      source,
      source.constraints!.find((c) => c.id === id)!,
    );
    delete c.reference;
  }
  validateSketchDrawing(next);
  return next;
}
