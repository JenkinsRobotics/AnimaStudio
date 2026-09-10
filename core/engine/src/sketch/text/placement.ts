import type { SketchPoint } from "../drawing";
import { textFrameHeight } from "./height";
import type { SketchTransform } from "../curves/similarity";
export interface TextOrientation {
  originMillimeters?: SketchPoint;
  rotationDegrees?: number;
  flipHorizontal?: boolean;
  flipVertical?: boolean;
  flipAboutFrame?: boolean;
  /** Reflect the entire local coordinate system, including construction frame. */
  placementReflected?: boolean;
  frameWidthMillimeters?: number;
  emSizeMillimeters?: number;
  fontAscenderRatio?: number;
}
/** Reflect in local baseline axes, then rotate and translate. Scale is positive;
 * the same transform handles normalized UI previews and full-size font paths. */
export function textPlacementTransform(
  options: TextOrientation,
  scale = 1,
): SketchTransform {
  const origin = options.originMillimeters ?? [0, 0],
    rotation = options.rotationDegrees ?? 0;
  if (
    !Array.isArray(origin) ||
    origin.length !== 2 ||
    !origin.every(Number.isFinite) ||
    !Number.isFinite(rotation) ||
    !Number.isFinite(scale) ||
    scale <= 0
  )
    throw Error("Text placement must be finite with positive scale.");
  for (const flip of [
    options.flipHorizontal,
    options.flipVertical,
    options.flipAboutFrame,
    options.placementReflected,
  ])
    if (flip !== undefined && typeof flip !== "boolean")
      throw Error("Text flip settings must be boolean.");
  if (
    options.fontAscenderRatio !== undefined &&
    (!Number.isFinite(options.fontAscenderRatio) ||
      options.fontAscenderRatio <= 0)
  )
    throw Error("Font ascender ratio must be positive.");
  if (
    options.flipAboutFrame &&
    ![options.frameWidthMillimeters, options.emSizeMillimeters].every(
      (v) => typeof v === "number" && Number.isFinite(v) && v > 0,
    )
  )
    throw Error("Frame-centered text needs a positive frame width and height.");
  const angle = (rotation * Math.PI) / 180,
    cosine = Math.cos(angle),
    sine = Math.sin(angle),
    x = (options.flipHorizontal ? -1 : 1) * scale,
    handedness = options.placementReflected ? -1 : 1,
    y = (options.flipVertical ? -1 : 1) * scale * handedness,
    shiftX =
      options.flipAboutFrame && options.flipHorizontal
        ? options.frameWidthMillimeters!
        : 0,
    shiftY =
      options.flipAboutFrame && options.flipVertical
        ? textFrameHeight({
            emSizeMillimeters: options.emSizeMillimeters!,
            fontAscenderRatio: options.fontAscenderRatio,
          })
        : 0;
  return {
    a: cosine * x,
    b: -sine * y,
    c: sine * x,
    d: cosine * y,
    tx: origin[0] + cosine * shiftX - sine * shiftY * handedness,
    ty: origin[1] + sine * shiftX + cosine * shiftY * handedness,
  };
}
/** Frame-centered flips change letters, never the construction frame axes. */
export function textFramePlacement(options: TextOrientation): SketchTransform {
  return textPlacementTransform(
    options.flipAboutFrame
      ? {
          ...options,
          flipAboutFrame: false,
          flipHorizontal: false,
          flipVertical: false,
        }
      : options,
  );
}
