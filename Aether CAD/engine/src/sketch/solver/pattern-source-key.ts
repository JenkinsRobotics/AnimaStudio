import type { SketchEntityRef } from "./types";
/** Pattern curves refer to entire segments, so contact parameter is not part of source identity. */
export function patternSourceKey(ref: SketchEntityRef): string {
  return JSON.stringify([
    ref.projectedContourId ?? ref.contour,
    ref.kind,
    ref.kind === "contour" || ref.kind === "circle"
      ? null
      : (ref.segmentId ?? ref.vertexId ?? ref.index ?? null),
    ref.control ?? null,
  ]);
}
export function uniquePatternSources(
  refs: readonly SketchEntityRef[],
): SketchEntityRef[] {
  return [...new Map(refs.map((ref) => [patternSourceKey(ref), ref])).values()];
}
