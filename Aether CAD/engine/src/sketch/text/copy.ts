import { transformRetainedTextItem } from "./transform";
import type { SketchDrawing } from "../drawing";
import { type SketchTransform } from "../curves/similarity";
import { textOutlineDigest } from "./digest";

/** Attach metadata only when an entire intact text group was copied. Partial or
 * manually modified selections remain ordinary curves, preserving their shape. */
export function copyRetainedText(
  source: SketchDrawing,
  target: SketchDrawing,
  copiedIndices: ReadonlyMap<number, number>,
  transform: SketchTransform,
): void {
  for (const item of source.textItems ?? []) {
    const indices = item.contourIds.map((id) =>
      source.contours.findIndex((c) => c.id === id),
    );
    if (indices.some((index) => index < 0 || !copiedIndices.has(index)))
      continue;
    if (
      textOutlineDigest(indices.map((index) => source.contours[index])) !==
      item.outlineDigest
    )
      continue;
    const contours = indices.map(
      (index) => target.contours[copiedIndices.get(index)!],
    );
    const frameIndex =
      item.frameContourId === undefined
        ? -1
        : item.contourIds.indexOf(item.frameContourId);
    (target.textItems ??= []).push({
      ...transformRetainedTextItem(item,contours,transform),
      id: `text-${crypto.randomUUID()}`,
      contourIds: contours.map((c) => c.id!),
      ...(frameIndex >= 0 ? { frameContourId: contours[frameIndex].id } : {}),
    });
  }
}
