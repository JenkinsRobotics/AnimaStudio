import { expect, it } from "vitest";
import { editSketchPolygonSides } from "./polygon-sides";
import { constrainSketchPolygon } from "./polygon-relations";
import { sketchVariantContour } from "../primitives";
import { constraintResiduals } from "../solver/residuals";
import { editDrawingDimension } from "./edit-dimension";
function make(circumscribed = false) {
  return constrainSketchPolygon(
    {
      type: "drawing",
      contours: [
        sketchVariantContour(
          circumscribed ? "circumscribed-polygon" : "inscribed-polygon",
          [
            [2, 3],
            [12, 3],
          ],
          6,
        ),
      ],
    },
    0,
    [2, 3],
    circumscribed,
  );
}
for (const circumscribed of [false, true])
  it(`changes side count with persistent ${circumscribed ? "inner" : "outer"} sizing dimensions`, () => {
    const d = make(circumscribed),
      sizing = circumscribed ? 2 : 1;
    d.contours[0].id = "polygon";
    d.contours[sizing].id = "sizing";
    d.constraints!.push(
      {
        id: "radius",
        kind: "radius",
        a: { kind: "circle", contour: sizing },
        value: 10,
      },
      {
        id: "center",
        kind: "fix",
        a: { kind: "point", contour: sizing, index: 0 },
        point: [2, 3],
      },
    );
    const before = structuredClone(d),
      next = editSketchPolygonSides(d, 0, 8);
    expect(next.contours[0]).toMatchObject({
      id: "polygon",
      segments: Array.from({ length: 8 }, () =>
        expect.objectContaining({ type: "line" }),
      ),
    });
    expect(next.contours[sizing]).toMatchObject({
      id: "sizing",
      radius: 10,
      center: [2, 3],
    });
    for (const c of next.constraints!)
      expect(
        constraintResiduals(next, c).every((r) => Math.abs(r) < 1e-6),
      ).toBe(true);
    const resized = editDrawingDimension(
      JSON.parse(JSON.stringify(next)),
      "radius",
      12,
    );
    expect(resized.contours[sizing]).toMatchObject({
      radius: expect.closeTo(12, 5),
    });
    expect(editSketchPolygonSides(next, 0, 3).contours[0]).toMatchObject({
      segments: [expect.anything(), expect.anything(), expect.anything()],
    });
    expect(d).toEqual(before);
  });
it("remaps surviving vertices and rejects disappearing attachments atomically", () => {
  const d = make();
  d.constraints!.push({
    id: "fixed",
    kind: "fix",
    a: { kind: "point", contour: 0, index: 0 },
    point: [12, 3],
  });
  const next = editSketchPolygonSides(d, 0, 8);
  expect(next.constraints!.find((c) => c.id === "fixed")!.a.index).toBe(0);
  d.constraints!.push({
    id: "edge",
    kind: "length",
    a: { kind: "line", contour: 0, index: 0 },
    value: 10,
  });
  const before = structuredClone(d);
  expect(() => editSketchPolygonSides(d, 0, 8)).toThrow(/attachment/);
  expect(d).toEqual(before);
  expect(() => editSketchPolygonSides(d, 0, 2)).toThrow(/3 to 100/);
});
it("preserves clockwise traversal when changing a reflected polygon", async () => {
  const { transformContour } = await import("../curves/similarity");
  const d = make(true);
  d.contours = d.contours.map((c) =>
    transformContour(c, { a: -1, b: 0, c: 0, d: 1, tx: 0, ty: 0 }),
  );
  const next = editSketchPolygonSides(d, 0, 5),
    p = next.contours[0];
  if (p.type !== "path") throw Error();
  const q = p.segments[0].end;
  expect(
    (p.start[0] + 2) * (q[1] - 3) - (p.start[1] - 3) * (q[0] + 2),
  ).toBeLessThan(0);
  for (const c of next.constraints!)
    expect(constraintResiduals(next, c).every((r) => Math.abs(r) < 1e-6)).toBe(
      true,
    );
});
