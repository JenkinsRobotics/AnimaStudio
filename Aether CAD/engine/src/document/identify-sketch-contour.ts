import { contourClosed, type SketchContour } from "../sketch/drawing";

/** Mutates only a candidate contour; callers own the atomic document commit. */
export function identifySketchContour(
  contour: SketchContour,
  createId: () => string,
): void {
  contour.id ??= createId();
  if (contour.type !== "path") return;
  contour.startVertexId ??= createId();
  contour.segments.forEach((segment, index) => {
    segment.id ??= createId();
    segment.endVertexId ??=
      index === contour.segments.length - 1 && contourClosed(contour)
        ? contour.startVertexId
        : createId();
  });
}
