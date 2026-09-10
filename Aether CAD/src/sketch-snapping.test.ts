import { expect, it } from "vitest";
import { snapSketchPoint } from "./sketch-snapping";
import type { SketchDrawing } from "@aether/core/sketch";
it("prefers origin, endpoints, midpoints and centers over grid and supports alignment", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [10.25, 10.25],
        segments: [{ type: "line", end: [20.25, 10.25] }],
      },
      { type: "circle", center: [25.5, 25.5], radius: 3 },
    ],
  };
  for (const [p, label, target] of [
    [[0.1, 0.2], "Origin", [0, 0]],
    [[10.4, 10.2], "Endpoint", [10.25, 10.25]],
    [[15.3, 10.4], "Midpoint", [15.25, 10.25]],
    [[25.4, 25.6], "Center", [25.5, 25.5]],
  ] as const) {
    const result = snapSketchPoint([...p], d, undefined, 0.5);
    expect(result.label).toBe(label);
    expect(result.point).toEqual(target);
  }
  expect(snapSketchPoint([45, 12.2], d, [30, 12], 0.5).label).toBe(
    "Horizontal",
  );
  expect(snapSketchPoint([30.2, 50], d, [30, 12], 0.5).point).toEqual([30, 50]);
  expect(
    snapSketchPoint([40.25, 40.75], d, undefined, 0.5, false).point,
  ).toEqual([40.25, 40.75]);
});
it("shows quadrant snapping on ellipse axis endpoints without grid rounding", async () => {
  const { constrainSketchEllipse, sketchVariantContour } =
    await import("@aether/core/sketch");
  const d = constrainSketchEllipse(
    {
      type: "drawing",
      contours: [
        sketchVariantContour("ellipse", [
          [0, 0],
          [4, 0],
          [0, 2],
        ]),
      ],
    },
    0,
  );
  expect(snapSketchPoint([0.1, 2.1], d, undefined, 0.3, false)).toMatchObject({
    label: "Quadrant",
  });
  expect(snapSketchPoint([4.1, 0.1], d, undefined, 0.3, false).label).toBe(
    "Quadrant",
  );
});
it("snaps to analytic arc centers, including arcs later in a path", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [20, 20],
        segments: [
          { type: "line", end: [15, 10] },
          { type: "arc", middle: [10, 15], end: [5, 10] },
        ],
      },
    ],
  };
  expect(snapSketchPoint([10.1, 9.9], d, undefined, 0.3, false)).toEqual({
    point: [10, 10],
    label: "Arc center",
  });
  expect(snapSketchPoint([10.1, 9.9], d, undefined, 0.3, true)).toEqual({
    point: [10, 10],
    label: "Arc center",
  });
  expect(snapSketchPoint([11, 9], d, undefined, 0.3, false).label).toBe("");
});
it("keeps other snap targets available with a degenerate arc", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [2, 0],
        segments: [{ type: "arc", middle: [3, 0], end: [4, 0] }],
      },
    ],
  };
  expect(snapSketchPoint([4.1, 0], d, undefined, 0.3, false)).toEqual({
    point: [4, 0],
    label: "Endpoint",
  });
});

it("snaps to a projected circle quadrant before grid rounding", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [],
    projectionContext: [
      { id: "circle", type: "circle", center: [10, 10], radius: 5 },
    ],
  };
  expect(snapSketchPoint([10.1, 15.1], d, undefined, 0.5)).toEqual({
    point: [10, 15],
    label: "Projected quadrant",
  });
});

it("snaps along a projected edge while preserving priority for its midpoint", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [],
    projectionContext: [
      {
        id: "edge",
        type: "path",
        start: [10, 10],
        segments: [{ type: "line", end: [20, 10] }],
      },
    ],
  };
  expect(snapSketchPoint([12.3, 10.1], d, undefined, 0.2)).toEqual({
    point: [12.3, 10],
    label: "Projected curve",
  });
  expect(snapSketchPoint([15.1, 10.1], d, undefined, 0.2).label).toBe(
    "Projected midpoint",
  );
});
