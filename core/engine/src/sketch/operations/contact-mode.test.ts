import { expect, it } from "vitest";
import { setSketchContactSliding } from "./contact-mode";
import { dragSketchEntity } from "./drag-entity";
import { sketchConstraintState } from "../solver/diagnostics";
import type { SketchDrawing } from "../drawing";
it("releases then freezes a contact at its solved parameter without moving saved geometry", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [0, 0],
        segments: [{ type: "line", end: [4, 0] }],
      },
      { type: "path", start: [1, 0], segments: [] },
    ],
    constraints: [
      {
        id: "p0",
        kind: "fix",
        a: { kind: "point", contour: 0, index: 0 },
        point: [0, 0],
      },
      {
        id: "p1",
        kind: "fix",
        a: { kind: "point", contour: 0, index: 1 },
        point: [4, 0],
      },
      {
        id: "contact",
        kind: "coincident",
        a: { kind: "point", contour: 1, index: 0 },
        b: { kind: "curve", contour: 0, index: 0, parameter: 0.25 },
      },
    ],
  };
  expect(sketchConstraintState(d).degreesOfFreedom).toBe(0);
  const sliding = setSketchContactSliding(d, "contact", "b", true);
  expect(sliding.contours).toEqual(d.contours);
  expect(sketchConstraintState(sliding).degreesOfFreedom).toBe(1);
  const moved = dragSketchEntity(
      sliding,
      { kind: "point", contour: 1, index: 0 },
      [2, 0],
    ),
    fixed = setSketchContactSliding(
      JSON.parse(JSON.stringify(moved)),
      "contact",
      "b",
      false,
    );
  expect(fixed.contours).toEqual(moved.contours);
  expect(fixed.constraints!.at(-1)).toMatchObject({
    id: "contact",
    b: { parameter: expect.closeTo(0.75), sliding: false },
  });
  expect(sketchConstraintState(fixed).degreesOfFreedom).toBe(0);
  expect(() =>
    dragSketchEntity(fixed, { kind: "point", contour: 1, index: 0 }, [0.2, 0]),
  ).toThrow();
  expect(d.constraints!.at(-1)!.b!.sliding).toBeUndefined();
});
it("rejects non-contact selections without mutating input", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [{ type: "circle", center: [0, 0], radius: 1 }],
    constraints: [
      { id: "r", kind: "radius", a: { kind: "circle", contour: 0 }, value: 1 },
    ],
  };
  const before = structuredClone(d);
  expect(() => setSketchContactSliding(d, "r", "a", true)).toThrow(/contact/);
  expect(() => setSketchContactSliding(d, "missing", "b", true)).toThrow(
    /contact/,
  );
  expect(d).toEqual(before);
});
