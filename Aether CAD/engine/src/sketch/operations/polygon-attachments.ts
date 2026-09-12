import {
  sameSketchPoint,
  type SketchContour,
  type SketchPoint,
} from "../drawing";
import type { SketchEntityRef } from "../solver/types";
import { pointOnLineParameter } from "../curves/point-boundaries";
type Path = Extract<SketchContour, { type: "path" }>;
/** Retain geometric correspondence, not arbitrary edge indices. A supporting
 * line may survive with shorter endpoints; finite contacts must remain inside. */
export function remapPolygonAttachment(
  ref: SketchEntityRef,
  contour: number,
  before: Path,
  after: Path,
): SketchEntityRef {
  if (ref.contour !== contour) return ref;
  const points = [after.start, ...after.segments.map((s) => s.end)];
  if (ref.kind === "point" && ref.control === undefined) {
    const p =
      ref.index === 0 ? before.start : before.segments[ref.index! - 1]?.end;
    const index = p ? points.findIndex((q) => sameSketchPoint(p, q)) : -1;
    if (index >= 0) return { ...ref, index };
  }
  if (
    (ref.kind === "line" || ref.kind === "curve") &&
    Number.isInteger(ref.index)
  ) {
    const start =
        ref.index === 0 ? before.start : before.segments[ref.index! - 1]?.end,
      end = before.segments[ref.index!]?.end;
    if (start && end)
      for (let index = 0; index < after.segments.length; index++) {
        const a = points[index],
          b = points[index + 1];
        const first = pointOnLineParameter(start, a, b),
          last = pointOnLineParameter(end, a, b);
        if (first === undefined || last === undefined || last <= first)
          continue;
        if (ref.kind === "line") return { ...ref, index };
        const t = ref.parameter;
        if (t === undefined || !Number.isFinite(t) || t < 0 || t > 1)
          throw Error("Invalid polygon curve contact.");
        const p: SketchPoint = [
          start[0] + t * (end[0] - start[0]),
          start[1] + t * (end[1] - start[1]),
        ];
        const parameter = pointOnLineParameter(p, a, b)!;
        if (parameter >= -1e-8 && parameter <= 1 + 1e-8)
          return {
            ...ref,
            index,
            parameter: Math.max(0, Math.min(1, parameter)),
          };
      }
  }
  throw Error(
    "A polygon attachment references geometry changed by the side count. Remove or revise that constraint first.",
  );
}
