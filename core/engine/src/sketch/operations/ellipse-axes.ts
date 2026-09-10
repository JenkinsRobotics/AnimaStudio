import { addEllipseSupport } from "./ellipse-support";
import { validateSketchDrawing, type SketchDrawing } from "../drawing";
import {
  ellipseAxisReferences,
  MissingEllipseAxisEndpoints,
  ellipseReferenceKey,
} from "./ellipse-axis-references";
import type { SketchEntityRef } from "../solver/types";
/** Construction diameters use ordinary quadrant/length/angle constraints so there
 * is no second editable representation of the ellipse radii or rotation. */
export function addSketchEllipseAxis(
  source: SketchDrawing,
  ref: SketchEntityRef,
  axis: "x" | "y",
): { drawing: SketchDrawing; axis: SketchEntityRef } {
  if (ref.kind !== "ellipse" || (axis !== "x" && axis !== "y"))
    throw Error("Select an ellipse and its X or Y axis.");
  const next = structuredClone(source);
  let endpoints;
  try {
    endpoints = ellipseAxisReferences(next, ref, axis);
  } catch (error) {
    if (!(error instanceof MissingEllipseAxisEndpoints)) throw error;
    addEllipseSupport(next, ref);
    endpoints = ellipseAxisReferences(next, ref, axis);
  }
  const constraints = (next.constraints ??= []);
  // Reuse only a complete pair of quadrant relations on a construction line.
  for (const c of constraints) {
    if (
      c.kind !== "quadrant" ||
      c.quadrant !== endpoints[0].quadrant ||
      c.a.kind !== "point" ||
      c.a.index !== 0 ||
      c.a.control !== undefined ||
      c.b?.kind !== "ellipse" ||
      ellipseReferenceKey(next, c.b) !==
        ellipseReferenceKey(next, endpoints[0].ref)
    )
      continue;
    const path = next.contours[c.a.contour];
    if (
      path?.type !== "path" ||
      !path.construction ||
      path.segments.length !== 1 ||
      path.segments[0].type !== "line"
    )
      continue;
    if (
      constraints.some(
        (other) =>
          other.kind === "quadrant" &&
          other.quadrant === endpoints[1].quadrant &&
          other.a.kind === "point" &&
          other.a.contour === c.a.contour &&
          other.a.index === 1 &&
          other.a.control === undefined &&
          other.b?.kind === "ellipse" &&
          ellipseReferenceKey(next, other.b) ===
            ellipseReferenceKey(next, endpoints[1].ref),
      )
    ) {
      validateSketchDrawing(next);
      return {
        drawing: next,
        axis: { kind: "line", contour: c.a.contour, index: 0 },
      };
    }
  }
  const contour = next.contours.length;
  next.contours.push({
    type: "path",
    construction: true,
    start: endpoints[0].point,
    segments: [{ type: "line", end: endpoints[1].point }],
  });
  const used = new Set(constraints.map((c) => c.id));
  let n = 1;
  for (const index of [0, 1]) {
    while (used.has(`ellipse-axis-${n}`)) n++;
    const id = `ellipse-axis-${n++}`;
    used.add(id);
    constraints.push({
      id,
      kind: "quadrant",
      a: { kind: "point", contour, index },
      b: { ...endpoints[index].ref },
      quadrant: endpoints[index].quadrant,
    });
  }
  validateSketchDrawing(next);
  return { drawing: next, axis: { kind: "line", contour, index: 0 } };
}
