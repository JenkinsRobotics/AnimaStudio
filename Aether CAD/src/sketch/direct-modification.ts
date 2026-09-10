import {
  insertSketchSplinePoint,
  ExtensionNeedsEndpoint,
  extendSketchCurve,
  splitSketchCircle,
  splitSketchSegment,
  trimSketchCurve,
  type SketchDrawing,
  type SketchPoint,
} from "@aether/core/sketch";
export type { DirectModificationTool as DirectModification } from "./tool-instructions";
import type { DirectModificationTool as DirectModification } from "./tool-instructions";
export interface DirectResult {
  drawing?: SketchDrawing;
  pending: SketchPoint[];
  message?: string;
}
function nearestCircle(
  drawing: SketchDrawing,
  point: SketchPoint,
  tolerance: number,
) {
  let index = -1,
    best = tolerance;
  drawing.contours.forEach((c, i) => {
    if (c.type === "circle") {
      const distance = Math.abs(
        Math.hypot(point[0] - c.center[0], point[1] - c.center[1]) - c.radius,
      );
      if (distance < best) {
        best = distance;
        index = i;
      }
    }
  });
  return index;
}
/** Shared by committed clicks and pointer previews for multi-step editing gestures. */
export function directModification(
  drawing: SketchDrawing,
  tool: DirectModification,
  point: SketchPoint,
  pending: SketchPoint[],
  tolerance: number,
): DirectResult {
  if (tool === "insert-spline-point") return {drawing: insertSketchSplinePoint(drawing, point, tolerance), pending: []};
  if (tool === "trim") {
    const next = trimSketchCurve(drawing, point, tolerance);
    const retained = new Set(next.constraints?.map((c) => c.id));
    const removed =
      drawing.constraints?.filter((c) => !retained.has(c.id)).length ?? 0;
    return {
      drawing: next,
      pending: [],
      message: removed
        ? `Trim removed ${removed} constraint${removed === 1 ? "" : "s"} attached to changed geometry. Undo restores them.`
        : undefined,
    };
  }
  if (tool === "extend") {
    try {
      return {
        drawing: extendSketchCurve(
          drawing,
          pending[0] ?? point,
          tolerance,
          pending.length ? point : undefined,
        ),
        pending: [],
      };
    } catch (error) {
      if (error instanceof ExtensionNeedsEndpoint && !pending.length)
        return {
          pending: [point],
          message:
            "Click the new endpoint. The curve keeps its original shape.",
        };
      throw error;
    }
  }
  const circle = nearestCircle(drawing, pending[0] ?? point, tolerance);
  if (circle >= 0) {
    if (!pending.length)
      return {
        pending: [point],
        message: "Click a second position on this circle.",
      };
    return {
      drawing: splitSketchCircle(drawing, circle, pending[0], point),
      pending: [],
    };
  }
  return {
    drawing: splitSketchSegment(drawing, point, tolerance),
    pending: [],
  };
}
