import type { SketchDrawing } from "../drawing";
import { resolve } from "../solver/entities";
import { ellipseQuadrant } from "../solver/ellipse-contact";
/** Candidate-only inference on a newly authored arc; no temporary guide is saved. */
export function constrainEllipseEndpointQuadrants(
  drawing: SketchDrawing,
  contour: number,
): void {
  const path = drawing.contours[contour];
  if (
    path.type !== "path" ||
    path.segments.length !== 1 ||
    path.segments[0].type !== "ellipse"
  )
    return;
  const ref = { contour, kind: "ellipse" as const, index: 0 },
    e = resolve(drawing, ref).ellipse!;
  const constraints = (drawing.constraints ??= []),
    used = new Set(constraints.map((c) => c.id));
  for (const [index, point] of [path.start, path.segments[0].end].entries()) {
    for (const quadrant of [0, 1, 2, 3] as const) {
      const q = ellipseQuadrant(e, quadrant);
      if (Math.hypot(q[0] - point[0], q[1] - point[1]) > 1e-7) continue;
      if (
        constraints.some(
          (c) =>
            c.kind === "quadrant" &&
            c.quadrant === quadrant &&
            c.a.kind === "point" &&
            c.a.contour === contour &&
            c.a.index === index &&
            c.b?.kind === "ellipse" &&
            c.b.contour === contour &&
            c.b.index === 0,
        )
      )
        break;
      let n = 1;
      while (used.has(`ellipse-endpoint-${n}`)) n++;
      const id = `ellipse-endpoint-${n}`;
      used.add(id);
      constraints.push({
        id,
        kind: "quadrant",
        a: { contour, kind: "point", index },
        b: ref,
        quadrant,
      });
      break;
    }
  }
}
