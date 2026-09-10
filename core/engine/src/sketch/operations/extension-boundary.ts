import type { SketchDrawing, SketchPoint } from "../drawing";
import type { SketchEntityRef } from "../solver/types";
import {
  closestSegmentParameter,
  segmentPoint,
} from "../curves/parameterization";
/** Identify the reached finite boundary, excluding the extended segment itself.
 * Conics/lines retain a sliding locus; cubic contacts solve a bounded parameter. */
export function extensionCurveBoundary(
  drawing: SketchDrawing,
  endpoint: SketchEntityRef,
  p: SketchPoint,
): SketchEntityRef | undefined {
  let result: SketchEntityRef | undefined,
    best = 1e-6;
  drawing.contours.forEach((c, contour) => {
    if (c.type === "circle") {
      const distance = Math.abs(
        Math.hypot(p[0] - c.center[0], p[1] - c.center[1]) - c.radius,
      );
      if (distance < best) {
        best = distance;
        result = { kind: "circle", contour };
      }
      return;
    }
    let start = c.start;
    c.segments.forEach((s, index) => {
      const a = start;
      start = s.end;
      if (
        contour === endpoint.contour &&
        index === (endpoint.index === 0 ? 0 : endpoint.index! - 1)
      )
        return;
      const parameter = closestSegmentParameter(a, s, p).parameter,
        q = segmentPoint(a, s, parameter),
        distance = Math.hypot(p[0] - q[0], p[1] - q[1]);
      if (distance < best) {
        best = distance;
        result = {
          kind: s.type === "bezier" ? "curve" : s.type,
          contour,
          index,
          ...(s.type === "bezier" ? { parameter, sliding: true } : {}),
        };
      }
    });
  });
  return result;
}
