import { patternRelationTransform } from "../pattern-groups";
import { expect, it } from "vitest";
import { linearPattern, circularPattern } from "./pattern";
import {
  editDrawingDimension,
  removeDrawingConstraint,
} from "./edit-dimension";
import { dragSketchEntity } from "./drag-entity";
import { validateSketchDrawing, type SketchDrawing } from "../drawing";
import { patternResiduals } from "../solver/pattern";
import { sketchConstraintState } from "../solver/diagnostics";
const circle = (): SketchDrawing => ({
  type: "drawing",
  contours: [{ type: "circle", center: [5, 0], radius: 2 }],
  constraints: [
    {
      id: "radius",
      kind: "radius",
      a: { kind: "circle", contour: 0 },
      value: 2,
    },
  ],
});
it("propagates radius and source-position edits through linear and circular instances after serialization", () => {
  for (const make of [
    (d: SketchDrawing) => linearPattern(d, [0], [10, 0], 3),
    (d: SketchDrawing) => circularPattern(d, [0], [0, 0], 3, 120),
  ]) {
    const source = circle(),
      pattern = make(source);
    expect(
      pattern.constraints!.filter((c) => c.kind === "pattern"),
    ).toHaveLength(2);
    const edited = editDrawingDimension(
      JSON.parse(JSON.stringify(pattern)),
      "radius",
      4,
    );
    for (const c of edited.contours) {
      if (c.type !== "circle") throw Error();
      expect(c.radius).toBeCloseTo(4, 6);
    }
    const moved = dragSketchEntity(
      edited,
      { kind: "point", contour: 0, index: 0 },
      [2, 3],
    );
    for (const relation of moved.constraints!.filter(
      (c) => c.kind === "pattern",
    ))
      expect(
        Math.max(
          ...patternResiduals(
            moved.contours[relation.a.contour],
            moved.contours[relation.b!.contour],
            patternRelationTransform(moved, relation),
          ).map(Math.abs),
        ),
      ).toBeLessThan(1e-6);
    expect(sketchConstraintState(pattern).degreesOfFreedom).toBe(2);
    expect(source).toEqual(circle());
  }
});
it("propagates a cubic control edit and permits explicit instance detachment", () => {
  const source: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [0, 0],
        segments: [
          {
            type: "bezier",
            controls: [
              [3, 4],
              [7, 4],
            ],
            end: [10, 0],
          },
        ],
      },
    ],
  };
  const p = linearPattern(source, [0], [20, 0], 2),
    moved = dragSketchEntity(
      p,
      { kind: "point", contour: 0, index: 0, control: 0 },
      [0, 2],
    );
  const a = moved.contours[0],
    b = moved.contours[1];
  if (
    a.type !== "path" ||
    b.type !== "path" ||
    a.segments[0].type !== "bezier" ||
    b.segments[0].type !== "bezier"
  )
    throw Error();
  expect(
    b.segments[0].controls[0][0] - a.segments[0].controls[0][0],
  ).toBeCloseTo(20, 6);
  expect(b.segments[0].controls[0][1]).toBeCloseTo(6, 6);
  const detached = removeDrawingConstraint(moved, moved.constraints![0].id);
  expect(detached.constraints).toHaveLength(0);
  expect(detached.contours).toEqual(moved.contours);
});
it("keeps arc geometry independent of through-point gauge and rejects incompatible topology", () => {
  const source: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [1, 0],
        segments: [
          { type: "arc", middle: [Math.SQRT1_2, Math.SQRT1_2], end: [0, 1] },
        ],
      },
    ],
  };
  const p = circularPattern(source, [0], [0, 0], 2, 90);
  expect(sketchConstraintState(p).degreesOfFreedom).toBe(5);
  const bad = structuredClone(p);
  if (bad.contours[1].type !== "path") throw Error();
  bad.contours[1].segments.push({ type: "line", end: [20, 20] });
  expect(() => validateSketchDrawing(bad)).toThrow(/topology/);
});
