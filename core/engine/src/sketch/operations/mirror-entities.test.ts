import { expect, it } from "vitest";
import { mirrorSketchEntities } from "./mirror-entities";
import { editMirrorAxis } from "./mirror-edit";
import { dragSketchEntity } from "./drag-entity";
import { validateSketchDrawing, type SketchDrawing } from "../drawing";
it("mirrors a selected edge about another edge in the same contour and follows endpoint edits", () => {
  const source: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [0, -10],
        segments: [
          { type: "line", end: [0, 10] },
          { type: "line", end: [5, 10] },
          { type: "line", end: [5, 0] },
        ],
      },
    ],
    constraints: [
      {
        id: "a",
        kind: "fix",
        a: { contour: 0, kind: "point", index: 0 },
        point: [0, -10],
      },
      {
        id: "b",
        kind: "fix",
        a: { contour: 0, kind: "point", index: 1 },
        point: [0, 10],
      },
    ],
  };
  const p = mirrorSketchEntities(
    source,
    [{ contour: 0, kind: "line", index: 2 }],
    [0, 0],
    [0, 1],
    { contour: 0, kind: "line", index: 0 },
  );
  expect(p.contours).toHaveLength(2);
  expect(p.contours[1]).toMatchObject({
    start: [-5, 10],
    segments: [{ type: "line", end: [-5, 0] }],
  });
  const identified = structuredClone(source.contours[0]);
  if (identified.type !== "path") throw Error();
  identified.segments[0].id = "source-edge-2";
  identified.segments[2].id = "source-edge-1";
  expect(p.contours[0]).toEqual(identified);
  const moved = dragSketchEntity(
    JSON.parse(JSON.stringify(p)),
    { contour: 0, kind: "point", index: 3 },
    [2, 0],
  );
  const target = moved.contours[1];
  if (target.type !== "path") throw Error();
  expect(target.segments[0].end[0]).toBeCloseTo(-7, 6);
  const edited = editMirrorAxis(moved, moved.constraints!.at(-1)!.id, {
    axis: { contour: 0, kind: "line", index: 0 },
  });
  validateSketchDrawing(edited);
  expect(() =>
    mirrorSketchEntities(
      source,
      [{ contour: 0, kind: "line", index: 0 }],
      [0, 0],
      [0, 1],
      { contour: 0, kind: "line", index: 0 },
    ),
  ).toThrow(/axis itself/);
});
it("mirrors a stationary-end cubic edge without requiring a tangent contact", () => {
  const source: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [2, 0],
        segments: [
          {
            type: "bezier",
            controls: [
              [2, 0],
              [5, 5],
            ],
            end: [8, 0],
          },
          { type: "line", end: [10, 0] },
        ],
      },
    ],
  };
  const p = mirrorSketchEntities(
    source,
    [{ contour: 0, kind: "curve", index: 0, parameter: 0 }],
    [0, 0],
    [0, 10],
  );
  expect(p.contours[1]).toMatchObject({
    start: [-2, 0],
    segments: [
      {
        type: "bezier",
        controls: [
          [-2, 0],
          [-5, 5],
        ],
        end: [-8, 0],
      },
    ],
  });
  validateSketchDrawing(p);
  expect(p.constraints![0].a).toMatchObject({
    contour: 0,
    kind: "curve",
    index: 0,
  });
});
