import { validateSketchDrawing, type SketchDrawing } from "../drawing";
import { sketchArcGeometry } from "../arc-geometry";
import type { DrawingConstraint, SketchEntityRef } from "../solver/types";
import { addSketchArcCenter } from "./arc-center";

/** Placement-only inference: keep a half-circle's analytic center at the
 * endpoint chord using ordinary editable constraints. A circle center already
 * lies on the chord bisector, so one point-on-line equation makes the chord a
 * diameter without adding a redundant midpoint equation. */
export function inferSketchSemicircle(
  source: SketchDrawing,
  contour: number,
  index: number,
): SketchDrawing {
  const path = source.contours[contour];
  if (path?.type !== "path" || path.segments[index]?.type !== "arc")
    return source;
  const segment = path.segments[index];
  if (segment.type !== "arc") return source;
  const start = index === 0 ? path.start : path.segments[index - 1].end;
  const geometry = sketchArcGeometry(start, segment.middle, segment.end);
  if (Math.abs(Math.abs(geometry.sweep) - Math.PI) > 1e-7) return source;
  const next = addSketchArcCenter(source, { contour, kind: "arc", index });
  const center = next.constraints!.find(
    (c) =>
      c.kind === "concentric" &&
      c.a.contour === contour &&
      c.a.kind === "arc" &&
      c.a.index === index &&
      c.b?.kind === "point",
  )!.b!;
  const chord = next.contours.length;
  next.contours.push({
    type: "path",
    construction: true,
    start: [...start],
    segments: [{ type: "line", end: [...segment.end] }],
  });
  const constraints = next.constraints!;
  const used = new Set(constraints.map((c) => c.id));
  let sequence = 1;
  const add = (
    kind: DrawingConstraint["kind"],
    a: SketchEntityRef,
    b: SketchEntityRef,
  ) => {
    while (used.has(`semicircle-${sequence}`)) sequence++;
    const id = `semicircle-${sequence++}`;
    used.add(id);
    constraints.push({ id, kind, a, b });
  };
  add(
    "coincident",
    { contour: chord, kind: "point", index: 0 },
    { contour, kind: "point", index },
  );
  add(
    "coincident",
    { contour: chord, kind: "point", index: 1 },
    { contour, kind: "point", index: index + 1 },
  );
  add("coincident", { contour: chord, kind: "line", index: 0 }, center);
  validateSketchDrawing(next);
  return next;
}
