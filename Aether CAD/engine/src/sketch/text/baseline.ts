import type { SketchDrawing } from "../drawing";

/** Creation-time inference only. Never restore a constraint the author removed,
 * force an explicitly rotated frame horizontal, or overconstrain existing text. */
export function constrainNewTextBaseline(drawing: SketchDrawing, id: string) {
  const item = drawing.textItems?.find((item) => item.id === id);
  if (!item?.frameContourId) return;
  const contour = drawing.contours.findIndex(
      (c) => c.id === item.frameContourId,
    ),
    frame = drawing.contours[contour];
  if (frame?.type !== "path" || !frame.segments.length) return;
  if (Math.abs(frame.segments[0].end[1] - frame.start[1]) > 1e-7) return;
  const owned = new Set(
    item.contourIds.map((id) => drawing.contours.findIndex((c) => c.id === id)),
  );
  if (
    drawing.constraints?.some(
      (c) =>
        !c.reference &&
        [c.a, c.b, c.axis].some((ref) => ref && owned.has(ref.contour)),
    )
  )
    return;
  drawing.constraints ??= [];
  drawing.constraints.push({
    id: `text-baseline-${crypto.randomUUID()}`,
    kind: "horizontal",
    a: { contour, kind: "line", index: 0 },
  });
}
