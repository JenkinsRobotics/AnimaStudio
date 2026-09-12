import type { SketchDrawing } from "../drawing";
import type { DrawingConstraint } from "./types";
import { patternRelationTransform } from "../pattern-groups";
/** Suppression retains a slot and minimal presentation identity, never stale geometry. */
export function validatePatternSuppression(
  d: SketchDrawing,
  c: DrawingConstraint,
) {
  const metadata = c.patternSuppression;
  if (
    !metadata ||
    typeof metadata !== "object" ||
    Array.isArray(metadata) ||
    !c.patternGroup ||
    c.b
  )
    throw Error("Invalid suppressed pattern instance.");
  if (
    metadata.id !== undefined &&
    (typeof metadata.id !== "string" ||
      !metadata.id.trim() ||
      metadata.id.length > 128)
  )
    throw Error("Invalid suppressed instance identity.");
  for (const value of [metadata.construction, metadata.hole])
    if (value !== undefined && typeof value !== "boolean")
      throw Error("Invalid suppressed instance flags.");
  patternRelationTransform(d, c);
}
