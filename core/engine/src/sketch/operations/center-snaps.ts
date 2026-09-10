import {
  contourClosed,
  type SketchDrawing,
  type SketchPoint,
} from "../drawing";
import { ellipseFrame } from "../curves/parameterization";
import { sketchArcGeometry } from "../arc-geometry";
import { sketchEntities, sketchEntityPoint } from "../solver/entities";
import type { SketchEntityRef } from "../solver/types";

/** Geometric centers, including arcs without an authored center point. */
export function centerSnapPoints(drawing: SketchDrawing) {
  const result: { point: SketchPoint; ref: SketchEntityRef }[] = [];
  drawing.contours.forEach((contour, i) => {
    if (contour.type === "circle") {
      result.push({
        point: contour.center,
        ref: { contour: i, kind: "circle" },
      });
      return;
    }
    contour.segments.forEach((segment, index) => {
      if (segment.type !== "arc" && segment.type !== "ellipse") return;
      try {
        const start =
          index === 0 ? contour.start : contour.segments[index - 1].end;
        result.push({
          point:
            segment.type === "arc"
              ? sketchArcGeometry(start, segment.middle, segment.end).center
              : ellipseFrame(start, segment).center,
          ref: { contour: i, kind: segment.type, index },
        });
      } catch {
        /* Degenerate draft geometry cannot provide a center. */
      }
    });
  });
  return result;
}

/** Attach newly authored vertices to exact center snaps. No existing vertices
 * are changed. The caller commits geometry and inference in one undo step. */
export function inferCenterSnaps(
  before: SketchDrawing,
  after: SketchDrawing,
): SketchDrawing {
  const candidates = centerSnapPoints(before);
  if (!candidates.length) return after;
  const next = structuredClone(after),
    constraints = (next.constraints ??= []);
  const ids = new Set(constraints.map((c) => c.id)),
    seen = new Set<string>();
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
    const snap = candidates.find(
      (c) =>
        point &&
        Math.hypot(c.point[0] - point[0], c.point[1] - point[1]) < 1e-7,
    );
    if (!snap) continue;
    const same = (a: SketchEntityRef | undefined, b: SketchEntityRef) =>
      a?.kind === b.kind &&
      a.contour === b.contour &&
      a.index === b.index &&
      a.control === b.control;
    if (
      constraints.some(
        (c) =>
          c.kind === "concentric" &&
          ((same(c.a, ref) && same(c.b, snap.ref)) ||
            (same(c.b, ref) && same(c.a, snap.ref))),
      )
    )
      continue;
    while (ids.has(`center-inferred-${sequence}`)) sequence++;
    const id = `center-inferred-${sequence++}`;
    ids.add(id);
    constraints.push({ id, kind: "concentric", a: ref, b: snap.ref });
  }
  return next;
}
