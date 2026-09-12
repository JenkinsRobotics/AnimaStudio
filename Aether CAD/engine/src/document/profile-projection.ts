import type { PartFeature } from "./part-document";
import { composeProjectedDrawing } from "./mixed-projection";
import type { ProfileFeature } from "./solid-features";
import { projectSketchDrawing } from "../sketch/projection/drawing";
import { solveDrawingConstraints } from "../sketch/drawing-constraints";
import type { SketchDrawing, SketchFrame } from "../sketch/drawing";
/** Matches the evaluator's named Replicad planes. Explicit frames already
 * contain their world origin, so the legacy offset is not applied twice. */
export function profileSketchFrame(feature: ProfileFeature): SketchFrame {
  if (feature.frame) return structuredClone(feature.frame);
  const normal: SketchFrame["normal"] =
    feature.plane === "XY"
      ? [0, 0, 1]
      : feature.plane === "XZ"
        ? [0, -1, 0]
        : [1, 0, 0];
  return {
    originMillimeters: normal.map(
      (v) => v * feature.offsetMillimeters,
    ) as SketchFrame["normal"],
    normal,
    xDirection: feature.plane === "YZ" ? [0, 1, 0] : [1, 0, 0],
  };
}
/** Resolve whole-sketch projection by stable feature ID. No geometry snapshot
 * is persisted. Restricting dependencies to earlier features prevents cycles
 * and makes rollback/suppression deterministic. */
export function resolveProfileDrawing(
  features: readonly PartFeature[],
  featureId: string,
): SketchDrawing {
  const cache = new Map<string, SketchDrawing>();
  const resolve = (
    id: string,
    before: number,
    depth: number,
  ): SketchDrawing => {
    if (depth > 256)
      throw Error("Projection dependency chain exceeds 256 profiles.");
    const index = features.findIndex((f) => f.id === id),
      feature = features[index];
    if (index < 0 || index >= before || feature.type !== "profile")
      throw Error(
        `Broken projection reference: ${id} must be an earlier profile.`,
      );
    if (feature.suppressed)
      throw Error(`Projection source is suppressed: ${feature.name} (${id}).`);
    const hit = cache.get(id);
    if (hit) return hit;
    const p = feature.profile;
    let drawing: SketchDrawing;
    if (p.type === "projection") {
      const input = resolve(p.sourceFeatureId, index, depth + 1),
        source = features.find(
          (f) => f.id === p.sourceFeatureId,
        ) as ProfileFeature;
      const selected = p.sourceContourId === undefined ? input.contours : input.contours.filter(c=>c.id===p.sourceContourId);
      if(p.sourceContourId!==undefined&&selected.length!==1)throw Error(`Broken projection contour reference: ${p.sourceContourId} in ${source.name}.`);
      drawing = projectSketchDrawing(
        {type:"drawing",contours:selected},
        profileSketchFrame(source),
        profileSketchFrame(feature),
      );
      drawing = composeProjectedDrawing(drawing, p.authored);
    } else if (p.type === "drawing") drawing = solveDrawingConstraints(p);
    else if (p.type === "circle")
      drawing = {
        type: "drawing",
        contours: [
          {
            type: "circle",
            center: [...p.centerMillimeters],
            radius: p.radiusMillimeters,
          },
        ],
      };
    else
      drawing = {
        type: "drawing",
        contours: [
          {
            type: "path",
            start: [...p.pointsMillimeters[0]],
            segments: [
              ...p.pointsMillimeters.slice(1),
              p.pointsMillimeters[0],
            ].map((end) => ({ type: "line", end: [...end] })),
          },
        ],
      };
    cache.set(id, drawing);
    return drawing;
  };
  return resolve(featureId, features.length, 0);
}
