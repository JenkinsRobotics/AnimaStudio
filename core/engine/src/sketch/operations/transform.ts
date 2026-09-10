import { transformRetainedTextItem } from "../text/transform";
import { textOutlineDigest } from "../text/digest";
import { moveInternalConstraints } from "./move-constraints";
import { copyRetainedText } from "../text/copy";
import { copyInternalConstraints } from "./copy-constraints";
import { constraintResiduals } from "../drawing-constraints";
import { validateSketchDrawing, type SketchDrawing } from "../drawing";

import { transformContour, type SketchTransform } from "../curves/similarity";
export {
  transformContour,
  transformPoint,
  similarityTransform,
  type SketchTransform,
} from "../curves/similarity";
export function selectedContours(
  drawing: SketchDrawing,
  selection: readonly number[],
): number[] {
  const indices = [...new Set(selection)];
  if (
    !indices.length ||
    indices.some((i) => !Number.isInteger(i) || !drawing.contours[i])
  )
    throw new Error("Select one or more sketch contours.");
  return indices;
}
/** Moving preserves constraints: a move that violates them rejects atomically. */
export function moveSketchContours(
  drawing: SketchDrawing,
  selection: readonly number[],
  transform: SketchTransform,
): SketchDrawing {
  validateSketchDrawing(drawing);
  const next = structuredClone(drawing), indices=selectedContours(drawing, selection);
  for (const i of indices)
    next.contours[i] = transformContour(drawing.contours[i], transform);
  next.textItems=drawing.textItems?.map(item=>{
    const owned=item.contourIds.map(id=>drawing.contours.findIndex(c=>c.id===id));
    if(owned.some(i=>!indices.includes(i)) || textOutlineDigest(owned.map(i=>drawing.contours[i]))!==item.outlineDigest)return structuredClone(item);
    return transformRetainedTextItem(item,owned.map(i=>next.contours[i]),transform);
  });
  next.constraints=moveInternalConstraints(drawing,indices,transform);
  for (const constraint of next.constraints ?? [])
    if (constraintResiduals(next, constraint).some((r) => !Number.isFinite(r) || Math.abs(r) > 1e-6))
      throw new Error(
        "This transform conflicts with an existing constraint. Edit the constraint before moving this geometry.",
      );
  validateSketchDrawing(next);
  return next;
}
/** Copies retain internal constraints with independent identities. External relations are omitted. */
export function copySketchContours(
  drawing: SketchDrawing,
  selection: readonly number[],
  transforms: readonly SketchTransform[],
  options: { preserveConstraints?: boolean; preserveText?: boolean } = {},
): SketchDrawing {
  const indices = selectedContours(drawing, selection);
  if (drawing.contours.length + indices.length * transforms.length > 1000)
    throw new Error(
      "A sketch supports at most 1000 contours. Reduce the pattern count.",
    );
  const next = structuredClone(drawing);
  for (const transform of transforms)
    appendCopiedSketchContours(drawing, next, indices, transform, options);
  validateSketchDrawing(next);
  return next;
}

/** Internal append primitive shared by in-sketch copies and portable clipboard fragments.
 * Callers own a private target draft and validate it before committing. */
export function appendCopiedSketchContours(
  drawing: SketchDrawing,
  next: SketchDrawing,
  indices: readonly number[],
  transform: SketchTransform,
  options: { preserveConstraints?: boolean; preserveText?: boolean } = {},
): void {
  if (next.contours.length + indices.length > 1000)
    throw Error("A sketch supports at most 1000 contours.");
  const first = next.contours.length;
  for (const i of indices) {
    const copied = transformContour(drawing.contours[i], transform);
    copied.id = `contour-${crypto.randomUUID()}`;
    next.contours.push(copied);
  }
  if (options.preserveText !== false)
    copyRetainedText(
      drawing,
      next,
      new Map(indices.map((index, i) => [index, first + i])),
      transform,
    );
  if (options.preserveConstraints !== false) {
    const constraints = copyInternalConstraints(
      drawing,
      indices,
      first,
      transform,
    );
    if (constraints.length) (next.constraints ??= []).push(...constraints);
    for (const constraint of constraints) {
      if (
        constraintResiduals(next, constraint).some(
          (value) => !Number.isFinite(value) || Math.abs(value) > 1e-6,
        )
      )
        throw Error(
          `Cannot preserve ${constraint.kind} under this copy transform.`,
        );
    }
  }
}
