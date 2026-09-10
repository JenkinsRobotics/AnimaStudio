import { expect, it } from "vitest";
import { extendSketchCurve } from "./extend-curves";
import { ExtensionNeedsEndpoint } from "./trim-extend";
import { validateSketchDrawing, type SketchDrawing } from "../drawing";
const point = (x: number, y: number) => ({
  type: "path" as const,
  start: [x, y] as [number, number],
  segments: [],
});
it("extends to the nearest collinear point on either side and ignores off-locus points", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [0, 0],
        segments: [{ type: "line", end: [5, 0] }],
      },
      point(7, 0),
      point(10, 0),
      point(6, 0.01),
      point(-3, 0),
    ],
    constraints: [
      {
        id: "h",
        kind: "horizontal",
        a: { kind: "line", contour: 0, index: 0 },
      },
    ],
  };
  const right = extendSketchCurve(d, [4.9, 0], 0.1);
  expect(right.contours[0]).toMatchObject({ segments: [{ end: [7, 0] }] });
  const left = extendSketchCurve(d, [0.1, 0], 0.2);
  expect(left.contours[0]).toMatchObject({ start: [-3, 0] });
  expect(right.constraints).toEqual(expect.arrayContaining(d.constraints!));
  expect(right.constraints!.at(-1)).toMatchObject({
    kind: "coincident",
    b: { kind: "point", contour: 1, index: 0 },
  });
  validateSketchDrawing(JSON.parse(JSON.stringify(right)));
  expect(d.contours[0]).toMatchObject({ segments: [{ end: [5, 0] }] });
});
it("extends circular and elliptical arcs to exact point boundaries", () => {
  for (const rx of [5, 10]) {
    const ry = 5;
    const d: SketchDrawing = {
      type: "drawing",
      contours: [
        {
          type: "path",
          start: [rx, 0],
          segments: [
            {
              type: "ellipse",
              end: [0, ry],
              radiusX: rx,
              radiusY: ry,
              rotationDegrees: 0,
              largeArc: false,
              sweep: true,
            },
          ],
        },
        point(-rx * 0.6, ry * 0.8),
        point(-rx, 0),
      ],
    };
    const next = extendSketchCurve(d, [0, ry], 0.2);
    const path = next.contours[0];
    if (path.type !== "path") throw Error();
    expect(path.segments[0].end[0]).toBeCloseTo(-rx * 0.6);
    expect(path.segments[0].end[1]).toBeCloseTo(ry * 0.8);
    validateSketchDrawing(next);
  }
  const arc: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [5, 0],
        segments: [
          {
            type: "arc",
            middle: [5 * Math.SQRT1_2, 5 * Math.SQRT1_2],
            end: [0, 5],
          },
        ],
      },
      point(-3, 4),
    ],
  };
  expect(extendSketchCurve(arc, [0, 5], 0.1).contours[0]).toMatchObject({
    segments: [{ end: [expect.closeTo(-3), expect.closeTo(4)] }],
  });
});
it("retains conflict guards and requires a second click if no point lies on the locus", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [0, 0],
        segments: [{ type: "line", end: [5, 0] }],
      },
      point(7, 0.01),
    ],
  };
  expect(() => extendSketchCurve(d, [5, 0], 0.1)).toThrow(
    ExtensionNeedsEndpoint,
  );
  d.contours.push(point(8, 0));
  d.constraints = [
    {
      id: "length",
      kind: "length",
      a: { kind: "line", contour: 0, index: 0 },
      value: 5,
    },
  ];
  const before = structuredClone(d);
  expect(() => extendSketchCurve(d, [5, 0], 0.1)).toThrow();
  expect(d).toEqual(before);
});
