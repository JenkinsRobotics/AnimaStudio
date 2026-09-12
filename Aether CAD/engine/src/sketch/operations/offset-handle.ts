import type { SketchDrawing, SketchPoint } from "../drawing";
import { resolve } from "../drawing-constraints";
import { dimensionValue } from "../solver/dimension-links";
export interface OffsetHandle {
  origin: SketchPoint;
  position: SketchPoint;
  direction: SketchPoint;
  distance: number;
}
/** Geometry-only projection of a signed offset dimension. */
export function offsetDistanceHandle(
  drawing: SketchDrawing,
  id: string,
): OffsetHandle | undefined {
  const c = drawing.constraints?.find(
    (c) => c.id === id && c.kind === "offset",
  );
  if (!c) return;
  const entity = resolve(drawing, c.a),
    distance = dimensionValue(drawing, c);
  let origin: SketchPoint, direction: SketchPoint;
  if (entity.arc) {
    origin = [...entity.arc.midpoint];
    const sign = -Math.sign(entity.arc.sweep);
    direction = [
      (sign * (origin[0] - entity.arc.center[0])) / entity.arc.radius,
      (sign * (origin[1] - entity.arc.center[1])) / entity.arc.radius,
    ];
  } else if (entity.circle) {
    origin = [
      entity.circle.center[0] + entity.circle.radius,
      entity.circle.center[1],
    ];
    direction = [1, 0];
  } else {
    const path = entity.contour?.type === "path" ? entity.contour : undefined;
    const line =
      entity.line ??
      (path && path.segments[0]?.type === "line"
        ? [path.start, path.segments[0].end]
        : undefined);
    if (!line) return;
    const dx = line[1][0] - line[0][0],
      dy = line[1][1] - line[0][1],
      length = Math.hypot(dx, dy);
    if (length < 1e-10) return;
    origin = [(line[0][0] + line[1][0]) / 2, (line[0][1] + line[1][1]) / 2];
    direction = [-dy / length, dx / length];
  }
  return {
    origin,
    direction,
    distance,
    position: [
      origin[0] + direction[0] * distance,
      origin[1] + direction[1] * distance,
    ],
  };
}
export function offsetDistanceFromHandle(
  handle: OffsetHandle,
  point: SketchPoint,
): number {
  if (!point.every(Number.isFinite))
    throw Error("Offset handle coordinates must be finite.");
  return (
    (point[0] - handle.origin[0]) * handle.direction[0] +
    (point[1] - handle.origin[1]) * handle.direction[1]
  );
}
