import { expect, it } from "vitest";
import { createSketchTangentArc, pickTangentArcSource } from "./tangent-arc";
import { constraintResiduals } from "../solver/residuals";
import { dragSketchEntity } from "./drag-entity";
import { sketchArcGeometry } from "../arc-geometry";
import type { SketchDrawing } from "../drawing";
const line = (): SketchDrawing => ({
  type: "drawing",
  contours: [
    {
      type: "path",
      start: [-10, 0],
      segments: [{ type: "line", end: [0, 0] }],
    },
  ],
});

it("appends either arc direction with persistent endpoint tangency", () => {
  for (const sign of [-1, 1]) {
    const source = line(),
      before = structuredClone(source);
    const result = createSketchTangentArc(
      source,
      { contour: 0, segment: 0, endpoint: 1 },
      [5, sign * 5],
    );
    expect(result.drawing.contours).toHaveLength(1);
    const path = result.drawing.contours[0];
    if (path.type !== "path") throw Error();
    const arc = path.segments[1];
    if (arc.type !== "arc") throw Error();
    expect(
      sketchArcGeometry([0, 0], arc.middle, arc.end).sweep * sign,
    ).toBeGreaterThan(0);
    expect(
      Math.max(
        ...constraintResiduals(
          result.drawing,
          result.drawing.constraints![0],
        ).map(Math.abs),
      ),
    ).toBeLessThan(1e-7);
    expect(source).toEqual(before);
  }
});
it("retains tangency when an arc endpoint is dragged", () => {
  const { drawing } = createSketchTangentArc(
    line(),
    { contour: 0, segment: 0, endpoint: 1 },
    [5, 5],
  );
  const moved = dragSketchEntity(
    drawing,
    { contour: 0, kind: "point", index: 2 },
    [1, 2],
  );
  expect(
    Math.max(
      ...constraintResiduals(moved, moved.constraints![0]).map(Math.abs),
    ),
  ).toBeLessThan(1e-6);
});
it("starts at the beginning of a path with an explicit constrained branch", () => {
  const { drawing } = createSketchTangentArc(
    line(),
    { contour: 0, segment: 0, endpoint: 0 },
    [-15, 5],
  );
  expect(drawing.contours).toHaveLength(2);
  expect(
    Math.max(
      ...constraintResiduals(drawing, drawing.constraints![0]).map(Math.abs),
    ),
  ).toBeLessThan(1e-7);
});
it("supports finite curved endpoints and rejects stationary or straight-line cases", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [-10, 0],
        segments: [
          {
            type: "bezier",
            controls: [
              [-8, 0],
              [-2, 0],
            ],
            end: [0, 0],
          },
        ],
      },
    ],
  };
  const ref = pickTangentArcSource(d, [0, 0], 1);
  const { drawing } = createSketchTangentArc(d, ref, [5, 5]);
  expect(
    Math.max(
      ...constraintResiduals(drawing, drawing.constraints![0]).map(Math.abs),
    ),
  ).toBeLessThan(1e-7);
  expect(() => createSketchTangentArc(d, ref, [5, 0])).toThrow(/tangent line/);
  expect(() => pickTangentArcSource(d, [20, 20], 1)).toThrow(/endpoint/);
});
