import { sameSketchPoint, type SketchContour } from "../drawing";
import type { SketchEntityRef } from "./types";

/** Resolve vertex identity before numeric indexing; closing vertices alias start. */
export function resolveVertexReference(
  contour: SketchContour | undefined,
  ref: SketchEntityRef,
): SketchEntityRef {
  if (ref.vertexId === undefined) return ref;
  if (
    typeof ref.vertexId !== "string" ||
    !ref.vertexId.trim() ||
    contour?.type !== "path" ||
    ref.kind !== "point" ||
    ref.control !== undefined ||
    ref.segmentId !== undefined
  )
    throw Error("Invalid stable vertex reference.");
  const indices: number[] = [];
  if (contour.startVertexId === ref.vertexId) indices.push(0);
  contour.segments.forEach((s, index) => {
    if (s.endVertexId !== ref.vertexId) return;
    if (
      indices[0] === 0 &&
      index === contour.segments.length - 1 &&
      sameSketchPoint(s.end, contour.start)
    )
      return;
    indices.push(index + 1);
  });
  if (indices.length !== 1)
    throw Error(`Broken vertex reference: ${ref.vertexId}.`);
  return { ...ref, index: indices[0] };
}

export function identifyVertexReference(
  contour: SketchContour,
  ref: SketchEntityRef,
): SketchEntityRef {
  if (
    contour.type !== "path" ||
    ref.kind !== "point" ||
    ref.control !== undefined
  )
    return ref;
  const id =
    ref.index === 0
      ? contour.startVertexId
      : contour.segments[ref.index! - 1]?.endVertexId;
  return id === undefined ? ref : { ...ref, vertexId: id };
}
