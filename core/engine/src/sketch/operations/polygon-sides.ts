import { remapPolygonAttachment } from "./polygon-attachments";
import { transformContour } from "../curves/similarity";
import { validateSketchDrawing, type SketchDrawing } from "../drawing";
import type { SketchEntityRef } from "../solver/types";
import { sketchVariantContour } from "../primitives";
import { constrainSketchPolygon } from "./polygon-relations";
import { sketchPolygonDefinition } from "./polygon-definition";
import { assertConstraintsSatisfied } from "./preserve-constraints";

export function editSketchPolygonSides(
  source: SketchDrawing,
  contour: number,
  sides: number,
): SketchDrawing {
  if (!Number.isInteger(sides) || sides < 3 || sides > 100)
    throw Error("Polygon sides must be an integer from 3 to 100.");
  validateSketchDrawing(source);
  const definition = sketchPolygonDefinition(source, contour),
    next = structuredClone(source);
  if (sides === definition.sides) return next;
  const path = source.contours[contour],
    outer = source.contours[definition.outer],
    sizing = source.contours[definition.inner ?? definition.outer];
  if (
    path.type !== "path" ||
    outer.type !== "circle" ||
    sizing.type !== "circle"
  )
    throw Error("Invalid polygon sizing geometry.");
  const angle =
    Math.atan2(
      path.start[1] - outer.center[1],
      path.start[0] - outer.center[0],
    ) +
    (definition.inner === undefined
      ? 0
      : (definition.orientation * Math.PI) / definition.sides);
  let raw = sketchVariantContour(
    definition.inner === undefined
      ? "inscribed-polygon"
      : "circumscribed-polygon",
    [
      sizing.center,
      [
        sizing.center[0] + sizing.radius * Math.cos(angle),
        sizing.center[1] + sizing.radius * Math.sin(angle),
      ],
    ],
    sides,
  );
  if (definition.orientation < 0) {
    const a = Math.cos(2 * angle),
      b = Math.sin(2 * angle),
      [x, y] = sizing.center;
    raw = transformContour(raw, {
      a,
      b,
      c: b,
      d: -a,
      tx: x - a * x - b * y,
      ty: y - b * x + a * y,
    });
  }
  const generated = constrainSketchPolygon(
    { type: "drawing", contours: [raw] },
    0,
    sizing.center,
    definition.inner !== undefined,
  );
  const replacement = generated.contours[0];
  if (replacement.type !== "path") throw Error();
  const owned = new Set(definition.owned.map((c) => c.id));
  const map = (r: SketchEntityRef) =>
    remapPolygonAttachment(r, contour, path, replacement);
  next.constraints = (source.constraints ?? [])
    .filter((c) => !owned.has(c.id))
    .map((c) => ({
      ...c,
      a: map(c.a),
      ...(c.b ? { b: map(c.b) } : {}),
      ...(c.axis ? { axis: map(c.axis) } : {}),
    }));
  next.contours[contour] = {
    ...path,
    start: replacement.start,
    segments: replacement.segments,
  };
  for (const [local, index] of [
    [1, definition.outer],
    ...(definition.inner === undefined ? [] : [[2, definition.inner]]),
  ])
    next.contours[index] = {
      ...next.contours[index],
      ...generated.contours[local],
      ...(next.contours[index].id ? { id: next.contours[index].id } : {}),
    };
  const indices = [contour, definition.outer, definition.inner];
  const remap = (r: SketchEntityRef) => ({
    ...r,
    contour: indices[r.contour]!,
  });
  const ids = new Set(next.constraints.map((c) => c.id));
  let sequence = 1;
  for (const c of generated.constraints!) {
    while (ids.has(`polygon-${sequence}`)) sequence++;
    const id = `polygon-${sequence++}`;
    ids.add(id);
    next.constraints.push({
      ...c,
      id,
      a: remap(c.a),
      ...(c.b ? { b: remap(c.b) } : {}),
    });
  }
  assertConstraintsSatisfied(next);
  validateSketchDrawing(next);
  return next;
}
