import {
  createSketchTangentArc,
  pickTangentArcSource,
  tangentArcContour,
  type SketchDrawing,
  type SketchPoint,
} from "@aether/core/sketch";

export const contextualDrawingTools = ["tangent-arc", "fit-spline"] as const;
export type ContextualDrawingTool = (typeof contextualDrawingTools)[number];

/** Two-click placement; the same Core geometry supplies preview and commit. */
export function placeTangentArc(
  drawing: SketchDrawing,
  pending: SketchPoint[],
  point: SketchPoint,
  tolerance: number,
  construction: boolean,
) {
  const source = pickTangentArcSource(drawing, pending[0] ?? point, tolerance);
  if (!pending.length) {
    const path = drawing.contours[source.contour];
    if (path.type !== "path") throw Error("Select a curve endpoint.");
    const start = source.endpoint
      ? path.segments[source.segment].end
      : source.segment
        ? path.segments[source.segment - 1].end
        : path.start;
    return {
      drawing,
      pending: [[...start] as SketchPoint],
      activePath: -1,
      committed: false,
    };
  }
  const result = createSketchTangentArc(drawing, source, point, construction);
  return {
    drawing: result.drawing,
    pending: [],
    activePath: result.contour,
    committed: true,
  };
}

export function previewTangentArc(
  drawing: SketchDrawing,
  start: SketchPoint,
  end: SketchPoint,
  tolerance: number,
) {
  return tangentArcContour(
    drawing,
    pickTangentArcSource(drawing, start, tolerance),
    end,
  );
}
