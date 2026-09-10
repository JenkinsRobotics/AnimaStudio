import type { SketchEntityRef } from "../solver/types";

/** De Casteljau subdivision scales the first/last control vectors by t/1-t. */
export function remapSplitControl(
  ref: SketchEntityRef,
  contour: number,
  segment: number,
  split: number,
): SketchEntityRef {
  if (
    ref.kind !== "point" ||
    ref.control === undefined ||
    ref.contour !== contour ||
    ref.index !== segment
  )
    return ref;
  return {
    ...ref,
    index: segment + (ref.control === 1 ? 1 : 0),
    controlScale:
      (ref.controlScale ?? 1) / (ref.control === 0 ? split : 1 - split),
  };
}
