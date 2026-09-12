import { expect, it } from "vitest";
import { linearPattern } from "./pattern";
import { setPatternInstanceSuppressed } from "./pattern-suppression";
import { editPatternGroup } from "./pattern-group";
import { editDrawingDimension } from "./edit-dimension";
import { missingPatternInstances } from "./pattern-repair";
import { validateSketchDrawing } from "../drawing";
const fixture = () =>
  linearPattern(
    {
      type: "drawing",
      contours: [{ type: "circle", center: [0, 0], radius: 1 }],
      constraints: [
        {
          id: "radius",
          kind: "radius",
          a: { kind: "circle", contour: 0 },
          value: 1,
        },
      ],
    },
    [0],
    [10, 0],
    3,
  );
it("removes instance geometry while retaining its slot and restores current source with stable identity", () => {
  const p = fixture(),
    c = p.constraints![1],
    id = Object.keys(p.patternGroups!)[0];
  p.contours[c.b!.contour].id = "instance";
  const off = setPatternInstanceSuppressed(p, c.id, true);
  expect(off.contours).toHaveLength(2);
  expect(off.constraints!.find((q) => q.id === c.id)).toMatchObject({
    patternSuppression: { id: "instance" },
    patternInstance: 1,
  });
  expect(missingPatternInstances(off, id)).toEqual([]);
  const changed = editDrawingDimension(
      JSON.parse(JSON.stringify(off)),
      "radius",
      2,
    ),
    on = setPatternInstanceSuppressed(changed, c.id, false);
  expect(on.contours).toHaveLength(3);
  expect(on.contours[2]).toMatchObject({
    id: "instance",
    center: [10, 0],
    radius: expect.closeTo(2, 6),
  });
  expect(
    on.constraints!.find((q) => q.id === c.id)!.patternSuppression,
  ).toBeUndefined();
  expect(setPatternInstanceSuppressed(on, c.id, false)).toEqual(on);
  expect(p.contours).toHaveLength(3);
});
it("retains suppression through count edits and rejects dependent suppression", () => {
  const p = fixture(),
    c = p.constraints![1],
    id = Object.keys(p.patternGroups!)[0];
  const off = setPatternInstanceSuppressed(p, c.id, true);
  const grown = editPatternGroup(off, id, {
    kind: "linear",
    first: [20, 0],
    second: [0, 0],
    countFirst: 4,
    countSecond: 1,
  });
  expect(grown.contours).toHaveLength(3);
  expect(
    grown.constraints!.find((q) => q.id === c.id)!.patternSuppression,
  ).toBeDefined();
  validateSketchDrawing(grown);
  const last = grown.constraints!.find((q) => q.patternInstance === 3)!;
  const all = setPatternInstanceSuppressed(grown, last.id, true);
  const shrunk = editPatternGroup(all, id, {
    kind: "linear",
    first: [20, 0],
    second: [0, 0],
    countFirst: 2,
    countSecond: 1,
  });
  expect(shrunk.contours).toHaveLength(1);
  expect(shrunk.constraints!.some((q) => q.id === last.id)).toBe(false);
  validateSketchDrawing(shrunk);
  const dependent = fixture();
  dependent.constraints!.push({
    id: "instance-radius",
    kind: "radius",
    a: { kind: "circle", contour: 1 },
    value: 1,
  });
  expect(() =>
    setPatternInstanceSuppressed(dependent, dependent.constraints![1].id, true),
  ).toThrow(/dependent/);
});
it('does not copy the source identity into a restored anonymous instance after serialization',()=>{
 const p=fixture();p.contours[0].id='source';const relation=p.constraints![1];
 const saved=JSON.parse(JSON.stringify(setPatternInstanceSuppressed(p,relation.id,true)));
 const restored=setPatternInstanceSuppressed(saved,relation.id,false);expect(restored.contours[2].id).toBeUndefined();expect(restored.contours[0].id).toBe('source');validateSketchDrawing(restored);
});
