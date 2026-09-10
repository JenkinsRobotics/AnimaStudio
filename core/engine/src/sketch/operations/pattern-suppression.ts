import { patternSourceContour } from "../solver/pattern-source";
import { validateSketchDrawing, type SketchDrawing } from "../drawing";
import { deleteSketchContour } from "./delete";
import { transformContour } from "./transform";
import { patternRelationTransform } from "../pattern-groups";
/** Retain relation identity while removing/restoring the actual generated contour. */
export function setPatternInstanceSuppressed(
  source: SketchDrawing,
  id: string,
  suppressed: boolean,
): SketchDrawing {
  validateSketchDrawing(source);
  let next = structuredClone(source);
  const c = next.constraints?.find((c) => c.id === id);
  if (!c || c.kind !== "pattern" || !c.patternGroup)
    throw Error("Select a grouped pattern instance.");
  if (!!c.patternSuppression === suppressed) return next;
  if (suppressed) {
    if (!c.b) throw Error("Pattern instance is missing.");
    const index = c.b.contour;
    if (
      next.constraints!.some(
        (other) =>
          other.id !== id &&
          [other.a, other.b, other.axis].some((r) => r?.contour === index),
      )
    )
      throw Error(
        "This instance has dependent sketch constraints. Remove those dependencies before suppressing it.",
      );
    const contour = next.contours[index];
    c.patternSuppression = {
      id: contour.id,
      construction: contour.construction,
      hole: contour.hole,
    };
    delete c.b;
    next = deleteSketchContour(next, index);
  } else {
    if (next.contours.length >= 1000)
      throw Error("A sketch supports at most 1000 contours.");
    const metadata = c.patternSuppression!,
      transform = patternRelationTransform(next, c);
    if (!transform) throw Error("Missing pattern transform.");
    const contour = {
      ...transformContour(patternSourceContour(next,c.a), transform),
      id: metadata.id,
      construction: metadata.construction,
      hole: metadata.hole,
    };
    c.b = { kind: "contour", contour: next.contours.length };
    next.contours.push(contour);
    delete c.patternSuppression;
  }
  validateSketchDrawing(next);
  return next;
}
