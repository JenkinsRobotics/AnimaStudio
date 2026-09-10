import {
  contourClosed,
  validateSketchDrawing,
  type SketchDrawing,
} from "../drawing";
import { resolve, sketchEntityPoint } from "../solver/entities";
import { ellipseQuadrant } from "../solver/ellipse-contact";
import { solveDrawingConstraints } from "../solver/solve";
/** Reassign the retained local-axis endpoint while preserving constraint identity. */
export function editSketchQuadrant(
  source: SketchDrawing,
  id: string,
  quadrant: number,
): SketchDrawing {
  validateSketchDrawing(source);
  if (!Number.isInteger(quadrant) || quadrant < 0 || quadrant > 3)
    throw Error("Choose one of the four ellipse quadrants.");
  const next = structuredClone(source),
    c = next.constraints?.find((c) => c.id === id);
  if (c?.kind !== "quadrant" || !c.b)
    throw Error("Select an existing quadrant constraint.");
  if (c.quadrant === quadrant) return next;
  const a = resolve(next, c.a),
    b = resolve(next, c.b),
    ellipse = a.ellipse ?? b.ellipse;
  const ref = a.point ? c.a : c.b,
    point = sketchEntityPoint(next, ref);
  if (!ellipse || !point) throw Error("Select a point and an ellipse.");
  const target = ellipseQuadrant(ellipse, quadrant),
    path = next.contours[ref.contour],
    closed = contourClosed(path);
  point[0] = target[0];
  point[1] = target[1];
  if (
    closed &&
    path.type === "path" &&
    ref.control === undefined &&
    (ref.index === 0 || ref.index === path.segments.length)
  ) {
    path.start = [...target];
    path.segments.at(-1)!.end = [...target];
  }
  c.quadrant = quadrant as 0 | 1 | 2 | 3;
  const solved = solveDrawingConstraints(next);
  validateSketchDrawing(solved);
  return solved;
}
