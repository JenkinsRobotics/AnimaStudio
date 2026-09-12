import type { SketchEntityRef, DrawingConstraint } from "../solver/types";
export function splitPreservesContact(
  c: DrawingConstraint,
  ref: SketchEntityRef,
): boolean {
  return (
    ref.kind === "curve" &&
    ["coincident", "tangent", "curvature", "normal"].includes(c.kind)
  );
}
/** Piecewise affine parameter mapping preserves the same exact contact point. */
export function remapSplitContact(
  ref: SketchEntityRef,
  contour: number,
  segment: number,
  split: number,
): SketchEntityRef {
  if (ref.contour !== contour || ref.kind !== "curve" || ref.index !== segment)
    return ref;
  const t = ref.parameter;
  if (t === undefined || !Number.isFinite(t) || t < 0 || t > 1)
    throw Error("Cannot split an invalid curve contact.");
  const left = t <= split;
  return {
    ...ref,
    index: segment + (left ? 0 : 1),
    parameter: left ? t / split : (t - split) / (1 - split),
  };
}
