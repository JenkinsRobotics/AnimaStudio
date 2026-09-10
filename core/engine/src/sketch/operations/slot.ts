import { identifySourceEdges } from "./identify-source-edges";
import { appendClosedSlot } from "./closed-slot";
import {
  contourClosed,
  validateSketchDrawing,
  type SketchDrawing,
} from "../drawing";
import type { SketchEntityRef } from "../solver/types";
import { slotProfile } from "../curves/slot";
/** Selected slots share one width driver and retain source-edge relationships. */
export function slotSketchEntities(
  source: SketchDrawing,
  refs: SketchEntityRef[],
  width: number,
): SketchDrawing {
  if (!refs.length) throw Error("Select slot centerlines.");
  if (
    refs.some(
      (ref) =>
        ref.kind === "circle" &&
        source.contours[ref.contour]?.type !== "circle",
    )
  )
    throw Error("Select a circular slot centerline.");
  const next = structuredClone(source),
    seen = new Set<string>(),
    ids = new Set(next.constraints?.map((c) => c.id));
  let driver: string | undefined;
  for (const ref of identifySourceEdges(next, refs)) {
    const key = `${ref.contour}:${ref.kind}:${ref.index}`;
    if (seen.has(key)) continue;
    seen.add(key);
    if (
      ref.kind === "circle" &&
      source.contours[ref.contour]?.type !== "circle"
    )
      throw Error("Select a circular slot centerline.");
    if (
      ref.kind === "circle" ||
      (ref.kind === "contour" &&
        source.contours[ref.contour] &&
        contourClosed(source.contours[ref.contour]))
    ) {
      driver = appendClosedSlot(next, ref.contour, width, driver);
      for (const c of next.constraints ?? []) ids.add(c.id);
      continue;
    }
    const contour = next.contours.length;
    next.contours.push(slotProfile(next, ref, width));
    let n = 1;
    while (ids.has(`slot-${n}`)) n++;
    const id = `slot-${n}`;
    ids.add(id);
    (next.constraints ??= []).push({
      id,
      kind: "slot",
      a: { ...ref },
      b: { kind: "contour", contour },
      ...(driver ? { valueFrom: driver } : { value: width }),
    });
    driver ??= id;
    const centerline = next.contours[ref.contour];
    if (
      centerline.type === "path" &&
      (centerline.segments.length === 1 || ref.kind === "contour")
    )
      centerline.construction = true;
  }
  validateSketchDrawing(next);
  return next;
}
