import { validateSketchDrawing, type SketchDrawing } from "../drawing";
import type { SketchEntityRef } from "../solver/types";

/** Add a selectable construction point tied to a line's midpoint.
 * The original line remains the profile edge; only the construction point is new.
 */
export function addSketchLineMidpoint(
  source: SketchDrawing,
  line: SketchEntityRef,
): SketchDrawing {
  const next = structuredClone(source),
    path = next.contours[line.contour];
  const index = line.index;
  if (
    line.kind !== "line" ||
    !path ||
    path.type !== "path" ||
    index === undefined ||
    !Number.isInteger(index) ||
    index < 0 ||
    path.segments[index]?.type !== "line"
  )
    throw new Error("Select an existing straight sketch edge.");
  const start = index ? path.segments[index - 1].end : path.start;
  const end = path.segments[index].end;
  const contour = next.contours.length;
  next.contours.push({
    type: "path",
    construction: true,
    start: [(start[0] + end[0]) / 2, (start[1] + end[1]) / 2],
    segments: [],
  });
  const constraints = (next.constraints ??= []);
  const ids = new Set(constraints.map((c) => c.id));
  let sequence = 1;
  while (ids.has(`line-midpoint-${sequence}`)) sequence++;
  constraints.push({
    id: `line-midpoint-${sequence}`,
    kind: "midpoint",
    a: { contour: line.contour, kind: "line", index },
    b: { contour, kind: "point", index: 0 },
  });
  validateSketchDrawing(next);
  return next;
}
