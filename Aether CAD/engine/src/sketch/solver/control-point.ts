import type { SketchContour, SketchPoint } from "../drawing";
import type { SketchEntityRef } from "./types";

/** Resolve a retained pre-subdivision control vector from native cubic geometry. */
export function scaledControlPoint(
  path: Extract<SketchContour, { type: "path" }>,
  ref: SketchEntityRef,
): SketchPoint | undefined {
  const s = path.segments[ref.index!];
  if (s?.type !== "bezier" || (ref.control !== 0 && ref.control !== 1)) return;
  const scale = ref.controlScale ?? 1;
  if (!Number.isFinite(scale) || scale <= 0)
    throw Error("Control reference scale must be positive and finite.");
  const anchor =
    ref.control === 0
      ? ref.index === 0
        ? path.start
        : path.segments[ref.index! - 1].end
      : s.end;
  const control = s.controls[ref.control];
  if (scale === 1) return control;
  return [
    anchor[0] + scale * (control[0] - anchor[0]),
    anchor[1] + scale * (control[1] - anchor[1]),
  ];
}
