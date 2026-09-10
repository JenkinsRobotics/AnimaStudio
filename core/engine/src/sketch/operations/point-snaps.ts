import {
  contourClosed,
  type SketchDrawing,
  type SketchPoint,
} from "../drawing";
import { sketchEntities, sketchEntityPoint } from "../solver/entities";
import type { SketchEntityRef } from "../solver/types";

const same = (a: SketchEntityRef | undefined, b: SketchEntityRef) =>
  a?.kind === b.kind &&
  a.contour === b.contour &&
  a.index === b.index &&
  a.control === b.control;

/** Infer endpoint coincidence and origin anchoring only for newly authored
 * vertices. Existing solver constraints remain the sole persisted truth. */
export function inferPointSnaps(
  before: SketchDrawing,
  after: SketchDrawing,
  placedPoints?: readonly SketchPoint[],
): SketchDrawing {
  const next = structuredClone(after),
    constraints = (next.constraints ??= []);
  const targets = sketchEntities(before).filter(
    (e) => e.ref.kind === "point" && e.ref.control === undefined,
  );
  const seen = new Set<string>(),
    ids = new Set(constraints.map((c) => c.id));
  let sequence = 1;
  for (const { ref: original } of sketchEntities(next)) {
    if (original.kind !== "point" || original.control !== undefined) continue;
    const ref = { ...original },
      contour = next.contours[ref.contour];
    if (
      contour.type === "path" &&
      contourClosed(contour) &&
      ref.index === contour.segments.length
    )
      ref.index = 0;
    const key = JSON.stringify(ref);
    if (seen.has(key) || sketchEntityPoint(before, ref)) continue;
    seen.add(key);
    const point = sketchEntityPoint(next, ref);
    if (
      !point ||
      (placedPoints &&
        !placedPoints.some(
          (p) => Math.hypot(p[0] - point[0], p[1] - point[1]) < 1e-7,
        ))
    )
      continue;
    const atOrigin = Math.hypot(...point) < 1e-7;
    if (atOrigin && constraints.some((c) => c.kind === "fix" && same(c.a, ref)))
      continue;
    // Center/quadrant inference already attaches this point to source geometry.
    if (
      !atOrigin &&
      constraints.some(
        (c) =>
          ["coincident", "concentric", "quadrant"].includes(c.kind) &&
          (same(c.a, ref) || same(c.b, ref)),
      )
    )
      continue;
    const target = targets.find((e) => {
      const p = sketchEntityPoint(before, e.ref);
      return (
        p &&
        !same(e.ref, ref) &&
        Math.hypot(p[0] - point[0], p[1] - point[1]) < 1e-7
      );
    });
    if (!atOrigin && !target) continue;
    while (ids.has(`point-inferred-${sequence}`)) sequence++;
    const id = `point-inferred-${sequence++}`;
    ids.add(id);
    constraints.push(
      atOrigin
        ? { id, kind: "fix", a: ref, point: [0, 0] }
        : { id, kind: "coincident", a: ref, b: target!.ref },
    );
  }
  return next;
}
