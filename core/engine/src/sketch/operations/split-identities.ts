import type { SketchSegment } from "../drawing";

/** A split creates two new edges but preserves the original terminal vertex.
 * External whole-edge links must be relinked; they must not silently shrink. */
export function identifySplitSegments(
  original: SketchSegment,
  pieces: [SketchSegment, SketchSegment],
): [SketchSegment, SketchSegment] {
  for (const piece of pieces) {
    delete piece.id;
    delete piece.endVertexId;
  }
  if (original.id !== undefined) {
    pieces[0].id = crypto.randomUUID();
    pieces[1].id = crypto.randomUUID();
  }
  if (original.endVertexId !== undefined) {
    pieces[0].endVertexId = crypto.randomUUID();
    pieces[1].endVertexId = original.endVertexId;
  }
  return pieces;
}
