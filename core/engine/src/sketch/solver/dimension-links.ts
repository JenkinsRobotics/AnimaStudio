import type { SketchDrawing } from "../drawing";
import type { DrawingConstraint } from "./types";
import { measuredDimensionValue } from "./measured-dimension";
export const dimensionUnit = (c: DrawingConstraint) =>
  c.kind === "angle"
    ? "angle"
    : [
          "distance",
          "horizontal-distance",
          "vertical-distance",
          "length",
          "radius",
          "diameter",
          "offset",
          "slot",
        ].includes(c.kind)
      ? "length"
      : undefined;
/** Resolve a dimensional driver by stable ID. No cached duplicate value is stored. */
export function resolveDimensionLink(
  drawing: SketchDrawing,
  constraint: DrawingConstraint,
): { driver: DrawingConstraint; sign: number; offset: number } {
  const expected = dimensionUnit(constraint);
  if (constraint.reference)
    throw Error("Reference dimensions cannot drive geometry.");
  if (!expected) throw new Error("Select a dimensional constraint.");
  let current = constraint,
    sign = 1,
    offset = 0;
  const seen = new Set<string>();
  while (current.valueFrom !== undefined) {
    if (seen.has(current.id)) throw new Error("Cyclic dimension link.");
    seen.add(current.id);
    if (current.value !== undefined)
      throw new Error("A linked dimension cannot also have a literal value.");
    const scale = current.valueScale ?? 1,
      shift = current.valueOffset ?? 0;
    if (!Number.isFinite(scale) || scale === 0 || !Number.isFinite(shift))
      throw Error(
        "Dimension links require a finite nonzero scale and finite offset.",
      );
    offset += sign * shift;
    sign *= scale;
    if (!Number.isFinite(sign) || sign === 0 || !Number.isFinite(offset))
      throw Error("Dimension link calculation is outside the numeric range.");
    if (current.valueSign !== undefined) {
      if (
        expected !== "angle" ||
        (current.valueSign !== 1 && current.valueSign !== -1)
      )
        throw new Error("Only angular links support a sign of +1 or -1.");
      sign *= current.valueSign;
    }
    const target = drawing.constraints?.find((c) => c.id === current.valueFrom);
    if (!target) throw new Error("The linked dimension driver is missing.");
    if (target.reference)
      throw Error("Reference dimensions cannot drive geometry.");
    if (dimensionUnit(target) !== expected)
      throw new Error("Linked dimensions must use compatible units.");
    current = target;
  }
  if (!Number.isFinite(current.value))
    throw new Error("Enter a finite constraint value.");
  if (
    current.valueSign !== undefined ||
    current.valueScale !== undefined ||
    current.valueOffset !== undefined
  )
    throw new Error("A dimension sign requires a driver link.");
  return { driver: current, sign, offset };
}
export function dimensionValue(
  drawing: SketchDrawing,
  constraint: DrawingConstraint,
): number {
  if (constraint.reference) return measuredDimensionValue(drawing, constraint);
  const { driver, sign, offset } = resolveDimensionLink(drawing, constraint);
  const value = driver.value! * sign + offset;
  if (!Number.isFinite(value))
    throw Error("Dimension link calculation is outside the numeric range.");
  return value;
}
/** When a driver is removed, preserve surviving dependent dimensions at their last resolved value. */
export function preserveRemovedDimensionDrivers(
  source: SketchDrawing,
  draft: SketchDrawing,
): void {
  const ids = new Set(draft.constraints?.map((c) => c.id));
  for (const c of draft.constraints ?? []) {
    if (c.valueFrom !== undefined && !ids.has(c.valueFrom)) {
      const original = source.constraints?.find((old) => old.id === c.id);
      if (!original)
        throw new Error("Cannot recover the removed dimension driver.");
      c.value = dimensionValue(source, original);
      delete c.valueFrom;
      delete c.valueSign;
      delete c.valueScale;
      delete c.valueOffset;
    }
  }
}

export function dimensionDriver(
  drawing: SketchDrawing,
  constraint: DrawingConstraint,
): DrawingConstraint {
  return resolveDimensionLink(drawing, constraint).driver;
}
