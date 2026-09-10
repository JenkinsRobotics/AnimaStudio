import type { SketchDrawing, SketchPoint } from "../drawing";
import type { SketchEntityRef } from "../solver/types";
import { identifySegmentReference } from "../solver/segment-reference";
import {
  closestSegmentParameter,
  segmentPoint,
} from "../curves/parameterization";

/** Nearest finite source geometry; discrete point snaps take precedence in UI. */
export function projectedCurveSnap(
  drawing: SketchDrawing,
  point: SketchPoint,
  tolerance: number,
) {
  let best:
    | {
        point: SketchPoint;
        ref: SketchEntityRef;
        kind: "coincident";
        label: string;
        distance: number;
        quadrant?: never;
      }
    | undefined;
  const accept = (p: SketchPoint, ref: SketchEntityRef, distance: number) => {
    if (distance <= tolerance && (!best || distance < best.distance))
      best = {
        point: p,
        ref,
        kind: "coincident",
        label: "Projected curve",
        distance,
      };
  };
  for (const contour of drawing.projectionContext ?? []) {
    if (!contour.id) continue;
    if (contour.type === "circle") {
      const dx = point[0] - contour.center[0],
        dy = point[1] - contour.center[1],
        length = Math.hypot(dx, dy);
      if (length < 1e-12) continue;
      accept(
        [
          contour.center[0] + (dx * contour.radius) / length,
          contour.center[1] + (dy * contour.radius) / length,
        ],
        { contour: -1, projectedContourId: contour.id, kind: "circle" },
        Math.abs(length - contour.radius),
      );
      continue;
    }
    let start = contour.start;
    contour.segments.forEach((segment, index) => {
      const hit = closestSegmentParameter(start, segment, point);
      accept(
        segmentPoint(start, segment, hit.parameter),
        {
          ...identifySegmentReference(contour, {
            kind: "curve",
            contour: -1,
            index,
            parameter: hit.parameter,
            sliding: true,
          }),
          projectedContourId: contour.id,
        },
        hit.distance,
      );
      start = segment.end;
    });
  }
  return best;
}
