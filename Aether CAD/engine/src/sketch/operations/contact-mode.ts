import { validateSketchDrawing, type SketchDrawing } from "../drawing";
/** Freeze at the last solved parameter, or release that parameter without moving geometry. */
export function setSketchContactSliding(
  source: SketchDrawing,
  id: string,
  side: "a" | "b",
  sliding: boolean,
): SketchDrawing {
  validateSketchDrawing(source);
  if (typeof sliding !== "boolean" || !["a", "b"].includes(side))
    throw Error("Choose a contact side and mode.");
  const next = structuredClone(source),
    constraint = next.constraints?.find((c) => c.id === id),
    ref = constraint?.[side];
  if (
    !constraint ||
    !["coincident", "tangent", "curvature", "normal"].includes(
      constraint.kind,
    ) ||
    ref?.kind !== "curve"
  )
    throw Error("Select an existing curve contact.");
  ref.sliding = sliding;
  validateSketchDrawing(next);
  return next;
}
