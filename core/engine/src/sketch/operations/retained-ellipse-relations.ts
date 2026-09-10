import type { SketchDrawing } from "../drawing";
import type { SketchEntityRef } from "../solver/types";
import { identifySegmentReference } from "../solver/segment-reference";
/** Replace closed-half parameterization with one common conic for surviving arcs. */
export function linkRetainedEllipse(
  source: SketchDrawing,
  next: SketchDrawing,
  contour: number,
  count: number,
): void {
  if (
    !source.constraints?.some(
      (c) => c.kind === "ellipse-shape" && c.a.contour === contour,
    )
  )
    return;
  const refs: SketchEntityRef[] = [];
  for (let offset = 0; offset < count; offset++) {
    const path = next.contours[contour + offset];
    if (path.type !== "path") continue;
    path.segments.forEach((s, index) => {
      if (s.type === "ellipse")
        refs.push(
          identifySegmentReference(path, {
            contour: contour + offset,
            kind: "ellipse",
            index,
          }),
        );
    });
  }
  const constraints = (next.constraints ??= []),
    used = new Set(constraints.map((c) => c.id));
  let sequence = 1;
  for (const b of refs.slice(1)) {
    while (used.has(`trim-ellipse-${sequence}`)) sequence++;
    const id = `trim-ellipse-${sequence++}`;
    used.add(id);
    constraints.push({ id, kind: "ellipse-locus", a: refs[0], b });
  }
  next.constraints = constraints;
}
