import { referencedContour } from "./projected-context";
import {
  resolveSegmentReference,
  identifySegmentReference,
} from "./segment-reference";
import type { SketchDrawing, SketchContour } from "../drawing";
import type { SketchEntityRef } from "./types";
import { resolve } from "./entities";
/** Project referenced source geometry without inserting duplicate source contours. */
export function patternSourceContour(
  d: SketchDrawing,
  ref: SketchEntityRef,
): SketchContour {
  const source = referencedContour(d, ref);
  ref = resolveSegmentReference(source, ref);
  if (
    ref.kind === "curve" &&
    source?.type === "path" &&
    Number.isInteger(ref.index) &&
    ref.index! >= 0 &&
    source.segments[ref.index!]
  )
    return {
      type: "path",
      start:
        ref.index === 0
          ? [...source.start]
          : [...source.segments[ref.index! - 1].end],
      segments: [structuredClone(source.segments[ref.index!])],
      ...(source.sourceLayer !== undefined
        ? { sourceLayer: source.sourceLayer }
        : {}),
      construction: source.construction,
    };
  const e = resolve(d, ref);
  if (ref.kind === "contour" && source) return source;
  if (ref.kind === "circle" && source?.type === "circle") return source;
  if (e.point)
    return {
      type: "path",
      start: [...e.point],
      segments: [],
      construction: true,
    };
  if (
    source?.type !== "path" ||
    ref.index === undefined ||
    !source.segments[ref.index]
  )
    throw Error("Select a sketch contour, edge or point.");
  return {
    type: "path",
    start:
      ref.index === 0
        ? [...source.start]
        : [...source.segments[ref.index - 1].end],
    segments: [structuredClone(source.segments[ref.index])],
    ...(source.sourceLayer !== undefined
      ? { sourceLayer: source.sourceLayer }
      : {}),
    construction: source.construction,
  };
}
export function mirrorAxisConflicts(
  source: SketchEntityRef,
  axis: SketchEntityRef,
  targetContour?: number,
  drawing?: SketchDrawing,
): boolean {
  if (drawing) {
    source = resolveSegmentReference(
      referencedContour(drawing, source),
      source,
    );
    axis = resolveSegmentReference(referencedContour(drawing, axis), axis);
  }
  if (axis.projectedContourId === undefined && axis.contour === targetContour)
    return true;
  return (
    (axis.projectedContourId ?? axis.contour) ===
      (source.projectedContourId ?? source.contour) &&
    (source.kind === "contour" ||
      (source.kind !== "point" &&
        (source.segmentId !== undefined && axis.segmentId !== undefined
          ? source.segmentId === axis.segmentId
          : source.index === axis.index)))
  );
}
export function patternSourceEntities(
  d: SketchDrawing,
): { ref: SketchEntityRef; label: string }[] {
  return d.contours.flatMap<{ ref: SketchEntityRef; label: string }>(
    (c, contour) => {
      if (c.type === "circle")
        return [
          {
            ref: { contour, kind: "circle" as const },
            label: `${contour + 1}: Circle`,
          },
        ];
      if (!c.segments.length)
        return [
          {
            ref: { contour, kind: "point" as const, index: 0 },
            label: `${contour + 1}: Point`,
          },
        ];
      return c.segments.map((s, index) => ({
        ref: identifySegmentReference(c, {
          contour,
          index,
          kind: s.type === "bezier" ? ("curve" as const) : s.type,
          ...(s.type === "bezier" ? { parameter: 0 } : {}),
        }),
        label: `${contour + 1}: ${s.type} ${index + 1}`,
      }));
    },
  );
}

export const mirrorSourceEntities = patternSourceEntities;
