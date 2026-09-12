import {
  validateSketchDrawing,
  type SketchContour,
  type SketchDrawing,
} from "../drawing";
import { transformContour } from "../curves/similarity";
import { textPlacementTransform, textFramePlacement } from "./placement";
import { textOutlineDigest } from "./digest";
import type { SketchTextItem } from "./records";
import { constrainNewTextBaseline } from "./baseline";
import { textFrameHeight } from "./height";

/** A stable construction rectangle in the text's local baseline coordinates.
 * Width is independent of glyph size; height is the em size, not cap height. */
export function textFrameContour(
  item: Pick<
    SketchTextItem,
    | "frameWidthMillimeters"
    | "frameContourId"
    | "emSizeMillimeters"
    | "originMillimeters"
    | "rotationDegrees"
    | "flipHorizontal"
    | "flipVertical"
    | "flipAboutFrame"
    | "placementReflected"
    | "fontAscenderRatio"
  >,
): SketchContour {
  const width = item.frameWidthMillimeters!,
    height = textFrameHeight(item);
  return transformContour(
    {
      type: "path",
      id: item.frameContourId,
      construction: true,
      start: [0, 0],
      segments: [
        { type: "line", end: [width, 0] },
        { type: "line", end: [width, height] },
        { type: "line", end: [0, height] },
        { type: "line", end: [0, 0] },
      ],
    },
    textFramePlacement(item),
  );
}

/** Attach a selectable/dimensionable frame without changing generated letters. */
export function attachSketchTextFrame(
  source: SketchDrawing,
  id: string,
  widthMillimeters?: number,
): SketchDrawing {
  validateSketchDrawing(source);
  const next = structuredClone(source),
    item = next.textItems?.find((item) => item.id === id);
  if (!item) throw Error("Select an existing text item.");
  const owned = item.contourIds.map((id) =>
    next.contours.find((c) => c.id === id),
  );
  if (
    owned.some((c) => !c) ||
    textOutlineDigest(owned as SketchContour[]) !== item.outlineDigest
  )
    throw Error(
      "Text outlines have been edited. Detach them before adding a frame.",
    );
  if (item.frameContourId) return next;
  // Conservative local X extent of outlines/control points, not a font advance metric.
  const t = textPlacementTransform(item);
  const localX = (p: [number, number]) =>
    t.a * (p[0] - t.tx) + t.c * (p[1] - t.ty);
  let extent = item.emSizeMillimeters * 0.5;
  for (const contour of owned as SketchContour[]) {
    if (contour.type === "circle")
      extent = Math.max(extent, localX(contour.center) + contour.radius);
    else {
      extent = Math.max(extent, localX(contour.start));
      for (const segment of contour.segments) {
        extent = Math.max(extent, localX(segment.end));
        if (segment.type === "bezier")
          for (const p of segment.controls)
            extent = Math.max(extent, localX(p));
      }
    }
  }
  const width = widthMillimeters ?? extent;
  if (!Number.isFinite(width) || width <= 0)
    throw Error("Enter a positive text frame width.");
  item.frameContourId = `text-frame-${crypto.randomUUID()}`;
  item.frameWidthMillimeters = width;
  const frame = textFrameContour(item);
  next.contours.push(frame);
  item.contourIds.push(item.frameContourId);
  item.outlineDigest = textOutlineDigest([
    ...(owned as SketchContour[]),
    frame,
  ]);
  constrainNewTextBaseline(next, id);
  validateSketchDrawing(next);
  return next;
}
