import { expect, it } from "vitest";
import { extendSketchCurve } from "./extend-curves";
import { linkExtendedEndpoint } from "./extension-point-link";
import { dragSketchEntity } from "./drag-entity";
import type { SketchDrawing } from "../drawing";
it("keeps a line endpoint attached when its boundary point moves after native reopening", () => {
  const source: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [0, 0],
        segments: [{ type: "line", end: [5, 0] }],
      },
      { type: "path", start: [8, 0], segments: [] },
    ],
    constraints: [
      {
        id: "h",
        kind: "horizontal",
        a: { kind: "line", contour: 0, index: 0 },
      },
    ],
  };
  const next = extendSketchCurve(source, [5, 0], 0.1);
  expect(source.constraints).toHaveLength(1);
  expect(next.constraints).toHaveLength(2);
  expect(
    linkExtendedEndpoint(next, { kind: "point", contour: 0, index: 1 }),
  ).toEqual(next);
  const moved = dragSketchEntity(
    JSON.parse(JSON.stringify(next)),
    { kind: "point", contour: 1, index: 0 },
    [2, 0],
  );
  const path = moved.contours[0];
  if (path.type !== "path") throw Error();
  expect(path.segments[0].end[0]).toBeCloseTo(10);
  expect(path.segments[0].end[1]).toBeCloseTo(0);
  expect(moved.constraints!.at(-1)).toEqual(next.constraints!.at(-1));
});
it("links conic endpoints but does not attach to implicit circle centers or near misses", () => {
  const d: SketchDrawing = {
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
      { type: "path", start: [-3, 4], segments: [] },
    ],
  };
  const next = extendSketchCurve(d, [0, 5], 0.1);
  expect(next.constraints!.at(-1)).toMatchObject({
    kind: "coincident",
    a: { kind: "point", contour: 0, index: 1 },
    b: { contour: 1 },
  });
  const source: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [0, 0],
        segments: [{ type: "line", end: [5, 0] }],
      },
      { type: "circle", center: [5, 0], radius: 1 },
      { type: "path", start: [5, 0.01], segments: [] },
    ],
  };
  expect(
    linkExtendedEndpoint(source, { kind: "point", contour: 0, index: 1 })
      .constraints,
  ).toBeUndefined();
});
