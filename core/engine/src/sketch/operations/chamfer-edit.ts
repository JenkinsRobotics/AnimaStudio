import { type SketchDrawing, type SketchPoint } from "../drawing";
import { resolve, type SketchEntityRef } from "../drawing-constraints";
import { dimensionDriver, dimensionValue } from "../solver/dimension-links";
import { editDrawingDimension } from "./edit-dimension";
const same = (a: SketchEntityRef, b: SketchEntityRef) =>
  a.contour === b.contour &&
  a.kind === b.kind &&
  a.index === b.index &&
  a.control === b.control;
export interface ChamferDimensions {
  distance: string;
  second?: string;
  angle?: string;
  equal: boolean;
}
/** Identify a bevel by its virtual-sharp relationships, not its display name or generated ID. */
export function findChamferDimensions(
  drawing: SketchDrawing,
  edge: SketchEntityRef,
): ChamferDimensions | undefined {
  const path = drawing.contours[edge.contour];
  if (edge.kind !== "line" || path?.type !== "path" || edge.index === undefined)
    return;
  const j = edge.index,
    count = path.segments.length;
  if (path.segments[j]?.type !== "line") return;
  const before = { ...edge, index: (j + count - 1) % count },
    after = { ...edge, index: (j + 1) % count };
  const constraints = drawing.constraints ?? [];
  const endpoint = (r: SketchEntityRef) =>
    r.kind === "point" &&
    r.contour === edge.contour &&
    r.control === undefined &&
    (r.index === j || r.index === j + 1 || (j === count - 1 && r.index === 0));
  for (const first of constraints) {
    if (
      first.kind !== "distance" ||
      !first.b ||
      !endpoint(first.b) ||
      first.a.kind !== "point"
    )
      continue;
    const sharp = first.a,
      side = (ref: SketchEntityRef) =>
        constraints.some(
          (c) =>
            c.kind === "coincident" &&
            c.b &&
            same(c.a, sharp) &&
            same(c.b, ref),
        );
    if (!side(before) || !side(after)) continue;
    const second = constraints.find(
      (c) =>
        c.id !== first.id &&
        c.kind === "distance" &&
        same(c.a, sharp) &&
        c.b &&
        endpoint(c.b) &&
        !same(c.b, first.b!),
    );
    const angle = constraints.find(
      (c) => c.kind === "angle" && c.b && (same(c.a, edge) || same(c.b, edge)),
    );
    if (!second && !angle) continue;
    return {
      distance: first.id,
      second: second?.id,
      angle: angle?.id,
      equal:
        !!second &&
        dimensionDriver(drawing, first).id ===
          dimensionDriver(drawing, second).id,
    };
  }
}
export function chamferDistanceHandle(
  drawing: SketchDrawing,
  id: string,
): { origin: SketchPoint; position: SketchPoint; radius: number } | undefined {
  const c = drawing.constraints?.find(
    (c) => c.id === id && c.kind === "distance",
  );
  if (!c?.b) return;
  const origin = resolve(drawing, c.a).point,
    position = resolve(drawing, c.b).point;
  if (!origin || !position) return;
  return {
    origin: [...origin],
    position: [...position],
    radius: dimensionValue(drawing, c),
  };
}
/** Existing bevel dimensions remain the authoritative geometry; edits keep linked batches together. */
export function editChamferDimensions(
  source: SketchDrawing,
  refs: ChamferDimensions,
  distance: number,
  second?: number,
  angleDegrees?: number,
): SketchDrawing {
  let next = editDrawingDimension(source, refs.distance, distance);
  if (refs.second && !refs.equal && second !== undefined)
    next = editDrawingDimension(next, refs.second, second);
  if (refs.angle && angleDegrees !== undefined) {
    const c = next.constraints!.find((c) => c.id === refs.angle)!;
    next = editDrawingDimension(
      next,
      c.id,
      Math.sign(dimensionValue(next, c)) * angleDegrees,
    );
  }
  return next;
}
