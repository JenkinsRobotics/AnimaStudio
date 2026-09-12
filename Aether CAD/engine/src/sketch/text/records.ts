import { parseExpression } from "../../expressions/parser";
import { textPlacementTransform } from "./placement";
import { normalizeSketchText } from "./content";
import type { SketchDrawing, SketchPoint } from "../drawing";
export interface SketchTextItem {
  id: string;
  text: string;
  /** Authoritative formula; text stores its last successfully generated wording. */
  expression?: string;
  fontBase64: string;
  emSizeMillimeters: number;
  /** Absent preserves legacy em-height frames. Updated from embedded font on authoring. */
  fontAscenderRatio?: number;
  originMillimeters: SketchPoint;
  rotationDegrees: number;
  flipHorizontal?: boolean;
  flipVertical?: boolean;
  /** Missing means legacy baseline-axis flips. New framed text uses its center. */
  flipAboutFrame?: boolean;
  /** Whole-frame handedness; independent of center-based letter flips. */
  placementReflected?: boolean;
  contourIds: string[];
  /** Optional construction rectangle; its height is the font em size. */
  frameContourId?: string;
  frameWidthMillimeters?: number;
  /** Detect manual outline edits before an explicit text regeneration. */
  outlineDigest: string;
}
export function validateTextItems(drawing: SketchDrawing) {
  if (drawing.textItems === undefined) return;
  if (!Array.isArray(drawing.textItems) || drawing.textItems.length > 100)
    throw Error("A sketch supports at most 100 retained text items.");
  const ids = new Set<string>(),
    contours = new Set<string>();
  let fontSize = 0;
  for (const item of drawing.textItems) {
    if (
      !item ||
      typeof item.id !== "string" ||
      !item.id.trim() ||
      item.id.length > 128 ||
      ids.has(item.id)
    )
      throw Error("Text item identities must be unique nonempty strings.");
    ids.add(item.id);
    textPlacementTransform(item);
    normalizeSketchText(item.text);
    if (item.expression !== undefined) parseExpression(item.expression);
    if (
      typeof item.fontBase64 !== "string" ||
      !item.fontBase64.length ||
      item.fontBase64.length > 44739244 ||
      item.fontBase64.length % 4 !== 0 ||
      !/^[A-Za-z0-9+/]*={0,2}$/.test(item.fontBase64)
    )
      throw Error("Invalid retained font data.");
    fontSize += item.fontBase64.length;
    if (fontSize > 89478488)
      throw Error("Retained fonts exceed the sketch's 64 MB font budget.");
    if (
      !Number.isFinite(item.emSizeMillimeters) ||
      item.emSizeMillimeters <= 0 ||
      !Number.isFinite(item.rotationDegrees) ||
      !Array.isArray(item.originMillimeters) ||
      item.originMillimeters.length !== 2 ||
      !item.originMillimeters.every(Number.isFinite)
    )
      throw Error("Invalid retained text size or placement.");
    if (
      !Array.isArray(item.contourIds) ||
      !item.contourIds.length ||
      item.contourIds.length > 1000
    )
      throw Error("Retained text needs generated contour identities.");
    if (
      (item.frameContourId !== undefined ||
        item.frameWidthMillimeters !== undefined) &&
      (typeof item.frameContourId !== "string" ||
        !item.contourIds.includes(item.frameContourId) ||
        !Number.isFinite(item.frameWidthMillimeters) ||
        item.frameWidthMillimeters! <= 0)
    )
      throw Error("Text frames require an owned contour and a positive width.");
    for (const id of item.contourIds) {
      if (
        typeof id !== "string" ||
        !id.trim() ||
        id.length > 128 ||
        contours.has(id)
      )
        throw Error(
          "Text contour identities must be unique across text items.",
        );
      contours.add(id);
    }
    if (
      typeof item.outlineDigest !== "string" ||
      !/^[a-f0-9]{64}$/.test(item.outlineDigest)
    )
      throw Error("Invalid retained text outline digest.");
  }
}
export function decodeTextFont(item: SketchTextItem): ArrayBuffer {
  const bytes = atob(item.fontBase64);
  return Uint8Array.from(bytes, (c) => c.charCodeAt(0)).buffer;
}
export function encodeTextFont(bytes: ArrayBuffer): string {
  const data = new Uint8Array(bytes),
    chunks: string[] = [];
  for (let i = 0; i < data.length; i += 32768)
    chunks.push(String.fromCharCode(...data.subarray(i, i + 32768)));
  return btoa(chunks.join(""));
}
