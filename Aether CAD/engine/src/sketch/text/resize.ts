import { validateSketchDrawing, type SketchDrawing } from "../drawing";
import { similarityTransform, transformContour } from "../curves/similarity";
import { solveDrawingConstraints } from "../solver/solve";
import { textOutlineDigest } from "./digest";
import { textFrameContour } from "./frame";
import { adjustTextForFrameWidth } from "./frame-width";

/** Resize around the retained baseline, preserving rotation/flips and glyph
 * proportions. Temporary targets enforce the requested frame, never persist. */
export function resizeSketchTextFrame(
  source: SketchDrawing,
  id: string,
  widthMillimeters: number,
  emSizeMillimeters: number,
): SketchDrawing {
  if (
    ![widthMillimeters, emSizeMillimeters].every(
      (v) => Number.isFinite(v) && v > 0,
    )
  )
    throw Error("Text frame width and height must be positive.");
  validateSketchDrawing(source);
  const next = structuredClone(source),
    item = next.textItems?.find((item) => item.id === id);
  if (!item?.frameContourId) throw Error("Select a retained text frame.");
  const indices = item.contourIds.map((id) =>
    next.contours.findIndex((c) => c.id === id),
  );
  if (
    indices.some((i) => i < 0) ||
    textOutlineDigest(indices.map((i) => next.contours[i])) !==
      item.outlineDigest
  )
    throw Error(
      "Text geometry has been manually edited. Resolve those edits before resizing retained text.",
    );
  const previousScaledWidth =
    (item.frameWidthMillimeters! * emSizeMillimeters) / item.emSizeMillimeters;
  const transform = similarityTransform(
    item.originMillimeters,
    [0, 0],
    0,
    emSizeMillimeters / item.emSizeMillimeters,
  );
  for (const index of indices)
    next.contours[index] = transformContour(next.contours[index], transform);
  item.emSizeMillimeters = emSizeMillimeters;
  item.frameWidthMillimeters = widthMillimeters;
  adjustTextForFrameWidth(next, item, previousScaledWidth);
  const contour = next.contours.findIndex((c) => c.id === item.frameContourId),
    old = next.contours[contour],
    frame = textFrameContour(item);
  if (old.type !== "path" || frame.type !== "path")
    throw Error("Invalid text frame.");
  next.contours[contour] = {
    ...old,
    start: frame.start,
    segments: old.segments.map((segment, i) => ({
      ...segment,
      end: frame.segments[i].end,
    })),
  };
  item.outlineDigest = textOutlineDigest(indices.map((i) => next.contours[i]));
  const temporary = new Set<string>(),
    used = new Set(next.constraints?.map((c) => c.id));
  next.constraints ??= [];
  for (const [index, point] of [
    frame.start,
    frame.segments[0].end,
    frame.segments[1].end,
  ].entries()) {
    let constraintId = `text-resize-${index}`;
    while (used.has(constraintId)) constraintId += "-";
    used.add(constraintId);
    temporary.add(constraintId);
    next.constraints.push({
      id: constraintId,
      kind: "fix",
      a: { contour, kind: "point", index },
      point,
    });
  }
  const solved = solveDrawingConstraints(next);
  solved.constraints =
    source.constraints === undefined
      ? undefined
      : solved.constraints?.filter((c) => !temporary.has(c.id));
  validateSketchDrawing(solved);
  return solved;
}
