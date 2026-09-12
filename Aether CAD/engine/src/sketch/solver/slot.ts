import { closedSlotResiduals } from "./closed-slot";
import { circularSlotResiduals } from "./circular-slot";
import { contourClosed, type SketchDrawing } from "../drawing";
import type { DrawingConstraint } from "./types";
import { dimensionValue } from "./dimension-links";
import { smoothSlotResiduals } from "./slot-chain";
import { slotCenterlinePath, slotProfile } from "../curves/slot";
import { sketchArcGeometry } from "../arc-geometry";
export function slotResiduals(
  d: SketchDrawing,
  c: DrawingConstraint,
): number[] {
  if(c.a.kind==="circle")return circularSlotResiduals(d,c);
  if(c.slotBoundary!==undefined)return closedSlotResiduals(d,c);
  const target = c.b?.kind === "contour" ? d.contours[c.b.contour] : undefined;
  const source = slotCenterlinePath(d, c.a),
    width = dimensionValue(d, c);
  if (
    source.segments.length > 1 &&
    target?.type === "path" &&
    target.segments.length === 2 * source.segments.length + 2
  )
    return smoothSlotResiduals(source, target, width);
  const expected = slotProfile(d, c.a, width);
  if (
    target?.type !== "path" ||
    !contourClosed(target) ||
    target.segments.length !== expected.segments.length ||
    target.segments.some((s, i) => s.type !== expected.segments[i].type)
  )
    throw Error("Slot topology changed.");
  const p = [
      expected.start,
      ...expected.segments.slice(0, -1).map((s) => s.end),
    ],
    q = [target.start, ...target.segments.slice(0, -1).map((s) => s.end)];
  const residuals = p.flatMap((a, i) => [q[i][0] - a[0], q[i][1] - a[1]]);
  expected.segments.forEach((s, i) => {
    const t = target.segments[i];
    if (s.type === "arc" && t.type === "arc")
      residuals.push(
        Math.tan(sketchArcGeometry(q[i], t.middle, t.end).sweep / 4) -
          Math.tan(sketchArcGeometry(p[i], s.middle, s.end).sweep / 4),
      );
  });
  return residuals;
}
