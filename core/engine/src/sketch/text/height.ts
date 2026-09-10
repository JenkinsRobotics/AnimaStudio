/** Persisted metric permits synchronous solving without parsing an embedded font. */
export function textFrameHeight(item: {
  emSizeMillimeters: number;
  fontAscenderRatio?: number;
}): number {
  const ratio = item.fontAscenderRatio ?? 1;
  if (
    !Number.isFinite(ratio) ||
    ratio <= 0 ||
    !Number.isFinite(item.emSizeMillimeters) ||
    item.emSizeMillimeters <= 0
  )
    throw Error("Text height and font ascender must be positive.");
  return item.emSizeMillimeters * ratio;
}
