import type { SketchDrawing, SketchPoint } from "../drawing";
import { slotCenterlinePath } from "../curves/slot";
import { curveJet } from "../curves/derivatives";
import { dimensionValue } from "../solver/dimension-links";
export interface SlotHandle {
  origin: SketchPoint;
  position: SketchPoint;
  normal: SketchPoint;
  width: number;
}
/** Width is a diameter; the visual handle lies half that distance from centerline. */
export function slotWidthHandle(
  drawing: SketchDrawing,
  id: string,
): SlotHandle | undefined {
  const c = drawing.constraints?.find((c) => c.id === id && c.kind === "slot");
  if (!c) return;
  if(c.a.kind==="circle"){
    const source=drawing.contours[c.a.contour];if(source.type!=="circle")return;
    const width=dimensionValue(drawing,c),origin:SketchPoint=[source.center[0]+source.radius,source.center[1]];
    return {origin,normal:[1,0],width,position:[origin[0]+width/2,origin[1]]};
  }
  const candidate=drawing.contours[c.a.contour];
  const path = c.slotBoundary!==undefined&&candidate.type==="path" ? candidate : slotCenterlinePath(drawing, c.a);
  const jet = curveJet({ start: path.start, segment: path.segments[0] })(0.5),
    length = Math.hypot(...jet.first),
    width = dimensionValue(drawing, c);
  if (length < 1e-10) return;
  const normal: SketchPoint = [-jet.first[1] / length, jet.first[0] / length];
  return {
    origin: jet.point,
    normal,
    width,
    position: [
      jet.point[0] + (normal[0] * width) / 2,
      jet.point[1] + (normal[1] * width) / 2,
    ],
  };
}
export function slotWidthFromHandle(
  handle: SlotHandle,
  point: SketchPoint,
): number {
  if (!point.every(Number.isFinite))
    throw Error("Slot handle coordinates must be finite.");
  return (
    2 *
    Math.abs(
      (point[0] - handle.origin[0]) * handle.normal[0] +
        (point[1] - handle.origin[1]) * handle.normal[1],
    )
  );
}
