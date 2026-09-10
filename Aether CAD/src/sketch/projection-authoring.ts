import {
  resolveProfileDrawing,
  type PartDocument,
  type ProfileFeature,
} from "@aether/core/document";
import { solveDrawingConstraints, type SketchDrawing } from "@aether/core/sketch";
import { contourPath } from "./svg-geometry";

/** Editing owns only the authored drawing; derived geometry is resolved for
 * context and never copied into the user's saved contour list. */
export function projectionAuthoring(
  part: PartDocument,
  feature?: ProfileFeature,
) {
  if (feature?.profile.type !== "projection") return undefined;
  const profile = structuredClone(feature.profile);
  const features = part.features.map((f) =>
    f.id === feature.id
      ? {
          ...feature,
          suppressed: false,
          profile: { ...profile, authored: undefined },
        }
      : f,
  );
  const background = resolveProfileDrawing(features, feature.id);
  return {
    drawing: solveDrawingConstraints({...structuredClone(profile.authored ?? { type: "drawing", contours: [] }), projectionContext: structuredClone(background.contours)} as SketchDrawing),
    save: (authored: SketchDrawing): ProfileFeature["profile"] => ({
      ...profile,
      authored: (()=>{const {projectionContext:_,...saved}=authored;return structuredClone(saved);})(),
    }),
    render(svg: SVGSVGElement) {
      const ns = "http://www.w3.org/2000/svg",
        group = document.createElementNS(ns, "g");
      group.setAttribute("class", "sketch-projected-background");
      group.setAttribute("aria-label", "Live projected geometry (read-only)");
      group.setAttribute("pointer-events", "none");
      for (const c of background.contours) {
        const node = document.createElementNS(
          ns,
          c.type === "circle" ? "circle" : "path",
        );
        if (c.type === "circle") {
          node.setAttribute("cx", String(c.center[0]));
          node.setAttribute("cy", String(-c.center[1]));
          node.setAttribute("r", String(c.radius));
        } else node.setAttribute("d", contourPath(c));
        node.setAttribute("vector-effect", "non-scaling-stroke");
        group.append(node);
      }
      svg.prepend(group);
    },
  };
}
