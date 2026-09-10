import type { SketchContour } from "../drawing";
import type { TrimSegmentOrigin } from "./trim-references";

/** Assign identities from retained source intervals, never from shifted positions. */
export function identifyTrimmedPaths(
  source: Extract<SketchContour, { type: "path" }>,
  paths: SketchContour[],
  layout: TrimSegmentOrigin[][],
): void {
  const vertex = (index: number) =>
    index === 0 ? source.startVertexId : source.segments[index - 1].endVertexId;
  const identified =
    source.startVertexId !== undefined ||
    source.segments.some((s) => s.endVertexId !== undefined);
  paths.forEach((path, offset) => {
    if (path.type !== "path") return;
    const entries = layout[offset],
      first = entries[0];
    delete path.startVertexId;
    const startId = first.keepStart
      ? vertex(first.segment)
      : identified
        ? crypto.randomUUID()
        : undefined;
    if (startId !== undefined) path.startVertexId = startId;
    entries.forEach((origin, index) => {
      const segment = path.segments[index],
        original = source.segments[origin.segment];
      delete segment.id;
      delete segment.endVertexId;
      if (original.id !== undefined)
        segment.id = origin.whole ? original.id : crypto.randomUUID();
      const endId = origin.keepEnd
        ? original.endVertexId
        : identified
          ? crypto.randomUUID()
          : undefined;
      if (endId !== undefined) segment.endVertexId = endId;
    });
  });
}
