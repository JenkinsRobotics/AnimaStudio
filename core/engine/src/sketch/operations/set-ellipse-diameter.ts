import { validateSketchDrawing, type SketchDrawing } from "../drawing";
import type { SketchEntityRef } from "../solver/types";
import { addSketchEllipseAxis } from "./ellipse-axes";
import { editDrawingDimension } from "./edit-dimension";
import { solveDrawingConstraints } from "../solver/solve";
import { resolve } from "../solver/entities";

export function sketchEllipseDiameters(
  drawing: SketchDrawing,
  ref: SketchEntityRef,
): [number, number] {
  const e = resolve(drawing, ref).ellipse;
  if (!e) throw Error("Select an elliptical sketch segment.");
  return [2 * e.radiusX, 2 * e.radiusY];
}
/** Ordinary construction-axis length driver; reuses existing dimensions and links. */
export function setSketchEllipseDiameter(
  source: SketchDrawing,
  ref: SketchEntityRef,
  axis: "x" | "y",
  diameterMillimeters: number,
): SketchDrawing {
  if (!Number.isFinite(diameterMillimeters) || diameterMillimeters <= 0)
    throw Error("Ellipse diameter must be a positive finite length.");
  const { drawing, axis: line } = addSketchEllipseAxis(source, ref, axis);
  const constraints = (drawing.constraints ??= []);
  const existing = constraints.find(
    (c) =>
      c.kind === "length" &&
      !c.reference &&
      c.a.kind === "line" &&
      c.a.contour === line.contour &&
      c.a.index === line.index,
  );
  if (existing)
    return editDrawingDimension(drawing, existing.id, diameterMillimeters);
  const ids = new Set(constraints.map((c) => c.id));
  let n = 1;
  while (ids.has(`ellipse-diameter-${n}`)) n++;
  constraints.push({
    id: `ellipse-diameter-${n}`,
    kind: "length",
    a: line,
    value: diameterMillimeters,
  });
  const solved = solveDrawingConstraints(drawing);
  validateSketchDrawing(solved);
  return solved;
}
