import { dimensionValue } from "../solver/dimension-links";
import { sketchArcGeometry } from "../arc-geometry";
import type { SketchDrawing, SketchPoint } from "../drawing";
import { resolve, type SketchEntityRef } from "../drawing-constraints";
export interface FilletHandle {
  origin: SketchPoint;
  position: SketchPoint;
  radius: number;
}
const same = (a: SketchEntityRef, b: SketchEntityRef) =>
  a.contour === b.contour &&
  a.kind === b.kind &&
  a.index === b.index &&
  a.control === b.control;
/** Project a fillet handle from its virtual sharp, or its center for finite curved contacts. */
export function filletRadiusHandle(
  drawing: SketchDrawing,
  id: string,
): FilletHandle | undefined {
  const dimension = drawing.constraints?.find(
    (c) => c.id === id && c.kind === "radius",
  );
  if (!dimension || dimension.reference || dimension.a.kind !== "arc") return;
  const lines = (drawing.constraints ?? []).flatMap((c) =>
    c.kind === "tangent" && c.b
      ? same(c.a, dimension.a) && c.b.kind === "line"
        ? [c.b]
        : same(c.b, dimension.a) && c.a.kind === "line"
          ? [c.a]
          : []
      : [],
  );
  if (lines.length !== 2) {
    const contacts = new Set<number>();
    for (const c of drawing.constraints ?? []) {
      if (c.kind !== "tangent" || !c.b) continue;
      for (const [ref, other] of [
        [c.a, c.b],
        [c.b, c.a],
      ]) {
        if (
          ref.kind === "curve" &&
          other.kind === "curve" &&
          ref.contour === dimension.a.contour &&
          ref.index === dimension.a.index &&
          (ref.parameter === 0 || ref.parameter === 1)
        )
          contacts.add(ref.parameter);
      }
    }
    if (contacts.size !== 2) return;
    const path = drawing.contours[dimension.a.contour],
      index = dimension.a.index!;
    if (path.type !== "path") return;
    const arc = path.segments[index];
    if (arc?.type !== "arc") return;
    const circle = sketchArcGeometry(
      index === 0 ? path.start : path.segments[index - 1].end,
      arc.middle,
      arc.end,
    );
    return {
      origin: [...circle.center],
      position: [...circle.midpoint],
      radius: dimensionValue(drawing, dimension),
    };
  }
  const points = (drawing.constraints ?? []).flatMap((c) =>
    c.kind === "coincident" &&
    c.b &&
    c.a.kind === "point" &&
    lines.some((l) => same(l, c.b!))
      ? [c.a]
      : [],
  );
  const sharp = points.find(
    (p) => points.filter((q) => same(p, q)).length >= 2,
  );
  if (!sharp) return;
  const origin = resolve(drawing, sharp).point,
    c = drawing.contours[dimension.a.contour];
  if (!origin || c.type !== "path") return;
  const arc = c.segments[dimension.a.index!];
  if (arc.type !== "arc") return;
  return {
    origin: [...origin],
    position: [...arc.middle],
    radius: dimensionValue(drawing, dimension),
  };
}
export function filletRadiusFromHandle(
  handle: FilletHandle,
  point: SketchPoint,
): number {
  const dx = handle.position[0] - handle.origin[0],
    dy = handle.position[1] - handle.origin[1],
    length = dx * dx + dy * dy;
  if (length < 1e-14)
    throw new Error("The fillet handle has no usable direction.");
  const radius =
    (handle.radius *
      ((point[0] - handle.origin[0]) * dx +
        (point[1] - handle.origin[1]) * dy)) /
    length;
  if (!Number.isFinite(radius) || radius <= 1e-7)
    throw new Error(
      "Drag away from the sharp corner to set a positive radius.",
    );
  return radius;
}
