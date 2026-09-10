import { expect, it } from "vitest";
import { linearPattern } from "./pattern";
import {
  patternPlacements,
  setPatternPlacementSuppressed,
} from "./pattern-placement";
import { setPatternInstanceSuppressed } from "./pattern-suppression";
const fixture = () =>
  linearPattern(
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
  );
it("suppresses and restores every contour of one placement while retaining other placements", () => {
  const p = fixture(),
    id = Object.keys(p.patternGroups!)[0],
    ids = p
      .constraints!.filter((c) => c.patternInstance === 1)
      .map((c) => c.id);
  const off = setPatternPlacementSuppressed(p, id, 1, true);
  expect(off.contours).toHaveLength(4);
  expect(patternPlacements(off, id)[0]).toMatchObject({
    complete: true,
    suppressed: 2,
    relationIds: ids,
  });
  expect(patternPlacements(off, id)[1].suppressed).toBe(0);
  const on = setPatternPlacementSuppressed(
    JSON.parse(JSON.stringify(off)),
    id,
    1,
    false,
  );
  expect(on.contours).toHaveLength(6);
  expect(patternPlacements(on, id)[0]).toMatchObject({
    suppressed: 0,
    relationIds: ids,
  });
  expect(p.contours).toHaveLength(6);
  const partial = setPatternInstanceSuppressed(p, ids[0], true);
  expect(
    setPatternPlacementSuppressed(partial, id, 1, true).contours,
  ).toHaveLength(4);
});
it("does not expose a partial mutation when a later member has a dependency", () => {
  const p = fixture(),
    id = Object.keys(p.patternGroups!)[0],
    second = p.constraints!.find(
      (c) => c.patternInstance === 1 && c.a.contour === 1,
    )!;
  p.constraints!.push({
    id: "dependent",
    kind: "radius",
    a: { kind: "circle", contour: second.b!.contour },
    value: 2,
  });
  const before = structuredClone(p);
  expect(() => setPatternPlacementSuppressed(p, id, 1, true)).toThrow(
    /dependent/,
  );
  expect(p).toEqual(before);
  expect(() => setPatternPlacementSuppressed(p, id, 0, true)).toThrow(
    /existing repeated/,
  );
});
