import type { SketchDrawing } from "../drawing";
import { ellipseFrame } from "../curves/parameterization";
import { angularSpanDistance } from "../curves/angular-span";
import { identifySegmentReference } from "../solver/segment-reference";
import { linkRetainedEllipse } from "./retained-ellipse-relations";
/** Retain supporting conic and choose a visible child for each quadrant reference. */
export function remapSplitEllipse(
  source: SketchDrawing,
  next: SketchDrawing,
  contour: number,
  segment: number,
): void {
  const path = next.contours[contour];
  if (path.type !== "path") throw Error("Expected an elliptical path.");
  const whole = source.constraints?.some(
    (c) => c.kind === "ellipse-shape" && c.a.contour === contour,
  );
  next.constraints = (next.constraints ?? []).filter(
    (c) => !(c.kind === "ellipse-shape" && c.a.contour === contour),
  );
  for (const c of next.constraints) {
    if (c.kind !== "quadrant") continue;
    for (const key of ["a", "b"] as const) {
      const ref = c[key];
      if (
        !ref ||
        ref.contour !== contour ||
        ref.kind !== "ellipse" ||
        (!whole && ref.index !== segment && ref.index !== segment + 1)
      )
        continue;
      const index = path.segments.findIndex((s, i) => {
        if (
          s.type !== "ellipse" ||
          (!whole && i !== segment && i !== segment + 1)
        )
          return false;
        const frame = ellipseFrame(
          i === 0 ? path.start : path.segments[i - 1].end,
          s,
        );
        return (
          angularSpanDistance(
            frame.startAngle,
            frame.sweep,
            (c.quadrant! * Math.PI) / 2,
          ) === 0
        );
      });
      if (index < 0)
        throw Error("Split could not retain the ellipse quadrant.");
      const { segmentId: old, ...local } = ref;
      c[key] = identifySegmentReference(path, { ...local, index });
    }
  }
  if (whole) {
    linkRetainedEllipse(source, next, contour, 1);
    return;
  }
  const used = new Set(next.constraints.map((c) => c.id));
  let i = 1;
  while (used.has(`split-ellipse-${i}`)) i++;
  next.constraints.push({
    id: `split-ellipse-${i}`,
    kind: "ellipse-locus",
    a: identifySegmentReference(path, {
      kind: "ellipse",
      contour,
      index: segment,
    }),
    b: identifySegmentReference(path, {
      kind: "ellipse",
      contour,
      index: segment + 1,
    }),
  });
}
