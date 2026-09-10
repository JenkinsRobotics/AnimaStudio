import { angularSpanDistance } from "../curves/angular-span";
import { circularQuadrantSnaps } from "./circular-quadrants";
import {
  contourClosed,
  type SketchDrawing,
  type SketchPoint,
} from "../drawing";
import { resolve, sketchEntities, sketchEntityPoint } from "../solver/entities";
import type { SketchEntityRef } from "../solver/types";
import { ellipseQuadrant } from "../solver/ellipse-contact";
import { ellipseFrame } from "../curves/parameterization";
export interface EllipseSnap {
  point: SketchPoint;
  ellipse: SketchEntityRef;
  quadrant: 0 | 1 | 2 | 3;
}
/** Exact local-axis endpoints, clipped to the visible span of trimmed ellipses. */
export function ellipseSnapPoints(d: SketchDrawing): EllipseSnap[] {
  const result: EllipseSnap[] = circularQuadrantSnaps(d);
  d.contours.forEach((path, contour) => {
    if (path.type !== "path") return;
    const whole = d.constraints?.some(
      (c) => c.kind === "ellipse-shape" && c.a.contour === contour,
    );
    path.segments.forEach((s, index) => {
      if (s.type !== "ellipse" || (whole && index > 0)) return;
      const ref: SketchEntityRef = { kind: "ellipse", contour, index },
        e = resolve(d, ref).ellipse!;
      const frame = ellipseFrame(
        index === 0 ? path.start : path.segments[index - 1].end,
        s,
      );
      for (let q = 0; q < 4; q++) {
        if (
          !whole &&
          angularSpanDistance(
            frame.startAngle,
            frame.sweep,
            (q * Math.PI) / 2,
          ) > 0
        )
          continue;
        result.push({
          point: ellipseQuadrant(e, q),
          ellipse: ref,
          quadrant: q as 0 | 1 | 2 | 3,
        });
      }
    });
  });
  return result;
}
/** Infer only newly authored vertices at exact snap positions. Existing geometry
 * and off-curve points are never moved by inference. Caller owns undo grouping. */
export function inferEllipseQuadrants(
  before: SketchDrawing,
  after: SketchDrawing,
): SketchDrawing {
  const candidates = ellipseSnapPoints(before);
  if (!candidates.length) return after;
  const next = structuredClone(after),
    seen = new Set<string>(),
    constraints = (next.constraints ??= []);
  const ids = new Set(constraints.map((c) => c.id));
  let sequence = 1;
  for (const entity of sketchEntities(next)) {
    if (entity.ref.kind !== "point" || entity.ref.control !== undefined)
      continue;
    const ref = { ...entity.ref },
      path = next.contours[ref.contour];
    if (
      path.type === "path" &&
      contourClosed(path) &&
      ref.index === path.segments.length
    )
      ref.index = 0;
    const key = JSON.stringify(ref);
    if (seen.has(key) || sketchEntityPoint(before, ref)) continue;
    seen.add(key);
    const p = sketchEntityPoint(next, ref);
    if (!p) continue;
    const snap = candidates.find(
      (c) => Math.hypot(c.point[0] - p[0], c.point[1] - p[1]) < 1e-7,
    );
    if (!snap) continue;
    if (
      constraints.some(
        (c) =>
          ["fix", "coincident", "quadrant", "midpoint", "concentric"].includes(
            c.kind,
          ) &&
          [c.a, c.b].some(
            (r) =>
              r?.contour === ref.contour &&
              r.kind === ref.kind &&
              r.index === ref.index &&
              r.control === undefined &&
              r.projectedContourId === undefined,
          ),
      )
    )
      continue;
    while (ids.has(`quadrant-inferred-${sequence}`)) sequence++;
    const id = `quadrant-inferred-${sequence++}`;
    ids.add(id);
    constraints.push({
      id,
      kind: "quadrant",
      a: ref,
      b: snap.ellipse,
      quadrant: snap.quadrant,
    });
  }
  return next;
}
