import { validateSketchDrawing, type SketchDrawing } from "../drawing";
import type { SketchEntityRef } from "../solver/types";
import { sketchEntityPoint } from "../solver/entities";
import { assertConstraintsSatisfied } from "./preserve-constraints";

/** Expose the existing cubic endpoint/control vector as a construction line.
 * Coincidence relations keep dimensions and edits attached to canonical controls. */
export function addSketchSplineHandle(
  drawing: SketchDrawing,
  ref: SketchEntityRef,
  end: "start" | "end",
): { drawing: SketchDrawing; handle: SketchEntityRef } {
  const path = drawing.contours[ref.contour];
  if (
    ref.kind !== "curve" ||
    path?.type !== "path" ||
    !Number.isInteger(ref.index) ||
    path.segments[ref.index!]?.type !== "bezier"
  )
    throw Error("Select a cubic spline span.");
  const endpoint: SketchEntityRef = {
    kind: "point",
    contour: ref.contour,
    index: ref.index! + (end === "end" ? 1 : 0),
  };
  const control: SketchEntityRef = {
    kind: "point",
    contour: ref.contour,
    index: ref.index,
    control: end === "start" ? 0 : 1,
  };
  const a = sketchEntityPoint(drawing, endpoint)!,
    b = sketchEntityPoint(drawing, control)!;
  if (Math.hypot(b[0] - a[0], b[1] - a[1]) < 1e-8)
    throw Error("This spline endpoint has no tangent direction.");
  const same = (a: SketchEntityRef | undefined, b: SketchEntityRef) =>
    a?.kind === b.kind &&
    a.contour === b.contour &&
    a.index === b.index &&
    a.control === b.control && (a.controlScale ?? 1) === (b.controlScale ?? 1);
  for (const c of drawing.constraints ?? []) {
    if (
      c.kind !== "coincident" ||
      !same(c.b, endpoint) ||
      c.a.kind !== "point" ||
      c.a.index !== 0
    )
      continue;
    const line = drawing.contours[c.a.contour];
    if (
      line?.type !== "path" ||
      !line.construction ||
      line.segments.length !== 1 ||
      line.segments[0].type !== "line"
    )
      continue;
    if (
      drawing.constraints?.some(
        (d) =>
          d.kind === "coincident" &&
          same(d.a, { kind: "point", contour: c.a.contour, index: 1 }) &&
          same(d.b, control),
      )
    )
      return {
        drawing: structuredClone(drawing),
        handle: { kind: "line", contour: c.a.contour, index: 0 },
      };
  }
  const next = structuredClone(drawing),
    contour = next.contours.length;
  next.contours.push({
    type: "path",
    construction: true,
    start: [...a],
    segments: [{ type: "line", end: [...b] }],
  });
  const constraints = (next.constraints ??= []),
    ids = new Set(constraints.map((c) => c.id));
  let sequence = 1;
  for (const [index, target] of [endpoint, control].entries()) {
    while (ids.has(`spline-handle-${sequence}`)) sequence++;
    const id = `spline-handle-${sequence++}`;
    ids.add(id);
    constraints.push({
      id,
      kind: "coincident",
      a: { kind: "point", contour, index },
      b: target,
    });
  }
  assertConstraintsSatisfied(next);
  validateSketchDrawing(next);
  return { drawing: next, handle: { kind: "line", contour, index: 0 } };
}
