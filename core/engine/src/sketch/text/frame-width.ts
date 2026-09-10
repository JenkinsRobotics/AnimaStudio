import type { SketchDrawing } from "../drawing";
import type { SketchTextItem } from "./records";
import { textFramePlacement } from "./placement";
import { similarityTransform, transformContour } from "../curves/similarity";

/** After uniform scaling, an independent width change moves horizontally
 * reflected letters with the frame's reflection center; letter size stays fixed. */
export function adjustTextForFrameWidth(
  drawing: SketchDrawing,
  item: SketchTextItem,
  previousScaledWidth: number,
) {
  if (!item.flipAboutFrame || !item.flipHorizontal) return;
  const delta = item.frameWidthMillimeters! - previousScaledWidth;
  const axes = textFramePlacement(item),
    transform = similarityTransform(
      [0, 0],
      [axes.a * delta, axes.c * delta],
      0,
    );
  for (const id of item.contourIds) {
    if (id === item.frameContourId) continue;
    const index = drawing.contours.findIndex((c) => c.id === id);
    if (index >= 0)
      drawing.contours[index] = transformContour(
        drawing.contours[index],
        transform,
      );
  }
}
