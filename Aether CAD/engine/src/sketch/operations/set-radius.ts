import { validateSketchDrawing, type SketchDrawing } from "../drawing";
import { resolve } from "../solver/entities";
import type { SketchEntityRef } from "../solver/types";
import { solveDrawingConstraints } from "../solver/solve";
import { editDrawingDimension } from "./edit-dimension";

export function sketchEntityRadius(
  drawing: SketchDrawing,
  ref: SketchEntityRef,
): number {
  if (ref.kind !== "circle" && ref.kind !== "arc")
    throw new Error("Select a circle or circular arc.");
  const entity = resolve(drawing, ref);
  if (!entity.circle) throw new Error("Select a circle or circular arc.");
  return entity.circle.radius;
}

/** Add a driving radius, or update the existing driver rather than duplicating it. */
export function setSketchRadius(
  source: SketchDrawing,
  ref: SketchEntityRef,
  radiusMillimeters: number,
): SketchDrawing {
  if (!Number.isFinite(radiusMillimeters) || radiusMillimeters <= 0)
    throw new Error("Radius must be a positive finite length in millimeters.");
  sketchEntityRadius(source, ref);
  const existing = source.constraints?.find(
    (c) =>
      (c.kind === "radius" || c.kind === "diameter") &&
      !c.reference &&
      c.a.contour === ref.contour &&
      c.a.kind === ref.kind &&
      (ref.kind === "circle" || c.a.index === ref.index),
  );
  if (existing)
    return editDrawingDimension(
      source,
      existing.id,
      radiusMillimeters * (existing.kind === "diameter" ? 2 : 1),
    );
  const next = structuredClone(source),
    constraints = (next.constraints ??= []);
  const ids = new Set(constraints.map((c) => c.id));
  let sequence = 1;
  while (ids.has(`radius-${sequence}`)) sequence++;
  constraints.push({
    id: `radius-${sequence}`,
    kind: "radius",
    a: { ...ref },
    value: radiusMillimeters,
  });
  const solved = solveDrawingConstraints(next);
  validateSketchDrawing(solved);
  return solved;
}
