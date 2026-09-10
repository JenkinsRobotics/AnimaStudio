import { validateSketchDrawing, type SketchDrawing } from "../drawing";
import { chamferSketchCorner, type ChamferSize } from "./chamfer";
import { assertConstraintsSatisfied } from "./preserve-constraints";
export interface ChamferCorner {
  contour: number;
  vertex: number;
}
/** Apply original corner indices in descending order and persist one driver per batch parameter. */
export function chamferSketchCorners(
  source: SketchDrawing,
  corners: ChamferCorner[],
  size: ChamferSize,
): SketchDrawing {
  if (!corners.length) throw new Error("Select at least one chamfer corner.");
  const unique = [
    ...new Map(corners.map((c) => [`${c.contour}:${c.vertex}`, c])).values(),
  ].sort((a, b) => b.contour - a.contour || b.vertex - a.vertex);
  let next = source;
  const groups: string[][] = [];
  for (const corner of unique) {
    const old = new Set(next.constraints?.map((c) => c.id));
    next = chamferSketchCorner(next, corner.contour, corner.vertex, size);
    groups.push(
      next
        .constraints!.filter(
          (c) =>
            !old.has(c.id) &&
            c.value !== undefined &&
            ["distance", "angle"].includes(c.kind),
        )
        .map((c) => c.id),
    );
  }
  const master = groups[0].map((id) =>
    next.constraints!.find((c) => c.id === id)!,
  );
  for (const group of groups.slice(1))
    group.forEach((id, i) => {
      const dimension = next.constraints!.find((c) => c.id === id)!,
        driver = master[i];
      if (dimension.kind !== driver.kind)
        throw new Error("Incompatible chamfer batch dimensions.");
      if (dimension.kind === "angle")
        dimension.valueSign = Math.sign(dimension.value! / driver.value!) as
          1 | -1;
      dimension.valueFrom = driver.id;
      delete dimension.value;
    });
  assertConstraintsSatisfied(next);
  validateSketchDrawing(next);
  return next;
}
