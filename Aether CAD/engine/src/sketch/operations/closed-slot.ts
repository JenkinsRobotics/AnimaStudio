import { closedSlotBoundary } from "../curves/closed-slot";
import type { SketchDrawing } from "../drawing";
/** Append two exact closed boundaries to a working copy. Width remains one
 * shared dimension; each persisted boundary declares its side explicitly. */
export function appendClosedSlot(
  d: SketchDrawing,
  contour: number,
  width: number,
  driver?: string,
): string {
  const source = d.contours[contour];
  if (!source) throw Error("Select a closed slot centerline.");
  const constraints = (d.constraints ??= []),
    ids = new Set(constraints.map((c) => c.id));
  for (const side of ["outer", "inner"] as const) {
    const target = d.contours.length;
    d.contours.push(closedSlotBoundary(source, side, width));
    let n = 1;
    while (ids.has(`slot-${n}`)) n++;
    const id = `slot-${n}`;
    ids.add(id);
    constraints.push({
      id,
      kind: "slot",
      slotBoundary: side,
      a: { kind: source.type === "circle" ? "circle" : "contour", contour },
      b: {
        kind: source.type === "circle" ? "circle" : "contour",
        contour: target,
      },
      ...(driver ? { valueFrom: driver } : { value: width }),
    });
    driver ??= id;
  }
  d.constraints = constraints;
  source.construction = true;
  return driver!;
}
