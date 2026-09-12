import { expect, it } from "vitest";
import { editSketchQuadrant } from "./quadrant-edit";
import { constrainSketchEllipse } from "./ellipse-relations";
import { sketchVariantContour } from "../primitives";
const fixture = () => {
  const d = constrainSketchEllipse(
    {
      type: "drawing",
      contours: [
        sketchVariantContour("ellipse", [
          [0, 0],
          [5, 0],
          [0, 2],
        ]),
        { type: "path", start: [5, 0], segments: [] },
      ],
    },
    0,
  );
  d.constraints!.push({
    id: "q",
    kind: "quadrant",
    a: { kind: "point", contour: 1, index: 0 },
    b: { kind: "ellipse", contour: 0, index: 0 },
    quadrant: 0,
  });
  return d;
};
it("reassigns all local quadrants without changing free source ellipse or constraint identity", () => {
  const source = fixture();
  let d = source;
  for (const [q, p] of [
    [1, [0, 2]],
    [2, [-5, 0]],
    [3, [0, -2]],
    [0, [5, 0]],
  ] as const) {
    d = editSketchQuadrant(JSON.parse(JSON.stringify(d)), "q", q);
    const point = d.contours[1];
    if (point.type !== "path") throw Error();
    expect(point.start[0]).toBeCloseTo(p[0]);
    expect(point.start[1]).toBeCloseTo(p[1]);
    expect(d.contours[0]).toEqual(source.contours[0]);
    expect(d.constraints!.at(-1)).toMatchObject({ id: "q", quadrant: q });
  }
  expect(editSketchQuadrant(d, "q", 0)).toEqual(d);
  expect(() => editSketchQuadrant(d, "q", 4)).toThrow(/four/);
  expect(() => editSketchQuadrant(d, "missing", 0)).toThrow(/existing/);
});
it("rejects incompatible retained quadrant and radius constraints without mutating input", () => {
  const d = fixture();
  d.constraints!.push({ ...d.constraints!.at(-1)!, id: "other" });
  // A fixed ellipse is formed by two fixed endpoint locations and fixed Y quadrant.
  d.constraints!.push(
    {
      id: "fix-start",
      kind: "fix",
      a: { kind: "point", contour: 0, index: 0 },
      point: [5, 0],
    },
    {
      id: "fix-end",
      kind: "fix",
      a: { kind: "point", contour: 0, index: 1 },
      point: [-5, 0],
    },
  );
  const before = structuredClone(d);
  expect(() => editSketchQuadrant(d, "q", 2)).toThrow();
  expect(d).toEqual(before);
});
