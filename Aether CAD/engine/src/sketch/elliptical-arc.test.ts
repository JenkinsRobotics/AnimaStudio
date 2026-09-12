import { expect, it } from "vitest";
import { sketchVariantContour } from "./primitives";
import { ellipticalArcGuide } from "./elliptical-arc";
import { ellipseFrame } from "./curves/parameterization";
import { validateSketchDrawing } from "./drawing";
it.each([false, true])(
  "creates an exact elliptical arc and guide clockwise=%s",
  (clockwise) => {
    const points: [number, number][] = [
      [0, 0],
      [5, 0],
      [3, 2.4],
      [0, -10],
    ];
    const c = sketchVariantContour("elliptical-arc", points, 6, { clockwise });
    if (c.type !== "path" || c.segments[0].type !== "ellipse") throw Error();
    const g = ellipseFrame(c.start, c.segments[0]);
    expect(g.radiusX).toBeCloseTo(5);
    expect(g.radiusY).toBeCloseTo(3);
    expect(g.center[0]).toBeCloseTo(0);
    expect(g.center[1]).toBeCloseTo(0);
    expect(Math.sign(g.sweep)).toBe(clockwise ? -1 : 1);
    expect(c.start[0]).toBeCloseTo(3);
    expect(c.start[1]).toBeCloseTo(2.4);
    expect(c.segments[0].end[1]).toBeCloseTo(-3);
    expect(c.segments[0].largeArc).toBe(!clockwise);
    const guide = ellipticalArcGuide(points.slice(0, 3));
    expect(guide.construction).toBe(true);
    validateSketchDrawing({ type: "drawing", contours: [c, guide] });
  },
);
it("supports rotated frames and rejects undefined radius or repeated endpoints", () => {
  const c = sketchVariantContour("elliptical-arc", [
    [10, 20],
    [10, 25],
    [7.6, 23],
    [20, 20],
  ]);
  if (c.type !== "path" || c.segments[0].type !== "ellipse") throw Error();
  const g = ellipseFrame(c.start, c.segments[0]);
  expect(g.center[0]).toBeCloseTo(10);
  expect(g.center[1]).toBeCloseTo(20);
  expect(g.radiusY).toBeCloseTo(3);
  expect(() =>
    sketchVariantContour("elliptical-arc", [
      [0, 0],
      [5, 0],
      [5, 0],
      [0, 3],
    ]),
  ).toThrow(/start/);
  expect(() =>
    sketchVariantContour("elliptical-arc", [
      [0, 0],
      [5, 0],
      [0, 3],
      [0, 6],
    ]),
  ).toThrow(/endpoints/);
});
it("starts on either primary-axis endpoint when secondary radius is specified", () => {
  for (const side of [1, -1]) {
    const c = sketchVariantContour(
      "elliptical-arc",
      [
        [0, 0],
        [5, 0],
        [side * 10, 0],
        [0, 6],
      ],
      6,
      { secondaryRadiusMillimeters: 3 },
    );
    if (c.type !== "path" || c.segments[0].type !== "ellipse") throw Error();
    const e = ellipseFrame(c.start, c.segments[0]);
    expect(c.start[0]).toBeCloseTo(side * 5);
    expect(c.start[1]).toBeCloseTo(0);
    expect(e.radiusY).toBeCloseTo(3);
    expect(c.segments[0].end[1]).toBeCloseTo(3);
  }
  for (const radius of [0, -1, Infinity, NaN])
    expect(() =>
      sketchVariantContour(
        "elliptical-arc",
        [
          [0, 0],
          [5, 0],
          [5, 0],
          [0, 3],
        ],
        6,
        { secondaryRadiusMillimeters: radius },
      ),
    ).toThrow(/radius/);
});
it("uses remembered radius only at an ambiguous axis start", () => {
  const options = { rememberedRadiusMillimeters: 3 };
  const axis = sketchVariantContour(
    "elliptical-arc",
    [
      [0, 0],
      [5, 0],
      [5, 0],
      [0, 9],
    ],
    6,
    options,
  );
  const free = sketchVariantContour(
    "elliptical-arc",
    [
      [0, 0],
      [5, 0],
      [0, 4],
      [5, 0],
    ],
    6,
    options,
  );
  const explicit = sketchVariantContour(
    "elliptical-arc",
    [
      [0, 0],
      [5, 0],
      [5, 0],
      [0, 9],
    ],
    6,
    { ...options, secondaryRadiusMillimeters: 2 },
  );
  for (const [c, radius] of [
    [axis, 3],
    [free, 4],
    [explicit, 2],
  ] as const) {
    if (c.type !== "path" || c.segments[0].type !== "ellipse") throw Error();
    expect(c.segments[0].radiusY).toBeCloseTo(radius);
  }
});
