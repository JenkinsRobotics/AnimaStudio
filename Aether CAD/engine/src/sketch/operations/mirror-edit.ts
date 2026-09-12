import { identifySourceEdges } from "./identify-source-edges";
import {
  patternSourceContour,
  mirrorAxisConflicts,
} from "../solver/pattern-source";
import {
  validateSketchDrawing,
  type SketchDrawing,
  type SketchPoint,
} from "../drawing";
import type { DrawingConstraint, SketchEntityRef } from "../solver/types";
import { resolve } from "../solver/entities";
import { solveDrawingConstraints } from "../solver/solve";
import { mirrorTransform } from "../curves/reflection";
import { transformContour } from "../curves/similarity";
export function isMirrorRelation(c: DrawingConstraint): boolean {
  return (
    c.kind === "pattern" &&
    (!!c.axis ||
      (!!c.transform &&
        c.transform.a * c.transform.d - c.transform.b * c.transform.c < 0))
  );
}
/** Reconstruct a representative fixed axis from its reflection matrix for editing. */
export function mirrorAxisPoints(
  d: SketchDrawing,
  c: DrawingConstraint,
): [SketchPoint, SketchPoint] {
  if (!isMirrorRelation(c)) throw Error("Select an existing mirror relation.");
  if (c.axis) {
    const line = resolve(d, c.axis).line;
    if (!line) throw Error("Mirror axis must be a line.");
    return structuredClone(line);
  }
  const t = c.transform!;
  const candidates: [[number, number], [number, number]] = [
    [1 + t.a, t.c],
    [t.b, 1 + t.d],
  ];
  const u =
    Math.hypot(...candidates[0]) > Math.hypot(...candidates[1])
      ? candidates[0]
      : candidates[1];
  const length = Math.hypot(...u);
  if (length < 1e-8) throw Error("Invalid reflection transform.");
  const start: SketchPoint = [t.tx / 2, t.ty / 2];
  return [
    start,
    [start[0] + (10 * u[0]) / length, start[1] + (10 * u[1]) / length],
  ];
}
export type MirrorAxisEdit =
  { axis: SketchEntityRef } | { start: SketchPoint; end: SketchPoint };
/** Replace the axis while retaining the relation and instance identities. */
export function editMirrorAxis(
  source: SketchDrawing,
  id: string,
  edit: MirrorAxisEdit,
): SketchDrawing {
  validateSketchDrawing(source);
  const next = structuredClone(source),
    c = next.constraints?.find((c) => c.id === id);
  if (!c || !isMirrorRelation(c) || !c.b)
    throw Error("Select an existing mirror relation.");
  let points: [SketchPoint, SketchPoint];
  if ("axis" in edit) {
    if (mirrorAxisConflicts(c.a, edit.axis, c.b.contour, next))
      throw Error(
        "Choose an axis distinct from the source geometry and outside its instance contour.",
      );
    const line = resolve(next, edit.axis).line;
    if (!line) throw Error("Mirror axis must be a line.");
    points = line;
    c.axis = identifySourceEdges(next, [edit.axis])[0];
    delete c.transform;
  } else {
    points = [edit.start, edit.end];
    delete c.axis;
  }
  const transform = mirrorTransform(...points);
  if (!("axis" in edit)) c.transform = transform;
  const target = next.contours[c.b.contour],
    expected = transformContour(patternSourceContour(next, c.a), transform);
  next.contours[c.b.contour] = {
    ...expected,
    id: target.id,
    construction: target.construction,
    hole: target.hole,
  };
  const solved = solveDrawingConstraints(next);
  validateSketchDrawing(solved);
  return solved;
}
