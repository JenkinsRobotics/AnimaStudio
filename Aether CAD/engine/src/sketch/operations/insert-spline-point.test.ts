import { expect, it } from "vitest";
import { insertSketchSplinePoint } from "./insert-spline-point";
import { segmentPoint } from "../curves/parameterization";
import { constraintResiduals } from "../solver/residuals";
import { dragSketchEntity } from "./drag-entity";
import type { SketchDrawing } from "../drawing";

const fixture = (): SketchDrawing => ({
  type: "drawing",
  contours: [
    {
      type: "path",
      start: [0, 0],
      segments: [
        {
          type: "bezier",
          controls: [
            [3, 6],
            [7, 6],
          ],
          end: [10, 0],
        },
      ],
    },
  ],
});

it("inserts an exact cubic join and retains smoothness after a saved point edit", () => {
  const source = fixture(),
    before = structuredClone(source);
  const next = insertSketchSplinePoint(source, [5, 4.5], 0.1);
  const a = source.contours[0],
    b = next.contours[0];
  if (a.type !== "path" || b.type !== "path") throw Error("path");
  expect(b.segments).toHaveLength(2);
  for (let i = 0; i <= 20; i++) {
    const t = i / 20,
      right = t > 0.5;
    const p = segmentPoint(a.start, a.segments[0], t);
    const q = segmentPoint(
      right ? b.segments[0].end : b.start,
      b.segments[right ? 1 : 0],
      right ? 2 * t - 1 : 2 * t,
    );
    expect(q[0]).toBeCloseTo(p[0], 6);
    expect(q[1]).toBeCloseTo(p[1], 6);
  }
  const moved = dragSketchEntity(
    JSON.parse(JSON.stringify(next)),
    { kind: "point", contour: 0, index: 1 },
    [0, 1],
  );
  for (const c of moved.constraints!)
    expect(constraintResiduals(moved, c).every((v) => Math.abs(v) < 1e-6)).toBe(
      true,
    );
  const edited = moved.contours[0];
  if (edited.type !== "path") throw Error("path");
  expect(edited.segments[0].end[1]).toBeCloseTo(5.5, 5);
  expect(source).toEqual(before);
});

it("rejects endpoint insertion and noncubic geometry without mutation", () => {
  expect(() => insertSketchSplinePoint(fixture(), [0, 0], 0.1)).toThrow(
    "endpoints",
  );
  const line: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [0, 0],
        segments: [{ type: "line", end: [10, 0] }],
      },
    ],
  };
  expect(() => insertSketchSplinePoint(line, [5, 0], 0.1)).toThrow("cubic");
  expect(line.contours).toHaveLength(1);
});

it("remaps saved contacts and supports a second insertion with unique continuity IDs", () => {
  const d = fixture(),
    c = d.contours[0];
  if (c.type !== "path") throw Error("path");
  const contact = segmentPoint(c.start, c.segments[0], 0.75);
  d.contours.push({ type: "path", start: contact, segments: [] });
  d.constraints = [
    {
      id: "contact",
      kind: "coincident",
      a: { kind: "point", contour: 1, index: 0 },
      b: {
        kind: "curve",
        contour: 0,
        index: 0,
        parameter: 0.75,
        sliding: true,
      },
    },
  ];
  const next = insertSketchSplinePoint(d, [5, 4.5], 0.1);
  expect(next.constraints![0].b).toMatchObject({
    index: 1,
    parameter: 0.5,
    sliding: true,
  });
  const again = insertSketchSplinePoint(
    next,
    segmentPoint(c.start, c.segments[0], 0.25),
    0.1,
  );
  expect(new Set(again.constraints!.map((c) => c.id)).size).toBe(
    again.constraints!.length,
  );
  for (const c of again.constraints!)
    expect(constraintResiduals(again, c).every((v) => Math.abs(v) < 1e-6)).toBe(
      true,
    );
});
