import { identifySourceEdges } from "./identify-source-edges";
import {
  validateSketchDrawing,
  type SketchDrawing,
  type SketchContour,
} from "../drawing";
import type { SketchEntityRef } from "../solver/types";
import { offsetSketchContour } from "../curves/offset";
import { appendOffsetRelation } from "./offset-relations";
/** Offset selected edges without copying the rest of their source contours. */
export function offsetSketchEntities(
  source: SketchDrawing,
  refs: SketchEntityRef[],
  distance: number,
): SketchDrawing {
  if (!refs.length) throw Error("Select edges to offset.");
  const next = structuredClone(source),
    seen = new Set<string>();
  let driver: string | undefined;
  for (const ref of identifySourceEdges(next, refs)) {
    const c = next.contours[ref.contour];
    const key = `${ref.contour}:${ref.kind}:${ref.index ?? 0}`;
    if (seen.has(key)) continue;
    seen.add(key);
    let edge: SketchContour;
    if (c?.type === "circle" && ref.kind === "circle") edge = c;
    else if (
      c?.type === "path" &&
      (ref.kind === "line" || ref.kind === "arc") &&
      Number.isInteger(ref.index) &&
      ref.index! >= 0 &&
      c.segments[ref.index!]?.type === ref.kind
    ) {
      edge = {
        type: "path",
        start: ref.index === 0 ? c.start : c.segments[ref.index! - 1].end,
        segments: [c.segments[ref.index!]],
        ...(c.sourceLayer !== undefined ? { sourceLayer: c.sourceLayer } : {}),
        ...(c.construction ? { construction: true } : {}),
      };
    } else throw Error("Select a line, circular arc or circle to offset.");
    const contour = next.contours.length;
    next.contours.push(offsetSketchContour(edge, distance));
    const id = appendOffsetRelation(
      next,
      { ...ref },
      {
        contour,
        kind: ref.kind,
        ...(ref.kind !== "circle" ? { index: 0 } : {}),
      },
      distance,
      driver,
    );
    driver ??= id;
  }
  validateSketchDrawing(next);
  return next;
}
