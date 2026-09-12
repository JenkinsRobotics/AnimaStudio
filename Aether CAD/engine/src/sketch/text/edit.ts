import {
  resolveSketchTextExpression,
  type TextExpressionVariables,
} from "./expression";
import { textOutlineDigest as digest } from "./digest";
import { normalizeSketchText } from "./content";
import { constrainNewTextBaseline } from "./baseline";
import { sketchTextFontAscenderRatio } from "./font";
import {
  validateSketchDrawing,
  type SketchDrawing,
  type SketchPoint,
} from "../drawing";
import { deleteSketchContour } from "../operations/delete";
import { sketchTextOutline } from "./outline";
import { decodeTextFont, encodeTextFont } from "./records";
import { textFrameContour } from "./frame";
import { solveDrawingConstraints } from "../solver/solve";

export async function sketchTextEditState(
  drawing: SketchDrawing,
  id: string,
): Promise<"editable" | "modified" | "constrained"> {
  const item = drawing.textItems?.find((item) => item.id === id);
  if (!item) throw Error("Select an existing text item.");
  const indices = item.contourIds.map((id) =>
    drawing.contours.findIndex((c) => c.id === id),
  );
  if (
    indices.some((i) => i < 0) ||
    (await digest(indices.map((i) => drawing.contours[i]))) !==
      item.outlineDigest
  )
    return "modified";
  if (
    drawing.constraints?.some((c) =>
      [c.a, c.b, c.axis].some((ref) => ref && indices.includes(ref.contour)),
    )
  )
    return "constrained";
  return "editable";
}
/** Explicit regeneration preserves unrelated contours/references. Manual outline
 * edits or letter constraints must be resolved by the author. Stable frame
 * constraints survive regeneration and drive the returned geometry. */
export async function putSketchText(
  source: SketchDrawing,
  options: {
    id?: string;
    text: string;
    /** Undefined retains the saved expression; null switches to literal text. */
    expression?: string | null;
    expressionVariables?: TextExpressionVariables;
    fontBytes?: ArrayBuffer;
    emSizeMillimeters: number;
    originMillimeters: SketchPoint;
    rotationDegrees?: number;
    flipHorizontal?: boolean;
    flipVertical?: boolean;
    flipAboutFrame?: boolean;
    placementReflected?: boolean;
    frameWidthMillimeters?: number;
    /** Requested baseline-to-ascender height. Null explicitly selects legacy em sizing. */
    textHeightMillimeters?: number | null;
  },
): Promise<SketchDrawing> {
  let next = structuredClone(source);
  validateSketchDrawing(next);
  const prior = options.id
    ? next.textItems?.find((item) => item.id === options.id)
    : undefined;
  if (options.id && !prior) throw Error("Select an existing text item.");
  const expression =
    options.expression === undefined
      ? prior?.expression
      : (options.expression ?? undefined);
  const text =
    expression === undefined
      ? normalizeSketchText(options.text)
      : resolveSketchTextExpression(expression, options.expressionVariables);
  if (prior) {
    const state = await sketchTextEditState(next, prior.id);
    const letters = prior.contourIds
      .filter((id) => id !== prior.frameContourId)
      .map((id) => next.contours.findIndex((c) => c.id === id));
    const constrainedLetters = next.constraints?.some((c) =>
      [c.a, c.b, c.axis].some((ref) => ref && letters.includes(ref.contour)),
    );
    if (state === "modified" || constrainedLetters)
      throw Error(
        state === "modified"
          ? "Text outlines have been edited. Detach the text item before continuing with manual curves."
          : "Text outlines have constraints. Resolve them before regenerating text.",
      );
  }
  const font = options.fontBytes ?? (prior ? decodeTextFont(prior) : undefined);
  if (!font) throw Error("Select a font for the text item.");
  const useAscender =
    options.textHeightMillimeters != null ||
    (options.textHeightMillimeters === undefined &&
      prior?.fontAscenderRatio !== undefined);
  const fontAscenderRatio = useAscender
    ? await sketchTextFontAscenderRatio(font)
    : undefined;
  const emSizeMillimeters =
    options.textHeightMillimeters != null
      ? options.textHeightMillimeters / fontAscenderRatio!
      : options.emSizeMillimeters;
  const frameWidthMillimeters =
    options.frameWidthMillimeters ?? prior?.frameWidthMillimeters;
  const flipAboutFrame =
    options.flipAboutFrame ??
    (prior
      ? (prior.flipAboutFrame ?? false)
      : frameWidthMillimeters !== undefined);
  const placementReflected =
    options.placementReflected ?? prior?.placementReflected;
  const generated = await sketchTextOutline(font, text, {
    ...options,
    emSizeMillimeters,
    fontAscenderRatio,
    frameWidthMillimeters,
    flipAboutFrame,
    placementReflected,
  });
  const id = prior?.id ?? `text-${crypto.randomUUID()}`;
  for (const contour of generated.contours)
    contour.id = `text-contour-${crypto.randomUUID()}`;
  if (prior) {
    const removed = prior.contourIds
      .filter((id) => id !== prior.frameContourId)
      .map((id) => next.contours.findIndex((c) => c.id === id))
      .sort((a, b) => b - a);
    for (const index of removed) next = deleteSketchContour(next, index);
  }
  next.contours.push(...generated.contours);
  next.textItems = [
    ...(next.textItems ?? []).filter((item) => item.id !== id),
    {
      id,
      text,
      ...(expression !== undefined ? { expression } : {}),
      fontBase64: encodeTextFont(font),
      emSizeMillimeters,
      ...(fontAscenderRatio !== undefined ? { fontAscenderRatio } : {}),
      originMillimeters: [...options.originMillimeters],
      rotationDegrees: options.rotationDegrees ?? 0,
      flipHorizontal: options.flipHorizontal ?? false,
      flipVertical: options.flipVertical ?? false,
      flipAboutFrame,
      ...(placementReflected !== undefined ? { placementReflected } : {}),
      contourIds: generated.contours.map((c) => c.id!),
      outlineDigest: await digest(generated.contours),
      ...(frameWidthMillimeters !== undefined
        ? {
            frameContourId:
              prior?.frameContourId ?? `text-frame-${crypto.randomUUID()}`,
            frameWidthMillimeters,
          }
        : {}),
    },
  ];
  const item = next.textItems.at(-1)!;
  if (item.frameContourId) {
    const index = next.contours.findIndex((c) => c.id === item.frameContourId);
    const previous = next.contours[index],
      frame = textFrameContour(item);
    if (previous?.type === "path" && frame.type === "path") {
      frame.startVertexId = previous.startVertexId;
      frame.segments.forEach((segment, i) => {
        segment.id = previous.segments[i].id;
        segment.endVertexId = previous.segments[i].endVertexId;
      });
    }
    if (index >= 0) next.contours[index] = frame;
    else next.contours.push(frame);
    item.contourIds.push(item.frameContourId);
    item.outlineDigest = digest([...generated.contours, frame]);
  }
  if (!prior?.frameContourId && item.frameContourId)
    constrainNewTextBaseline(next, id);
  validateSketchDrawing(next);
  return solveDrawingConstraints(next);
}
/** Convert a retained text item to ordinary curves without changing geometry. */
export function detachSketchText(
  source: SketchDrawing,
  id: string,
): SketchDrawing {
  validateSketchDrawing(source);
  if (!source.textItems?.some((item) => item.id === id))
    throw Error("Select an existing text item.");
  const next = structuredClone(source);
  next.textItems = next.textItems?.filter((item) => item.id !== id);
  return next;
}
