import { identifyProfileContours } from "./profile-contour-identities";
import { identifySketchContour } from "./identify-sketch-contour";
import { validatePartDocument, type PartDocument } from "./part-document";
import { resolveProfileDrawing } from "./profile-projection";
/** Assign identity only when a contour becomes externally referenced. IDs are
 * scoped to its source profile, so coordinate edits/reordering cannot retarget
 * a link. The returned document and reference must be committed together. */
export function referenceProfileContour(
  source: PartDocument,
  featureId: string,
  contourIndex: number,
  createId: () => string = () => crypto.randomUUID(),
) {
  const document = structuredClone(source),
    feature = document.features.find((f) => f.id === featureId);
  if (feature?.type !== "profile" || feature.suppressed)
    throw Error("Select an active source sketch.");
  const drawing = resolveProfileDrawing(document.features, featureId);
  if (
    !Number.isInteger(contourIndex) ||
    contourIndex < 0 ||
    !drawing.contours[contourIndex]
  )
    throw Error("Select an existing source contour.");
  if (feature.profile.type === "projection") {
    const identified = identifyProfileContours(source, featureId, createId);
    const contour = resolveProfileDrawing(identified.features, featureId)
      .contours[contourIndex];
    return {
      document: identified,
      reference: { sourceFeatureId: featureId, sourceContourId: contour.id! },
    };
  }
  const contour = drawing.contours[contourIndex];
  identifySketchContour(contour, createId);
  feature.profile = drawing;
  const end = document.features.findIndex((f) => f.id === featureId) + 1;
  validatePartDocument({
    ...document,
    features: document.features.slice(0, end),
    rollbackIndex: undefined,
  });
  return {
    document,
    reference: { sourceFeatureId: featureId, sourceContourId: contour.id },
  };
}
