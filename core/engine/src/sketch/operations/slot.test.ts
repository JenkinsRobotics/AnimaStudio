import { expect, it } from "vitest";
import { slotSketchEntities } from "./slot";
import { editDrawingDimension } from "./edit-dimension";
import { solveDrawingConstraints } from "../solver/solve";
import { constraintResiduals } from "../solver/residuals";
import { contourClosed, type SketchDrawing } from "../drawing";
const source = (): SketchDrawing => ({
  type: "drawing",
  contours: [
    { type: "path", start: [0, 0], segments: [{ type: "line", end: [10, 0] }] },
    {
      type: "path",
      start: [5, 0],
      segments: [
        {
          type: "arc",
          middle: [Math.sqrt(12.5), Math.sqrt(12.5)],
          end: [0, 5],
        },
      ],
    },
  ],
});
it("builds exact closed line/arc slots sharing one editable width", () => {
  const d = source(),
    before = structuredClone(d),
    next = slotSketchEntities(
      d,
      [
        { kind: "line", contour: 0, index: 0 },
        { kind: "arc", contour: 1, index: 0 },
      ],
      2,
    );
  expect(next.contours).toHaveLength(4);
  expect(next.contours[0].construction).toBe(true);
  expect(next.contours.slice(2).every(contourClosed)).toBe(true);
  expect(next.constraints?.[1]).toMatchObject({
    kind: "slot",
    valueFrom: "slot-1",
  });
  const edited = editDrawingDimension(next, "slot-2", 3);
  for (const c of edited.constraints!)
    for (const r of constraintResiduals(edited, c))
      expect(Math.abs(r)).toBeLessThan(1e-6);
  expect(edited.constraints![0].value).toBe(3);
  expect(d).toEqual(before);
});
it("follows a centerline that changes length and direction", () => {
  const d = slotSketchEntities(
    source(),
    [{ kind: "line", contour: 0, index: 0 }],
    2,
  );
  d.constraints!.push(
    {
      id: "start",
      kind: "fix",
      a: { kind: "point", contour: 0, index: 0 },
      point: [2, 3],
    },
    {
      id: "end",
      kind: "fix",
      a: { kind: "point", contour: 0, index: 1 },
      point: [2, 23],
    },
  );
  const solved = solveDrawingConstraints(d),
    slot = solved.contours[2];
  if (slot.type !== "path") throw Error();
  expect(slot.start[0]).toBeCloseTo(1, 5);
  expect(slot.start[1]).toBeCloseTo(3, 5);
  expect(slot.segments[0].end[1]).toBeCloseTo(23, 5);
});
it("rejects invalid widths/centerlines and oversized arcs without partial mutation", () => {
  const d = source(),
    before = structuredClone(d);
  for (const width of [0, -1, NaN])
    expect(() =>
      slotSketchEntities(d, [{ kind: "line", contour: 0, index: 0 }], width),
    ).toThrow();
  expect(() =>
    slotSketchEntities(d, [{ kind: "arc", contour: 1, index: 0 }], 12),
  ).toThrow("collapses");
  expect(() =>
    slotSketchEntities(d, [{ kind: "circle", contour: 0 }], 2),
  ).toThrow("centerline");
  expect(d).toEqual(before);
});
it("retains only centerline degrees of freedom and rejects overlapping major-arc caps", async () => {
  const { sketchConstraintState } = await import("../solver/diagnostics");
  const d = slotSketchEntities(
    { type: "drawing", contours: [source().contours[0]] },
    [{ kind: "line", contour: 0, index: 0 }],
    2,
  );
  expect(sketchConstraintState(d)).toMatchObject({
    degreesOfFreedom: 4,
    redundantEquations: 0,
  });
  expect(() =>
    slotSketchEntities(
      {
        type: "drawing",
        contours: [
          {
            type: "path",
            start: [5, 0],
            segments: [{ type: "arc", middle: [-5, 0], end: [0, -5] }],
          },
        ],
      },
      [{ kind: "arc", contour: 0, index: 0 }],
      8,
    ),
  ).toThrow("overlap");
});
