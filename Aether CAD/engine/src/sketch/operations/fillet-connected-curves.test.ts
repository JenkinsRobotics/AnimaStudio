import { it, expect } from "vitest";
import { filletSketchCurves } from "./fillet-curves";
import { contourClosed, type SketchDrawing } from "../drawing";
import { constraintResiduals } from "../drawing-constraints";
const drawing = (): SketchDrawing => ({
  type: "drawing",
  contours: [
    {
      type: "path",
      start: [-10, 0],
      segments: [
        { type: "line", end: [0, 0] },
        {
          type: "bezier",
          controls: [
            [1, 3],
            [2, 7],
          ],
          end: [0, 10],
        },
        { type: "line", end: [-10, 10] },
        { type: "line", end: [-10, 0] },
      ],
    },
  ],
  constraints: [
    {
      id: "outer",
      kind: "fix",
      a: { contour: 0, kind: "point", index: 2 },
      point: [0, 10],
    },
    {
      id: "length",
      kind: "length",
      a: { contour: 0, kind: "line", index: 2 },
      value: 10,
    },
  ],
});
it("rounds a connected line/Bezier corner and preserves later path geometry and references", () => {
  const source = drawing(),
    before = structuredClone(source),
    result = filletSketchCurves(
      source,
      { contour: 0, segment: 1 },
      { contour: 0, segment: 0 },
      1,
    );
  expect(source).toEqual(before);
  expect(result.contours).toHaveLength(1);
  const path = result.contours[0];
  if (path.type !== "path") throw Error();
  expect(contourClosed(path)).toBe(true);
  expect(path.segments.map((s) => s.type)).toEqual([
    "line",
    "arc",
    "bezier",
    "line",
    "line",
  ]);
  expect(path.segments.slice(3)).toEqual(
    (source.contours[0] as typeof path).segments.slice(2),
  );
  expect(result.constraints!.find((c) => c.id === "outer")!.a.index).toBe(3);
  expect(result.constraints!.find((c) => c.id === "length")!.a.index).toBe(3);
  for (const c of result.constraints!)
    for (const r of constraintResiduals(result, c))
      expect(Math.abs(r)).toBeLessThan(1e-6);
});
it("rounds a closed path seam without breaking closure or changing untouched indices", () => {
  const source = drawing(),
    path = source.contours[0];
  if (path.type !== "path") throw Error();
  path.start = [0, 0];
  path.segments.push(path.segments.shift()!);
  source.constraints = [];
  const result = filletSketchCurves(
      source,
      { contour: 0, segment: 0 },
      { contour: 0, segment: 3 },
      1,
    ),
    p = result.contours[0];
  if (p.type !== "path") throw Error();
  expect(contourClosed(p)).toBe(true);
  expect(p.segments.map((s) => s.type)).toEqual([
    "bezier",
    "line",
    "line",
    "line",
    "arc",
  ]);
  expect(p.segments.slice(1, 3)).toEqual(path.segments.slice(1, 3));
  for (const c of result.constraints!)
    for (const r of constraintResiduals(result, c))
      expect(Math.abs(r)).toBeLessThan(1e-6);
});
it("rejects a referenced removed corner and nonadjacent selection without changing the source", () => {
  const source = drawing();
  source.constraints!.push({
    id: "sharp",
    kind: "fix",
    a: { contour: 0, kind: "point", index: 1 },
    point: [0, 0],
  });
  const before = structuredClone(source);
  expect(() =>
    filletSketchCurves(
      source,
      { contour: 0, segment: 0 },
      { contour: 0, segment: 1 },
      1,
    ),
  ).toThrow("virtual-sharp");
  expect(() =>
    filletSketchCurves(
      source,
      { contour: 0, segment: 1 },
      { contour: 0, segment: 3 },
      1,
    ),
  ).toThrow("adjacent");
  expect(source).toEqual(before);
});
it("disambiguates the two corners of a two-segment closed loop from retained-side picks", () => {
  const source: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [-5, 0],
        segments: [
          { type: "line", end: [5, 0] },
          { type: "arc", middle: [0, 5], end: [-5, 0] },
        ],
      },
    ],
  };
  const regular = filletSketchCurves(
    source,
    { contour: 0, segment: 0, parameter: 0 },
    { contour: 0, segment: 1, parameter: 1 },
    0.5,
  );
  const seam = filletSketchCurves(
    source,
    { contour: 0, segment: 0, parameter: 1 },
    { contour: 0, segment: 1, parameter: 0 },
    0.5,
  );
  for (const result of [regular, seam]) {
    expect(contourClosed(result.contours[0])).toBe(true);
    for (const c of result.constraints!)
      for (const r of constraintResiduals(result, c))
        expect(Math.abs(r)).toBeLessThan(1e-6);
  }
  expect(regular.contours[0]).not.toEqual(seam.contours[0]);
});
it("batches curved and straight corners and edits their shared radius after reopening", async () => {
  const { filletSketchCorners } = await import("./fillet-batch");
  const { findFilletRadiusDimension, editFilletRadius } =
    await import("./fillet-radius-edit");
  const source = drawing();
  source.constraints = [];
  const result = filletSketchCorners(
    source,
    [
      { contour: 0, vertex: 1 },
      { contour: 0, vertex: 2 },
      { contour: 0, vertex: 0 },
    ],
    0.5,
  );
  expect(result.constraints!.filter((c) => c.kind === "radius")).toHaveLength(
    1,
  );
  expect(result.constraints!.filter((c) => c.kind === "equal")).toHaveLength(2);
  const reopened = JSON.parse(JSON.stringify(result)),
    master = reopened.constraints.find(
      (c: { kind: string }) => c.kind === "radius",
    );
  const follower = reopened.constraints.find(
    (c: { kind: string }) => c.kind === "equal",
  );
  expect(findFilletRadiusDimension(reopened, follower.a)).toBe(master.id);
  const edited = editFilletRadius(reopened, master.id, 0.6);
  for (const c of edited.constraints!)
    for (const r of constraintResiduals(edited, c))
      expect(Math.abs(r)).toBeLessThan(1e-6);
  expect(contourClosed(edited.contours[0])).toBe(true);
});
