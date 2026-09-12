import {
  contourClosed,
  validateSketchDrawing,
  type SketchDrawing,
} from "../drawing";
import { constraintResiduals } from "../solver/residuals";
import type { DrawingConstraint, SketchEntityRef } from "../solver/types";

export type RectangleKind =
  "rectangle" | "center-rectangle" | "aligned-rectangle";

/** Preserve the placement tool's intent with ordinary, editable sketch constraints. */
export function constrainSketchRectangle(
  source: SketchDrawing,
  contour: number,
  kind: RectangleKind,
): SketchDrawing {
  const next = structuredClone(source);
  const path = next.contours[contour];
  if (
    !path ||
    path.type !== "path" ||
    path.segments.length !== 4 ||
    path.segments.some((s) => s.type !== "line") ||
    !contourClosed(path)
  )
    throw new Error("Rectangle relations require a closed four-line path.");
  const constraints = (next.constraints ??= []);
  const ids = new Set(constraints.map((c) => c.id));
  let sequence = 1;
  const add = (constraint: Omit<DrawingConstraint, "id">) => {
    while (ids.has(`rectangle-${sequence}`)) sequence++;
    const c = { ...constraint, id: `rectangle-${sequence++}` };
    ids.add(c.id);
    constraints.push(c);
    // Reject a mislabeled arbitrary quadrilateral instead of deforming it silently.
    if (
      constraintResiduals(next, c).some(
        (r) => !Number.isFinite(r) || Math.abs(r) > 1e-6,
      )
    )
      throw new Error(
        "The selected path does not have the requested rectangle geometry.",
      );
  };
  const line = (index: number): SketchEntityRef => ({
    contour,
    kind: "line",
    index,
  });
  if (kind === "aligned-rectangle") {
    add({ kind: "parallel", a: line(0), b: line(2) });
    add({ kind: "parallel", a: line(1), b: line(3) });
    add({ kind: "perpendicular", a: line(0), b: line(1) });
  } else {
    for (let index = 0; index < 4; index++)
      add({ kind: index % 2 ? "vertical" : "horizontal", a: line(index) });
  }
  if (kind === "center-rectangle") {
    const opposite = path.segments[1].end;
    const diagonal = next.contours.length;
    next.contours.push({
      type: "path",
      construction: true,
      start: [...path.start],
      segments: [{ type: "line", end: [...opposite] }],
    });
    const center = next.contours.length;
    next.contours.push({
      type: "path",
      construction: true,
      start: [
        (path.start[0] + opposite[0]) / 2,
        (path.start[1] + opposite[1]) / 2,
      ],
      segments: [],
    });
    add({
      kind: "coincident",
      a: { contour: diagonal, kind: "point", index: 0 },
      b: { contour, kind: "point", index: 0 },
    });
    add({
      kind: "coincident",
      a: { contour: diagonal, kind: "point", index: 1 },
      b: { contour, kind: "point", index: 2 },
    });
    add({
      kind: "midpoint",
      a: { contour: diagonal, kind: "line", index: 0 },
      b: { contour: center, kind: "point", index: 0 },
    });
  }
  validateSketchDrawing(next);
  return next;
}
