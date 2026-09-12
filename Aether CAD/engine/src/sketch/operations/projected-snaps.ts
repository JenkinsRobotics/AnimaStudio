import { projectedCurveSnap } from "./projected-curve-snap";
import { ellipseSnapPoints } from "./ellipse-snaps";
import { identifySegmentReference } from "../solver/segment-reference";
import {
  contourClosed,
  type SketchDrawing,
  type SketchPoint,
} from "../drawing";
import { sketchEntities, sketchEntityPoint } from "../solver/entities";
import type { SketchEntityRef, DrawingConstraintKind } from "../solver/types";
import { centerSnapPoints } from "./center-snaps";
import { midpointSnapPoints } from "./midpoint-snaps";

export function projectedSnapPoints(drawing: SketchDrawing) {
  const result: {
    point: SketchPoint;
    ref: SketchEntityRef;
    kind: DrawingConstraintKind;
    label: string;
    quadrant?: 0 | 1 | 2 | 3;
  }[] = [];
  for (const c of drawing.projectionContext ?? []) {
    if (!c.id) continue;
    const local: SketchDrawing = { type: "drawing", contours: [c] };
    const append = (
      point: SketchPoint,
      ref: SketchEntityRef,
      kind: DrawingConstraintKind,
      label: string,
      quadrant?: 0 | 1 | 2 | 3,
    ) =>
      result.push({
        point,
        ref: {
          ...identifySegmentReference(c, ref),
          contour: -1,
          projectedContourId: c.id,
        },
        kind,
        label: `Projected ${label}`,
        ...(quadrant !== undefined ? { quadrant } : {}),
      });
    for (const e of sketchEntities(local))
      if (e.ref.kind === "point" && e.ref.control === undefined) {
        const p = sketchEntityPoint(local, e.ref);
        if (p)
          append(
            p,
            e.ref,
            "coincident",
            c.type === "circle" ? "center" : "endpoint",
          );
      }
    for (const p of centerSnapPoints(local))
      append(p.point, p.ref, "concentric", "center");
    for (const p of ellipseSnapPoints(local))
      append(p.point, p.ellipse, "quadrant", "quadrant", p.quadrant);
    for (const p of midpointSnapPoints(local))
      append(p.point, p.ref, "midpoint", "midpoint");
  }
  return result;
}

/** Persist a selected exact snap only for newly placed authored vertices.
 * Existing local inference wins if it has already attached the vertex. */
export function inferProjectedSnaps(
  before: SketchDrawing,
  after: SketchDrawing,
  placed: readonly SketchPoint[],
): SketchDrawing {
  const candidates = projectedSnapPoints(before);
  if (!before.projectionContext?.length) return after;
  const next = structuredClone(after),
    constraints = (next.constraints ??= []),
    seen = new Set<string>(),
    ids = new Set(constraints.map((c) => c.id));
  let sequence = 1;
  const same = (a: SketchEntityRef | undefined, b: SketchEntityRef) =>
    a?.contour === b.contour &&
    a.kind === b.kind &&
    a.index === b.index &&
    a.control === b.control &&
    a.projectedContourId === b.projectedContourId;
  for (const e of sketchEntities(next)) {
    if (e.ref.kind !== "point" || e.ref.control !== undefined) continue;
    const ref = { ...e.ref },
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
    const point = sketchEntityPoint(next, ref)!;
    if (
      !placed.some((p) => Math.hypot(p[0] - point[0], p[1] - point[1]) < 1e-7)
    )
      continue;
    if (
      constraints.some(
        (c) =>
          ["fix", "coincident", "concentric", "quadrant", "midpoint"].includes(
            c.kind,
          ) &&
          (same(c.a, ref) || same(c.b, ref)),
      )
    )
      continue;
    const snap =
      candidates.find(
        (p) => Math.hypot(p.point[0] - point[0], p.point[1] - point[1]) < 1e-7,
      ) ?? projectedCurveSnap(before, point, 1e-7);
    if (!snap) continue;
    while (ids.has(`projected-snap-${sequence}`)) sequence++;
    const id = `projected-snap-${sequence++}`;
    ids.add(id);
    constraints.push({
      id,
      kind: snap.kind,
      a: snap.kind === "midpoint" ? snap.ref : ref,
      b: snap.kind === "midpoint" ? ref : snap.ref,
      ...(snap.quadrant !== undefined ? { quadrant: snap.quadrant } : {}),
    });
  }
  return next;
}
