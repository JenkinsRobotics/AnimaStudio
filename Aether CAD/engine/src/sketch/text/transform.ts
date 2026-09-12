import type { SketchContour } from "../drawing";
import type { SketchTextItem } from "./records";
import { transformPoint, type SketchTransform } from "../curves/similarity";
import { textOutlineDigest } from "./digest";

/** Compose a whole-group similarity while preserving text identity and local
 * frame topology. Callers transform the owned contours before updating metadata. */
export function transformRetainedTextItem(
  item: SketchTextItem,
  contours: SketchContour[],
  transform: SketchTransform,
): SketchTextItem {
  const scale = Math.hypot(transform.a, transform.c),
    reflected = transform.a * transform.d - transform.b * transform.c < 0,
    angle = item.rotationDegrees * Math.PI / 180,
    x = Math.cos(angle), y = Math.sin(angle);
  return {
    ...structuredClone(item),
    originMillimeters: transformPoint(item.originMillimeters, transform),
    rotationDegrees: Math.atan2(transform.c*x+transform.d*y,transform.a*x+transform.b*y)*180/Math.PI,
    placementReflected: reflected ? !item.placementReflected : item.placementReflected,
    emSizeMillimeters: item.emSizeMillimeters*scale,
    ...(item.frameWidthMillimeters===undefined ? {} : {frameWidthMillimeters:item.frameWidthMillimeters*scale}),
    outlineDigest:textOutlineDigest(contours),
  };
}
