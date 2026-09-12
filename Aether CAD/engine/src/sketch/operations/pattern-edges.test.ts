import { expect, it } from "vitest";
import { linearPattern, circularPattern } from "./pattern";
import { editPatternGroup } from "./pattern-group";
import {
  missingPatternInstances,
  restorePatternInstances,
} from "./pattern-repair";
import {
  patternPlacements,
  setPatternPlacementSuppressed,
} from "./pattern-placement";
import { validateSketchDrawing, type SketchDrawing } from "../drawing";
import type { SketchEntityRef } from "../solver/types";
const source: SketchDrawing = {
  type: "drawing",
  contours: [
    {
      type: "path",
      start: [0, 0],
      segments: [
        { type: "line", end: [5, 0] },
        { type: "line", end: [5, 5] },
        { type: "line", end: [10, 5] },
      ],
    },
  ],
};
const refs: SketchEntityRef[] = [
  { kind: "line", contour: 0, index: 0 },
  { kind: "line", contour: 0, index: 2 },
];
const identifiedRefs = refs.map((ref, index) => ({
  ...ref,
  segmentId: `source-edge-${index + 1}`,
}));
it("retains separate same-contour edges through native JSON and count/spacing edits", () => {
  const p = linearPattern(source, refs, [20, 0], 3),
    id = Object.keys(p.patternGroups!)[0];
  expect(p.contours).toHaveLength(5);
  expect(p.contours[1]).toMatchObject({
    start: [20, 0],
    segments: [{ type: "line", end: [25, 0] }],
  });
  expect(p.contours[2]).toMatchObject({
    start: [25, 5],
    segments: [{ type: "line", end: [30, 5] }],
  });
  const grown = editPatternGroup(JSON.parse(JSON.stringify(p)), id, {
    kind: "linear",
    first: [30, 0],
    second: [0, 20],
    countFirst: 4,
    countSecond: 1,
  });
  expect(grown.contours).toHaveLength(7);
  expect(grown.constraints!.slice(0, 4)).toEqual(p.constraints);
  expect(grown.constraints!.slice(-2).map((c) => c.a)).toEqual(identifiedRefs);
  const shrunk = editPatternGroup(grown, id, {
    kind: "linear",
    first: [30, 0],
    second: [0, 20],
    countFirst: 2,
    countSecond: 1,
  });
  expect(shrunk.contours).toHaveLength(3);
  expect(shrunk.constraints!.map((c) => c.a)).toEqual(identifiedRefs);
  validateSketchDrawing(shrunk);
});
it("repairs only the missing edge membership and suppresses/restores entire placements", () => {
  const p = linearPattern(source, refs, [20, 0], 3),
    id = Object.keys(p.patternGroups!)[0];
  p.constraints!.splice(1, 1);
  expect(missingPatternInstances(p, id)).toEqual([
    { sourceContour: 0, source: identifiedRefs[1], instance: 1 },
  ]);
  const repaired = restorePatternInstances(p, id);
  expect(repaired.contours).toHaveLength(6);
  expect(repaired.contours[2]).toEqual(p.contours[2]);
  expect(
    patternPlacements(repaired, id).every(
      (p) => p.complete && p.relationIds.length === 2,
    ),
  ).toBe(true);
  const off = setPatternPlacementSuppressed(repaired, id, 1, true);
  expect(off.contours).toHaveLength(4);
  const on = setPatternPlacementSuppressed(
    JSON.parse(JSON.stringify(off)),
    id,
    1,
    false,
  );
  expect(on.contours).toHaveLength(6);
  for (const c of on.constraints!.filter((c) => c.patternInstance === 1))
    expect(on.contours[c.b!.contour]).toMatchObject({
      type: "path",
      segments: [{ type: "line", end: expect.any(Array) }],
    });
  validateSketchDrawing(on);
});
it("patterns selected edges circularly and reseeds them from edited source geometry", () => {
  const p = circularPattern(source, [...refs, refs[0]], [0, 0], 3, 90),
    id = Object.keys(p.patternGroups!)[0];
  expect(p.contours).toHaveLength(5);
  const changed = structuredClone(p);
  const path = changed.contours[0];
  if (path.type !== "path") throw Error("Expected path");
  path.segments[2].end = [12, 5];
  const next = editPatternGroup(changed, id, {
    kind: "circular",
    center: [0, 0],
    count: 3,
    stepDegrees: 90,
  });
  const target = next.contours[2];
  if (target.type !== "path") throw Error("Expected path");
  expect(target.segments[0].end[0]).toBeCloseTo(-5);
  expect(target.segments[0].end[1]).toBeCloseTo(12);
  validateSketchDrawing(next);
});
