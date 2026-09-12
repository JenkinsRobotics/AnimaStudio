import type { SketchDrawing } from "../drawing";
import type { SketchEntityRef } from "../solver/types";
import { referencedContour } from "../solver/projected-context";
import {
  identifySegmentReference,
  resolveSegmentReference,
} from "../solver/segment-reference";
import { patternSourceContour } from "../solver/pattern-source";

/** Assign selected authored edges on a caller-owned candidate only. Whole
 * contours/points retain their existing reference contract; projected geometry
 * is source-owned and must never receive locally invented identities. */
export function identifySourceEdges(
  candidate: SketchDrawing,
  refs: readonly SketchEntityRef[],
): SketchEntityRef[] {
  const used = new Set<string>();
  for (const c of [
    ...candidate.contours,
    ...(candidate.projectionContext ?? []),
  ]) {
    if (c.type === "path") for (const s of c.segments) if (s.id) used.add(s.id);
  }
  let serial = 1;
  return refs.map((input) => {
    const contour = referencedContour(candidate, input);
    const ref = resolveSegmentReference(contour, input);
    // Validate the complete source selection before assigning it an identity.
    try {
      patternSourceContour(candidate, ref);
    } catch (error) {
      throw Error(
        `Select a compatible source edge. ${(error as Error).message}`,
      );
    }
    if (
      !contour ||
      contour.type !== "path" ||
      ref.projectedContourId !== undefined ||
      ref.kind === "contour" ||
      (ref.kind === "point" && ref.control === undefined)
    )
      return { ...ref };
    const segment = contour.segments[ref.index!];
    if (!segment) throw Error("Select an existing source edge.");
    if (segment.id === undefined) {
      while (used.has(`source-edge-${serial}`)) serial++;
      segment.id = `source-edge-${serial++}`;
      used.add(segment.id);
    }
    return identifySegmentReference(contour, ref);
  });
}
