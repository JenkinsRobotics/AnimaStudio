import { expect, it } from "vitest";
import { joinImportedContours } from "./join-contours";
import {
  contourClosed,
  type SketchDrawing,
  type SketchPoint,
} from "../drawing";
const line = (a: SketchPoint, b: SketchPoint) => ({
  type: "path" as const,
  start: a,
  segments: [{ type: "line" as const, end: b }],
});
it("joins shuffled and reversed edges into a closed contour without mutating source", () => {
  const d: SketchDrawing = {
      type: "drawing",
      contours: [
        line([0, 0], [10, 0]),
        line([0, 10], [10, 10]),
        line([0, 0], [0, 10]),
        line([10, 10], [10, 0]),
      ],
    },
    before = structuredClone(d),
    next = joinImportedContours(d);
  expect(next.contours).toHaveLength(1);
  expect(contourClosed(next.contours[0])).toBe(true);
  if (next.contours[0].type !== "path") throw Error();
  expect(next.contours[0].segments).toHaveLength(4);
  expect(d).toEqual(before);
});
it("reverses native Bezier controls and ellipse sweep while joining", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      line([0, 0], [10, 0]),
      {
        type: "path",
        start: [20, 0],
        segments: [
          {
            type: "bezier",
            controls: [
              [18, 3],
              [12, 3],
            ],
            end: [10, 0],
          },
        ],
      },
      {
        type: "path",
        start: [20, 10],
        segments: [
          {
            type: "ellipse",
            radiusX: 5,
            radiusY: 5,
            rotationDegrees: 0,
            largeArc: false,
            sweep: true,
            end: [20, 0],
          },
        ],
      },
    ],
  };
  const next = joinImportedContours(d),
    p = next.contours[0];
  if (p.type !== "path") throw Error();
  expect(p.segments[1]).toMatchObject({
    controls: [
      [12, 3],
      [18, 3],
    ],
    end: [20, 0],
  });
  expect(p.segments[2]).toMatchObject({ sweep: false, end: [20, 10] });
});
it("stops at branch nodes and keeps construction geometry separate", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      line([0, 0], [10, 0]),
      line([10, 0], [20, 0]),
      line([10, 0], [10, 10]),
    ],
  };
  expect(joinImportedContours(d).contours).toHaveLength(3);
  d.contours = [
    line([0, 0], [10, 0]),
    { ...line([10, 0], [20, 0]), construction: true },
  ];
  expect(joinImportedContours(d).contours).toHaveLength(2);
});
it("joins only within the supplied tolerance and refuses constrained topology", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [line([0, 0], [10, 0]), line([10.00001, 0], [20, 0])],
  };
  expect(joinImportedContours(d).contours).toHaveLength(2);
  expect(joinImportedContours(d, 0.0001).contours).toHaveLength(1);
  d.constraints = [
    { id: "h", kind: "horizontal", a: { kind: "line", contour: 0, index: 0 } },
  ];
  expect(() => joinImportedContours(d)).toThrow("before adding constraints");
});
