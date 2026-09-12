import {
  type SketchDrawing,
  type SketchPoint,
  type SketchSegment,
} from "../drawing";
import type { SketchEntityRef } from "../drawing-constraints";
import { preservesLineLocus } from "./split-relations";
/** Shared topology edit for straight-corner fillets/chamfers; caller owns dimensions and validation. */
export function breakLineCorner(
  source: SketchDrawing,
  contourIndex: number,
  vertex: number,
  a: SketchPoint,
  b: SketchPoint,
  bridge: SketchSegment,
) {
  const path = source.contours[contourIndex];
  if (path.type !== "path") throw Error("Expected path.");
  const count = path.segments.length,
    incoming = vertex === 0 ? count - 1 : vertex - 1,
    outgoing = vertex;
  const corner = vertex === 0 ? path.start : path.segments[vertex - 1].end;
  const next = structuredClone(source),
    result = next.contours[contourIndex];
  if (result.type !== "path") throw Error("Expected path.");
  result.segments[incoming].end = a;
  const arcIndex = vertex === 0 ? count : vertex;
  if (vertex === 0) {
    result.start = b;
    result.segments.push(bridge);
  } else result.segments.splice(vertex, 0, bridge);
  const sharpIndex = next.contours.length;
  next.contours.push({
    type: "path",
    start: [...corner],
    segments: [],
    construction: true,
  });
  const sharp: SketchEntityRef = {
    contour: sharpIndex,
    kind: "point",
    index: 0,
  };
  const map = (ref: SketchEntityRef): SketchEntityRef => {
    if (ref.contour !== contourIndex) return { ...ref };
    if (
      ref.kind === "point" &&
      ref.control === undefined &&
      (ref.index === vertex || (vertex === 0 && ref.index === count))
    )
      return { ...sharp };
    return {
      ...ref,
      index:
        vertex !== 0 &&
        ref.index !== undefined &&
        (ref.kind === "point" && ref.control === undefined
          ? ref.index > vertex
          : ref.index >= vertex)
          ? ref.index + 1
          : ref.index,
    };
  };
  next.constraints = (source.constraints ?? []).map((constraint) => {
    const touches = (ref: SketchEntityRef) =>
      ref.contour === contourIndex &&
      ref.kind === "line" &&
      (ref.index === incoming || ref.index === outgoing);
    if (constraint.kind === "length" && touches(constraint.a)) {
      const index = constraint.a.index!;
      return {
        ...constraint,
        kind: "distance" as const,
        a: map({ contour: contourIndex, kind: "point", index }),
        b: map({ contour: contourIndex, kind: "point", index: index + 1 }),
      };
    }
    if (
      (touches(constraint.a) || (constraint.b && touches(constraint.b)) || (constraint.axis && touches(constraint.axis))) &&
      !preservesLineLocus(constraint)
    )
      throw new Error(
        `Constraint "${constraint.id}" needs fillet remapping. Its geometry was not changed.`,
      );
    return {
      ...constraint,
      a: map(constraint.a),
      ...(constraint.b ? { b: map(constraint.b) } : {}),
      ...(constraint.axis ? { axis: map(constraint.axis) } : {}),
    };
  });
  const arc: SketchEntityRef = {
    contour: contourIndex,
    kind: bridge.type === "arc" ? "arc" : "line",
    index: arcIndex,
  };
  const first = map({ contour: contourIndex, kind: "line", index: incoming }),
    second = map({ contour: contourIndex, kind: "line", index: outgoing });

  return { next, sharp, bridge: arc, first, second };
}
