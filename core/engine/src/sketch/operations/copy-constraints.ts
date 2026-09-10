import type { SketchDrawing } from "../drawing";
import {
  dimensionUnit,
  dimensionValue,
  resolveDimensionLink,
} from "../solver/dimension-links";
import type { DrawingConstraint } from "../solver/types";
import { transformPoint, type SketchTransform } from "../curves/similarity";

/** Independent copies retain internal relations, never references to unselected
 * geometry. Pattern membership belongs to the original source/instance graph. */
export function copyInternalConstraints(
  source: SketchDrawing,
  indices: readonly number[],
  firstContour: number,
  transform: SketchTransform,
  preserveIdentities = false,
): DrawingConstraint[] {
  const contours = new Map(
    indices.map((index, i) => [index, firstContour + i]),
  );
  const scale = Math.hypot(transform.a, transform.c),
    det = Math.sign(transform.a * transform.d - transform.b * transform.c);
  const axis = (x: number, y: number): "horizontal" | "vertical" | undefined =>
    Math.abs(y) < 1e-8 * scale
      ? "horizontal"
      : Math.abs(x) < 1e-8 * scale
        ? "vertical"
        : undefined;
  const horizontal = axis(transform.a, transform.c),
    vertical = axis(transform.b, transform.d);
  const copies = new Map<
    string,
    { constraint: DrawingConstraint; factor: number }
  >();
  for (const original of source.constraints ?? []) {
    if (
      original.kind === "pattern" ||
      [original.a, original.b, original.axis].some(
        (ref) =>
          ref &&
          (ref.projectedContourId !== undefined || !contours.has(ref.contour)),
      )
    )
      continue;
    const constraint = structuredClone(original);
    constraint.id = preserveIdentities ? original.id : `constraint-${crypto.randomUUID()}`;
    for (const ref of [constraint.a, constraint.b, constraint.axis])
      if (ref) ref.contour = contours.get(ref.contour)!;
    let factor = dimensionUnit(original) === "length" ? scale : 1;
    if (original.kind === "horizontal" || original.kind === "vertical") {
      const direction = original.kind === "horizontal" ? horizontal : vertical;
      if (!direction) continue;
      constraint.kind = direction;
    }
    if (
      original.kind === "horizontal-distance" ||
      original.kind === "vertical-distance"
    ) {
      const x = original.kind === "horizontal-distance",
        direction = x ? horizontal : vertical;
      if (!direction) continue;
      constraint.kind =
        direction === "horizontal"
          ? "horizontal-distance"
          : "vertical-distance";
      factor = x
        ? direction === "horizontal"
          ? transform.a
          : transform.c
        : direction === "horizontal"
          ? transform.b
          : transform.d;
    }
    if (original.kind === "angle") factor = det;
    if (
      original.kind === "offset" &&
      source.contours[original.a.contour].type !== "circle"
    )
      factor *= det;
    if (constraint.point)
      constraint.point = transformPoint(constraint.point, transform);
    // World-axis circle quadrants are not invariant under arbitrary rotation.
    if (original.kind === "quadrant") {
      const ref = [original.a, original.b].find(
        (ref) => ref && ["circle", "arc"].includes(ref.kind),
      );
      if (ref) {
        if (!horizontal || !vertical) continue;
        const q = original.quadrant ?? 0,
          vectors = [
            [1, 0],
            [0, 1],
            [-1, 0],
            [0, -1],
          ],
          v = vectors[q];
        const x = transform.a * v[0] + transform.b * v[1],
          y = transform.c * v[0] + transform.d * v[1];
        constraint.quadrant =
          Math.abs(x) > Math.abs(y) ? (x > 0 ? 0 : 2) : y > 0 ? 1 : 3;
      } else if (det < 0 && constraint.quadrant !== undefined)
        constraint.quadrant = ([0, 3, 2, 1] as const)[constraint.quadrant];
    }
    copies.set(original.id, { constraint, factor });
  }
  for (const original of source.constraints ?? []) {
    const entry = copies.get(original.id);
    if (!entry) continue;
    const { constraint, factor } = entry;
    if (!dimensionUnit(original) || original.reference) continue;
    const copiedDriver =
      original.valueFrom === undefined
        ? undefined
        : copies.get(original.valueFrom);
    if (copiedDriver) {
      constraint.valueFrom = copiedDriver.constraint.id;
      constraint.valueScale =
        ((original.valueScale ?? 1) * factor) / copiedDriver.factor;
      constraint.valueOffset = (original.valueOffset ?? 0) * factor;
    } else {
      const { driver, sign, offset } = resolveDimensionLink(source, original);
      delete constraint.valueFrom;
      delete constraint.valueSign;
      delete constraint.valueScale;
      delete constraint.valueOffset;
      constraint.value = dimensionValue(source, original) * factor;
      if (driver.valueExpression !== undefined) {
        const unit = dimensionUnit(original) === "angle" ? "deg" : "mm";
        constraint.valueExpression =
          sign * factor === 1 && offset === 0
            ? driver.valueExpression
            : `(${driver.valueExpression}) * ${sign * factor} + (${offset * factor} ${unit})`;
      }
    }
  }
  return [...copies.values()].map((entry) => entry.constraint);
}
