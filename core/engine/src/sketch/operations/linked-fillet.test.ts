import { expect, it } from "vitest";
import { filletSketchCorners } from "./fillet-batch";
import { filletRadiusHandle } from "./fillet-handle";
import { editFilletRadius } from "./fillet-radius-edit";
import { linkSketchDimension } from "./link-dimension";
import { setDimensionReference } from "./dimension-reference";
import { sketchArcGeometry } from "../arc-geometry";
export function linkedFilletFixture() {
  const d = filletSketchCorners(
    {
      type: "drawing",
      contours: [
        {
          type: "path",
          start: [0, 0],
          segments: [
            { type: "line", end: [20, 0] },
            { type: "line", end: [20, 20] },
            { type: "line", end: [0, 20] },
            { type: "line", end: [0, 0] },
          ],
        },
      ],
    },
    [{ contour: 0, vertex: 0 }],
    2,
  );
  const id = d.constraints!.find((c) => c.kind === "radius")!.id;
  const contour = d.contours.length;
  d.contours.push({ type: "circle", center: [40, 40], radius: 1 });
  d.constraints!.push({
    id: "driver",
    kind: "radius",
    a: { contour, kind: "circle" },
    value: 1,
  });
  return { drawing: linkSketchDimension(d, id, "driver", 2, 0), id };
}
it("edits a linked fillet through its existing radius operation and handle", () => {
  const { drawing, id } = linkedFilletFixture(),
    before = structuredClone(drawing);
  expect(filletRadiusHandle(drawing, id)!.radius).toBe(2);
  const edited = editFilletRadius(JSON.parse(JSON.stringify(drawing)), id, 3);
  expect(edited.constraints!.find((c) => c.id === "driver")!.value).toBe(1.5);
  expect(edited.constraints!.find((c) => c.id === id)).toMatchObject({
    valueFrom: "driver",
    valueScale: 2,
  });
  expect(edited.constraints!.find((c) => c.id === id)!.value).toBeUndefined();
  expect(filletRadiusHandle(edited, id)!.radius).toBe(3);
  const path = edited.contours[0];
  if (path.type !== "path") throw Error();
  path.segments.forEach((s, index) => {
    if (s.type === "arc")
      expect(
        sketchArcGeometry(
          index ? path.segments[index - 1].end : path.start,
          s.middle,
          s.end,
        ).radius,
      ).toBeCloseTo(3, 6);
  });
  expect(drawing).toEqual(before);
});
it("does not expose an editable handle for a reference radius", () => {
  const { drawing, id } = linkedFilletFixture();
  const measured = setDimensionReference(drawing, id, true);
  expect(filletRadiusHandle(measured, id)).toBeUndefined();
  expect(() => editFilletRadius(measured, id, 4)).toThrow("driving radius");
});
