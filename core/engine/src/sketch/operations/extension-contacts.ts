import type { SketchDrawing } from "../drawing";
import type { SketchEntityRef } from "../solver/types";

/** The extended interval is expressed in the original segment parameter space.
 * Reparameterize existing contacts without moving their physical positions. */
export function remapExtendedContacts(
  drawing: SketchDrawing,
  contour: number,
  segment: number,
  from: number,
  to: number,
): void {
  if (
    !Number.isFinite(from) ||
    !Number.isFinite(to) ||
    from > 0 ||
    to < 1 ||
    to <= from
  )
    throw Error("Invalid extended curve interval.");
  const map = (ref: SketchEntityRef): SketchEntityRef => {
    if (
      ref.kind !== "curve" ||
      ref.contour !== contour ||
      ref.index !== segment
    )
      return ref;
    const t = ref.parameter;
    if (t === undefined || !Number.isFinite(t) || t < 0 || t > 1)
      throw Error("Cannot extend an invalid curve contact.");
    return { ...ref, parameter: (t - from) / (to - from) };
  };
  drawing.constraints = drawing.constraints?.map((c) => ({
    ...c,
    a: map(c.a),
    ...(c.b ? { b: map(c.b) } : {}),
    ...(c.axis ? { axis: map(c.axis) } : {}),
  }));
}
