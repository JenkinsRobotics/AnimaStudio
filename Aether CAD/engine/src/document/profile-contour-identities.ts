import { identifySketchContour } from "./identify-sketch-contour";
import { validatePartDocument, type PartDocument } from "./part-document";
import { resolveProfileDrawing } from "./profile-projection";
import type { SketchDrawing } from "../sketch/drawing";

/** Assign missing identities where geometry is authored, including upstream
 * projection chains. Return one atomic candidate; cancel never changes source. */
export function identifyProfileContours(
  source: PartDocument,
  featureId: string,
  createId: () => string = () => crypto.randomUUID(),
): PartDocument {
  const next = structuredClone(source),
    visited = new Set<string>();
  const identify = (drawing: SketchDrawing) => {
    for (const contour of drawing.contours)
      identifySketchContour(contour, createId);
  };
  const visit = (id: string, depth: number) => {
    if (depth > 256 || visited.has(id))
      throw Error("Invalid projection identity dependency chain.");
    visited.add(id);
    const feature = next.features.find((f) => f.id === id);
    if (feature?.type !== "profile" || feature.suppressed)
      throw Error(
        `Broken projection reference: ${id} must be an active source sketch.`,
      );
    if (feature.profile.type === "projection") {
      visit(feature.profile.sourceFeatureId, depth + 1);
      if (feature.profile.authored) identify(feature.profile.authored);
    } else {
      if (feature.profile.type !== "drawing")
        feature.profile = resolveProfileDrawing(next.features, feature.id);
      identify(feature.profile);
    }
  };
  visit(featureId, 0);
  const end = next.features.findIndex((f) => f.id === featureId) + 1;
  validatePartDocument({
    ...next,
    features: next.features.slice(0, end),
    rollbackIndex: undefined,
  });
  // Check composed IDs too, including collisions across projected/authored halves.
  resolveProfileDrawing(next.features, featureId);
  return next;
}
