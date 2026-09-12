import { expect, it } from "vitest";
import { sketchVariantContour } from "../primitives";
import { sketchConstraintState } from "../solver/diagnostics";
import { constraintResiduals } from "../solver/residuals";
import { dragSketchEntity } from "./drag-entity";
import { editDrawingDimension } from "./edit-dimension";
import { constrainSketchPolygon } from "./polygon-relations";
import type { SketchDrawing } from "../drawing";

function polygon(sides: number, circumscribed: boolean): SketchDrawing {
  const tool = circumscribed ? "circumscribed-polygon" : "inscribed-polygon";
  return constrainSketchPolygon(
    {
      type: "drawing",
      contours: [
        sketchVariantContour(
          tool,
          [
            [2, 3],
            [12, 3],
          ],
          sides,
        ),
      ],
    },
    0,
    [2, 3],
    circumscribed,
  );
}
function regular(d: SketchDrawing) {
  for (const c of d.constraints!)
    expect(Math.max(...constraintResiduals(d, c).map(Math.abs))).toBeLessThan(
      1e-6,
    );
  const path = d.contours[0];
  if (path.type !== "path") throw Error();
  const points = [path.start, ...path.segments.slice(0, -1).map((s) => s.end)];
  const edges = points.map((p, i) => {
    const q = points[(i + 1) % points.length];
    return [q[0] - p[0], q[1] - p[1]];
  });
  const length = Math.hypot(...edges[0]);
  for (let i = 0; i < edges.length; i++) {
    const a = edges[i],
      b = edges[(i + 1) % edges.length];
    expect(Math.hypot(...a)).toBeCloseTo(length, 5);
    expect((a[0] * b[0] + a[1] * b[1]) / length ** 2).toBeCloseTo(
      Math.cos((2 * Math.PI) / edges.length),
      5,
    );
  }
}

for (const circumscribed of [false, true]) {
  it(`preserves ${circumscribed ? "circumscribed" : "inscribed"} regularity during vertex dragging`, () => {
    for (const sides of [3, 4, 5, 6]) {
      const d = polygon(sides, circumscribed);
      expect(sketchConstraintState(d)).toMatchObject({
        state: "under-constrained",
        degreesOfFreedom: 4,
      });
      const moved = dragSketchEntity(
        d,
        { contour: 0, kind: "point", index: 0 },
        [2, 1],
      );
      regular(moved);
      expect(moved.constraints).toEqual(d.constraints);
    }
  });
  it(`edits the ${circumscribed ? "inner" : "outer"} sizing radius without fixing orientation`, () => {
    const d = polygon(6, circumscribed),
      sizing = circumscribed ? 2 : 1;
    d.constraints!.push(
      {
        id: "center",
        kind: "fix",
        a: { contour: sizing, kind: "point", index: 0 },
        point: [2, 3],
      },
      {
        id: "size",
        kind: "radius",
        a: { contour: sizing, kind: "circle" },
        value: 10,
      },
    );
    const moved = editDrawingDimension(d, "size", 12);
    regular(moved);
    expect(sketchConstraintState(moved)).toMatchObject({
      state: "under-constrained",
      degreesOfFreedom: 1,
    });
    const circle = moved.contours[sizing];
    if (circle.type !== "circle") throw Error();
    expect(circle.radius).toBeCloseTo(12);
    expect(circle.center[0]).toBeCloseTo(2);
    expect(circle.center[1]).toBeCloseTo(3);
  });
}
it("supports the existing 100-side limit with real editable constraints", () => {
  const d = polygon(100, true);
  expect(d.constraints).toHaveLength(201);
  d.constraints!.push({
    id: "size",
    kind: "radius",
    a: { contour: 2, kind: "circle" },
    value: 10,
  });
  const moved = editDrawingDimension(d, "size", 10.2);
  regular(moved);
});
it("rejects a nonregular path without mutating its source", () => {
  const source: SketchDrawing = {
    type: "drawing",
    contours: [
      sketchVariantContour(
        "inscribed-polygon",
        [
          [0, 0],
          [10, 0],
        ],
        4,
      ),
    ],
  };
  const path = source.contours[0];
  if (path.type !== "path") throw Error();
  path.segments[0].end[1] += 1;
  const before = structuredClone(source);
  expect(() => constrainSketchPolygon(source, 0, [0, 0])).toThrow();
  expect(source).toEqual(before);
});
