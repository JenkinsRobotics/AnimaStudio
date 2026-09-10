import { expect, it } from "vitest";
import { editDrawingDimension } from "../operations/edit-dimension";
import { setSketchRadius } from "../operations/set-radius";
import { splitSketchCircle } from "../operations/split";
import { resolve } from "./entities";
import { validateSketchDrawing, type SketchDrawing } from "../drawing";
const drawing = (): SketchDrawing => ({
  type: "drawing",
  contours: [{ type: "circle", center: [2, 3], radius: 5 }],
  constraints: [
    {
      id: "diameter",
      kind: "diameter",
      a: { kind: "circle", contour: 0 },
      value: 10,
    },
    {
      id: "center",
      kind: "fix",
      a: { kind: "point", contour: 0, index: 0 },
      point: [2, 3],
    },
  ],
});
it("drives a circle diameter after serialization without moving its fixed center", () => {
  const d = drawing();
  validateSketchDrawing(d);
  const resized = editDrawingDimension(
    JSON.parse(JSON.stringify(d)),
    "diameter",
    16,
  );
  expect(resized.contours[0]).toMatchObject({ center: [2, 3] });
  expect(
    resolve(resized, { kind: "circle", contour: 0 }).circle!.radius,
  ).toBeCloseTo(8);
  const radiusEdit = setSketchRadius(
    resized,
    { kind: "circle", contour: 0 },
    3,
  );
  expect(radiusEdit.constraints).toHaveLength(2);
  expect(radiusEdit.constraints![0].value).toBe(6);
  expect(() => editDrawingDimension(d, "diameter", 0)).toThrow();
  expect(() => editDrawingDimension(d, "diameter", -2)).toThrow();
  expect(d.contours[0]).toMatchObject({ radius: 5 });
});
it("retains the diameter driver when a circle becomes split arcs", () => {
  const split = splitSketchCircle(drawing(), 0, [7, 3], [2, 8]);
  const resized = editDrawingDimension(split, "diameter", 14);
  for (const index of [0, 1])
    expect(
      resolve(resized, { kind: "arc", contour: 0, index }).circle!.radius,
    ).toBeCloseTo(7);
});
it("uses literal diameter values when linked to another length dimension", () => {
  const d = drawing();
  d.contours.push({ type: "circle", center: [20, 20], radius: 10 });
  d.constraints!.push({
    id: "linked-radius",
    kind: "radius",
    a: { kind: "circle", contour: 1 },
    valueFrom: "diameter",
  });
  validateSketchDrawing(d);
  const resized = editDrawingDimension(d, "diameter", 12);
  expect(
    resolve(resized, { kind: "circle", contour: 0 }).circle!.radius,
  ).toBeCloseTo(6);
  expect(
    resolve(resized, { kind: "circle", contour: 1 }).circle!.radius,
  ).toBeCloseTo(12);
});
