import type { SketchDrawing } from "../drawing";
import type { SketchEntityRef } from "../solver/types";
import { resolve } from "../solver/entities";
import { ellipseQuadrant } from "../solver/ellipse-contact";

/** Candidate-only construction conic exposes absent diameter endpoints. Explicit
 * locus relations keep it dependent on the authored arc, not a detached copy. */
export function addEllipseSupport(
  drawing: SketchDrawing,
  ref: SketchEntityRef,
): void {
  const e = resolve(drawing, ref).ellipse;
  if (!e) throw Error("Select an elliptical sketch segment.");
  const index = drawing.contours.length;
  const segment = {
    type: "ellipse" as const,
    radiusX: e.radiusX,
    radiusY: e.radiusY,
    rotationDegrees: (e.rotation * 180) / Math.PI,
    largeArc: false,
    sweep: true,
  };
  const start = ellipseQuadrant(e, 0);
  drawing.contours.push({
    type: "path",
    construction: true,
    start,
    segments: [
      { ...segment, end: ellipseQuadrant(e, 2) },
      { ...segment, end: [...start] },
    ],
  });
  const constraints = (drawing.constraints ??= []),
    used = new Set(constraints.map((c) => c.id));
  for (const [a, b] of [
    [ref, { contour: index, kind: "ellipse" as const, index: 0 }],
    [
      { contour: index, kind: "ellipse" as const, index: 0 },
      { contour: index, kind: "ellipse" as const, index: 1 },
    ],
  ]) {
    let n = 1;
    while (used.has(`ellipse-support-${n}`)) n++;
    const id = `ellipse-support-${n}`;
    used.add(id);
    constraints.push({ id, kind: "ellipse-locus", a: { ...a }, b: { ...b } });
  }
}
