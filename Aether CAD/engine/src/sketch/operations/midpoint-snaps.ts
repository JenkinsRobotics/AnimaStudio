import {
  contourClosed,
  type SketchDrawing,
  type SketchPoint,
} from "../drawing";
import { sketchArcGeometry } from "../arc-geometry";
import { sketchEntities, sketchEntityPoint } from "../solver/entities";
import type { SketchEntityRef } from "../solver/types";

/** Circular arc midpoints are halfway along the sweep, not the chord. */
export function midpointSnapPoints(drawing: SketchDrawing) {
  const points: { point: SketchPoint; ref: SketchEntityRef }[] = [];
  drawing.contours.forEach((path, contour) => {
    if (path.type !== "path") return;
    path.segments.forEach((s, index) => {
      const start = index === 0 ? path.start : path.segments[index - 1].end;
      if (s.type === "line")
        points.push({
          point: [(start[0] + s.end[0]) / 2, (start[1] + s.end[1]) / 2],
          ref: { kind: "line", contour, index },
        });
      if (s.type === "arc") {
        try {
          points.push({
            point: sketchArcGeometry(start, s.middle, s.end).midpoint,
            ref: { kind: "arc", contour, index },
          });
        } catch {
          /* Invalid draft arcs have no reliable midpoint. */
        }
      }
    });
  });
  return points;
}

/** Retain an explicit midpoint placement, without retroactively attaching old
 * vertices or adding a second relation to points already inferred elsewhere. */
export function inferMidpointSnaps(
  before: SketchDrawing,
  after: SketchDrawing,
  placedPoints: readonly SketchPoint[],
) {
  const candidates = midpointSnapPoints(before),
    next = structuredClone(after);
  const constraints = (next.constraints ??= []),
    ids = new Set(constraints.map((c) => c.id)),
    seen = new Set<string>();
  let sequence = 1;
  for (const { ref: original } of sketchEntities(next)) {
    if (original.kind !== "point" || original.control !== undefined) continue;
    const ref = { ...original },
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
    const point = sketchEntityPoint(next, ref);
    if (
      !point ||
      !placedPoints.some(
        (p) => Math.hypot(p[0] - point[0], p[1] - point[1]) < 1e-7,
      )
    )
      continue;
    const same = (r: SketchEntityRef | undefined) =>
      r?.kind === "point" &&
      r.contour === ref.contour &&
      r.index === ref.index &&
      r.control === undefined;
    if (
      constraints.some(
        (c) =>
          ["fix", "coincident", "concentric", "quadrant", "midpoint"].includes(
            c.kind,
          ) &&
          (same(c.a) || same(c.b)),
      )
    )
      continue;
    const snap = candidates.find(
      (c) => Math.hypot(c.point[0] - point[0], c.point[1] - point[1]) < 1e-7,
    );
    if (!snap) continue;
    while (ids.has(`midpoint-inferred-${sequence}`)) sequence++;
    const id = `midpoint-inferred-${sequence++}`;
    ids.add(id);
    constraints.push({ id, kind: "midpoint", a: snap.ref, b: ref });
  }
  return next;
}
