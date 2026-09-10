import { expect, it } from "vitest";
import { linearPattern } from "./pattern";
import { removeDrawingConstraint } from "./edit-dimension";
import { editPatternGroup } from "./pattern-group";
import {
  missingPatternInstances,
  restorePatternInstances,
} from "./pattern-repair";
import { deleteSketchContour } from "./delete";
it("restores a missing membership without overwriting or reattaching detached geometry", () => {
  const p = linearPattern(
      {
        type: "drawing",
        contours: [{ type: "circle", center: [0, 0], radius: 1 }],
      },
      [0],
      [10, 0],
      3,
    ),
    id = Object.keys(p.patternGroups!)[0];
  const detached = removeDrawingConstraint(p, p.constraints![0].id);
  detached.contours[1].id = "detached";
  if (detached.contours[1].type !== "circle") throw Error();
  detached.contours[1].center = [99, 99];
  const before = structuredClone(detached);
  expect(missingPatternInstances(detached, id)).toEqual([
    { sourceContour: 0, source: {kind:"contour",contour:0}, instance: 1 },
  ]);
  const fixed = restorePatternInstances(
    JSON.parse(JSON.stringify(detached)),
    id,
  );
  expect(fixed.contours).toHaveLength(4);
  expect(fixed.contours.slice(0, 3)).toEqual(before.contours);
  expect(fixed.contours[3]).toMatchObject({ center: [10, 0] });
  expect(
    fixed.constraints!.find((c) => c.patternInstance === 1)!.b!.contour,
  ).toBe(3);
  expect(restorePatternInstances(fixed, id)).toEqual(fixed);
  expect(detached).toEqual(before);
  expect(
    editPatternGroup(fixed, id, {
      kind: "linear",
      first: [10, 0],
      second: [0, 0],
      countFirst: 4,
      countSecond: 1,
    }).contours,
  ).toHaveLength(5);
});
it("repairs a deleted instance with remapped sources and rejects fully detached groups", () => {
  const p = linearPattern(
      {
        type: "drawing",
        contours: [
          { type: "circle", center: [0, 0], radius: 1 },
          { type: "circle", center: [5, 0], radius: 2 },
        ],
      },
      [0, 1],
      [20, 0],
      3,
    ),
    id = Object.keys(p.patternGroups!)[0];
  const deleted = deleteSketchContour(p, 2),
    fixed = restorePatternInstances(deleted, id);
  expect(fixed.contours).toHaveLength(6);
  expect(missingPatternInstances(fixed, id)).toEqual([]);
  const empty = structuredClone(p);
  empty.constraints = [];
  expect(() => restorePatternInstances(empty, id)).toThrow(/No linked sources/);
});
