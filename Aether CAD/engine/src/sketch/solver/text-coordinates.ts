import type { SketchDrawing, SketchPoint } from "../drawing";
import { similarityTransform, transformContour } from "../curves/similarity";
import { textOutlineDigest } from "../text/digest";
import { textFrameContour } from "../text/frame";
import { adjustTextForFrameWidth } from "../text/frame-width";
/** Intact retained letters have one similarity transform, not independently
 * deformable glyph vertices. These coordinates are transient solver state. */
export function textSimilarityCoordinates(
  drawing: SketchDrawing,
  options: { fixed?: ReadonlySet<number>; used?: ReadonlySet<number> } = {},
) {
  const covered = new Set<number>(),
    coordinates: { get: () => number; set: (value: number) => void }[] = [],
    finish: (() => void)[] = [];
  for (const item of drawing.textItems ?? []) {
    const indices = item.contourIds.map((id) =>
      drawing.contours.findIndex((c) => c.id === id),
    );
    if (
      indices.some((i) => i < 0) ||
      textOutlineDigest(indices.map((i) => drawing.contours[i])) !==
        item.outlineDigest
    )
      continue;
    indices.forEach((i) => covered.add(i));
    if (
      indices.some((i) => options.fixed?.has(i)) ||
      (options.used && !indices.some((i) => options.used!.has(i)))
    )
      continue;
    const original = indices.map((i) => structuredClone(drawing.contours[i])),
      origin: SketchPoint = [...item.originMillimeters],
      em = item.emSizeMillimeters,
      rotation = item.rotationDegrees,
      frameWidth = item.frameWidthMillimeters,
      frameIndex = drawing.contours.findIndex(
        (c) => c.id === item.frameContourId,
      );
    const state = item.frameContourId ? [0, 0, 0, 0, 0] : [0, 0, 0, 0]; // X/Y, rotation, log scale, optional log frame width
    const render = () => {
      const scale = Math.exp(state[3]),
        degrees = (state[2] * 180) / Math.PI,
        transform = similarityTransform(
          origin,
          [state[0], state[1]],
          degrees,
          scale,
        );
      indices.forEach((index, i) => {
        drawing.contours[index] = transformContour(original[i], transform);
      });
      item.originMillimeters = [origin[0] + state[0], origin[1] + state[1]];
      item.emSizeMillimeters = em * scale;
      item.rotationDegrees = rotation + degrees;
      if (frameWidth !== undefined && frameIndex >= 0) {
        item.frameWidthMillimeters = frameWidth * scale * Math.exp(state[4]);
        adjustTextForFrameWidth(drawing, item, frameWidth * scale);
        // Preserve stable segment/vertex identities assigned by sketch selection.
        const frame = textFrameContour(item),
          existing = drawing.contours[frameIndex];
        if (frame.type === "path" && existing.type === "path") {
          frame.startVertexId = existing.startVertexId;
          frame.segments.forEach((segment, i) => {
            segment.id = existing.segments[i].id;
            segment.endVertexId = existing.segments[i].endVertexId;
          });
        }
        drawing.contours[frameIndex] = frame;
      }
    };
    state.forEach((_, i) =>
      coordinates.push({
        get: () => state[i],
        set: (value) => {
          state[i] = value;
          render();
        },
      }),
    );
    finish.push(() => {
      item.outlineDigest = textOutlineDigest(
        indices.map((i) => drawing.contours[i]),
      );
    });
  }
  return {
    covered,
    coordinates,
    finish() {
      finish.forEach((commit) => commit());
      return drawing;
    },
  };
}
