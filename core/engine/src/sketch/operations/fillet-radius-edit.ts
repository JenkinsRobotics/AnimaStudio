import { editDrawingDimension } from "./edit-dimension";
import { type SketchDrawing } from "../drawing";
import { type SketchEntityRef } from "../drawing-constraints";
import { filletRadiusHandle } from "./fillet-handle";
const key = (ref: SketchEntityRef) => `${ref.contour}:${ref.kind}:${ref.index}`;
/** Follow equal-radius links so any arc in a batch resolves to its driving dimension. */
export function findFilletRadiusDimension(
  drawing: SketchDrawing,
  arc: SketchEntityRef,
): string | undefined {
  if (arc.kind !== "arc") return;
  const reachable = new Set([key(arc)]);
  let changed = true;
  while (changed) {
    changed = false;
    for (const c of drawing.constraints ?? []) {
      if (
        c.kind !== "equal" ||
        !c.b ||
        c.a.kind !== "arc" ||
        c.b.kind !== "arc"
      )
        continue;
      const a = key(c.a),
        b = key(c.b);
      if (reachable.has(a) && !reachable.has(b)) {
        reachable.add(b);
        changed = true;
      }
      if (reachable.has(b) && !reachable.has(a)) {
        reachable.add(a);
        changed = true;
      }
    }
  }
  return drawing.constraints?.find(
    (c) =>
      c.kind === "radius" &&
      reachable.has(key(c.a)) &&
      filletRadiusHandle(drawing, c.id),
  )?.id;
}
export function editFilletRadius(
  source: SketchDrawing,
  id: string,
  radius: number,
): SketchDrawing {
  if (!Number.isFinite(radius) || radius <= 0)
    throw new Error("Enter a positive fillet radius.");
  const dimension = source.constraints?.find(
    (c) => c.id === id && c.kind === "radius",
  );
  if (!dimension || !filletRadiusHandle(source, id))
    throw new Error("Select a fillet with a driving radius.");
  return editDrawingDimension(source, id, radius);
}
