import {
  resolveVertexReference,
  identifyVertexReference,
} from "./vertex-reference";
import type { SketchContour } from "../drawing";
import type { SketchEntityRef } from "./types";

/** An identified edge must never fall back to a now-unrelated numeric index. */
export function resolveSegmentReference(
  contour: SketchContour | undefined,
  ref: SketchEntityRef,
): SketchEntityRef {
  ref = resolveVertexReference(contour, ref);
  if (ref.segmentId === undefined) return ref;
  if (
    typeof ref.segmentId !== "string" ||
    !ref.segmentId.trim() ||
    contour?.type !== "path" ||
    (ref.kind === "point" && ref.control === undefined)
  )
    throw Error("Invalid stable segment reference.");
  const matches = contour.segments
    .map((s, index) => ({ s, index }))
    .filter(({ s }) => s.id === ref.segmentId);
  if (matches.length !== 1)
    throw Error(`Broken segment reference: ${ref.segmentId}.`);
  return { ...ref, index: matches[0].index };
}

/** Capture subentity identity when selecting projected geometry. */
export function identifySegmentReference(
  contour: SketchContour,
  ref: SketchEntityRef,
): SketchEntityRef {
  ref = identifyVertexReference(contour, ref);
  if (
    contour.type !== "path" ||
    ref.kind === "contour" ||
    (ref.kind === "point" && ref.control === undefined)
  )
    return ref;
  const id = contour.segments[ref.index!]?.id;
  return id === undefined ? ref : { ...ref, segmentId: id };
}
