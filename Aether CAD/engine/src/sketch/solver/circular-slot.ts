import type { SketchDrawing } from "../drawing";
import type { DrawingConstraint } from "./types";
import { dimensionValue } from "./dimension-links";
export function circularSlotResiduals(
  d: SketchDrawing,
  c: DrawingConstraint,
): number[] {
  const a = d.contours[c.a.contour],
    b = c.b ? d.contours[c.b.contour] : undefined,
    width = dimensionValue(d, c);
  if (
    a?.type !== "circle" ||
    c.a.kind !== "circle" ||
    b?.type !== "circle" ||
    c.b?.kind !== "circle" ||
    !["inner", "outer"].includes(c.slotBoundary ?? "")
  )
    throw Error("Circular slot references or boundary side are invalid.");
  if (!Number.isFinite(width) || width <= 1e-8 || width >= 2 * a.radius - 1e-8)
    throw Error(
      "Circular slot width must be smaller than its centerline diameter.",
    );
  return [
    b.center[0] - a.center[0],
    b.center[1] - a.center[1],
    b.radius - a.radius - ((c.slotBoundary === "outer" ? 1 : -1) * width) / 2,
  ];
}
