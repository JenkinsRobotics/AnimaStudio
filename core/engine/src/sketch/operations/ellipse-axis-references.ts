export class MissingEllipseAxisEndpoints extends Error {}
import type { SketchDrawing } from "../drawing";
import type { SketchEntityRef } from "../solver/types";
import { resolve } from "../solver/entities";
import { resolveSegmentReference } from "../solver/segment-reference";
import {
  ellipseQuadrant,
  nearestEllipseQuadrant,
  quadrantSpan,
} from "../solver/ellipse-contact";

export function ellipseReferenceKey(
  drawing: SketchDrawing,
  ref: SketchEntityRef,
): string {
  const contour = ref.projectedContourId
    ? drawing.projectionContext?.find((c) => c.id === ref.projectedContourId)
    : drawing.contours[ref.contour];
  const normalized = resolveSegmentReference(contour, ref);
  return JSON.stringify([
    ref.projectedContourId ?? ref.contour,
    normalized.index ?? 0,
  ]);
}

/** Follow explicit conic relations, never merely nearby or equal-looking curves. */
export function ellipseAxisReferences(
  drawing: SketchDrawing,
  ref: SketchEntityRef,
  axis: "x" | "y",
) {
  const ellipse = resolve(drawing, ref).ellipse;
  if (!ellipse) throw Error("Select an elliptical sketch segment.");
  const candidates = new Map([[ellipseReferenceKey(drawing, ref), ref]]);
  let changed = true;
  while (changed) {
    changed = false;
    for (const c of drawing.constraints ?? []) {
      if (c.kind !== "ellipse-locus" || !c.b) continue;
      const a = ellipseReferenceKey(drawing, c.a),
        b = ellipseReferenceKey(drawing, c.b);
      if (candidates.has(a) === candidates.has(b)) continue;
      candidates.set(candidates.has(a) ? b : a, candidates.has(a) ? c.b : c.a);
      changed = true;
    }
  }
  return [axis === "x" ? 0 : 1, axis === "x" ? 2 : 3].map((q) => {
    const point = ellipseQuadrant(ellipse, q);
    for (const candidate of candidates.values()) {
      const entity = resolve(drawing, candidate),
        frame = entity.ellipse;
      if (!frame) continue;
      let quadrant;
      try {
        quadrant = nearestEllipseQuadrant(frame, point, quadrantSpan(entity));
      } catch {
        continue;
      }
      const actual = ellipseQuadrant(frame, quadrant);
      if (Math.hypot(actual[0] - point[0], actual[1] - point[1]) > 1e-6)
        continue;
      return { ref: candidate, quadrant, point };
    }
    throw new MissingEllipseAxisEndpoints(
      "The retained ellipse arcs do not contain both axis endpoints.",
    );
  });
}
