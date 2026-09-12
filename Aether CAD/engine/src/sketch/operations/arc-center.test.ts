import { expect, it } from "vitest";
import { sketchVariantContour } from "../primitives";
import { addSketchArcCenter } from "./arc-center";
import { dragSketchEntity } from "./drag-entity";
import { editDrawingDimension } from "./edit-dimension";
import { sketchConstraintState } from "../solver/diagnostics";
import { sketchArcGeometry } from "../arc-geometry";
import type { SketchDrawing } from "../drawing";

function drawing() {
  return addSketchArcCenter(
    {
      type: "drawing",
      contours: [
        sketchVariantContour("center-arc", [
          [0, 0],
          [5, 0],
          [0, 5],
        ]),
      ],
    },
    { contour: 0, kind: "arc", index: 0 },
  );
}
function geometry(d: SketchDrawing) {
  const path = d.contours[0];
  if (path.type !== "path") throw Error();
  const s = path.segments[0];
  if (s.type !== "arc") throw Error();
  return sketchArcGeometry(path.start, s.middle, s.end);
}
it("retains a selectable center without changing arc freedom", () => {
  const d = drawing();
  expect(d.contours[1]).toMatchObject({
    type: "path",
    construction: true,
    segments: [],
  });
  expect(sketchConstraintState(d)).toMatchObject({
    state: "under-constrained",
    degreesOfFreedom: 5,
  });
  const moved = dragSketchEntity(
    d,
    { contour: 1, kind: "point", index: 0 },
    [2, 1],
  );
  expect(geometry(moved).center[0]).toBeCloseTo(2);
  expect(geometry(moved).center[1]).toBeCloseTo(1);
});
it("keeps a fixed center while an endpoint changes the radius", () => {
  const d = drawing();
  d.constraints!.push({
    id: "fixed",
    kind: "fix",
    a: { contour: 1, kind: "point", index: 0 },
    point: [0, 0],
  });
  const moved = dragSketchEntity(
    d,
    { contour: 0, kind: "point", index: 0 },
    [1, 0],
  );
  const arc = geometry(moved);
  expect(arc.center[0]).toBeCloseTo(0);
  expect(arc.center[1]).toBeCloseTo(0);
  expect(arc.radius).toBeCloseTo(6);
  expect(sketchConstraintState(moved).degreesOfFreedom).toBe(3);
});
it("edits an arc radius while preserving its fixed center", () => {
  const d = drawing();
  d.constraints!.push(
    {
      id: "fixed",
      kind: "fix",
      a: { contour: 1, kind: "point", index: 0 },
      point: [0, 0],
    },
    {
      id: "radius",
      kind: "radius",
      a: { contour: 0, kind: "arc", index: 0 },
      value: 5,
    },
  );
  const moved = editDrawingDimension(d, "radius", 7),
    arc = geometry(moved);
  expect(arc.center[0]).toBeCloseTo(0);
  expect(arc.center[1]).toBeCloseTo(0);
  expect(arc.radius).toBeCloseTo(7);
  expect(sketchConstraintState(moved).degreesOfFreedom).toBe(2);
});
it("rejects incompatible references atomically", () => {
  const d = drawing(),
    before = structuredClone(d);
  expect(() =>
    addSketchArcCenter(d, { contour: 1, kind: "arc", index: 0 }),
  ).toThrow();
  expect(() =>
    addSketchArcCenter(d, { contour: 0, kind: "line", index: 0 }),
  ).toThrow();
  expect(d).toEqual(before);
});
it("reuses an exposed center without adding redundant constraints", () => {
  const d = drawing();
  expect(addSketchArcCenter(d, { contour: 0, kind: "arc", index: 0 })).toEqual(
    d,
  );
});

it("follows stable arc identity after an earlier edge is inserted", () => {
  const source = drawing();
  const path = source.contours[0];
  if (path.type !== "path") throw Error();
  path.segments[0].id = "arc-edge";
  // Start without a center so the operation must create one from the new index.
  source.contours.pop();
  source.constraints = [];
  path.start = [-10, 0];
  path.segments.unshift({ type: "line", id: "prefix", end: [5, 0] });
  const before = structuredClone(source);
  const ref = {
    contour: 0,
    kind: "arc" as const,
    index: 0,
    segmentId: "arc-edge",
  };
  const next = addSketchArcCenter(source, ref);
  expect(next.contours[1]).toMatchObject({ start: [0, 0], construction: true });
  expect(next.constraints![0].a).toMatchObject({
    index: 1,
    segmentId: "arc-edge",
  });
  expect(addSketchArcCenter(next, ref)).toEqual(next);
  expect(source).toEqual(before);
  expect(() =>
    addSketchArcCenter(source, { ...ref, segmentId: "deleted" }),
  ).toThrow("Broken segment reference");
  expect(source).toEqual(before);
});

it("captures an existing arc ID so its center survives later index changes", () => {
  const source = drawing();
  source.contours.pop();
  source.constraints = [];
  const path = source.contours[0];
  if (path.type !== "path") throw Error();
  path.segments[0].id = "arc-edge";
  const next = addSketchArcCenter(source, {
    contour: 0,
    kind: "arc",
    index: 0,
  });
  const changedPath = next.contours[0];
  if (changedPath.type !== "path") throw Error();
  changedPath.start = [-10, 0];
  changedPath.segments.unshift({ type: "line", end: [5, 0] });
  expect(
    addSketchArcCenter(next, { contour: 0, kind: "arc", index: 1 }),
  ).toEqual(next);
  next.constraints!.push(
    {
      id: "fixed",
      kind: "fix",
      a: { contour: 1, kind: "point", index: 0 },
      point: [0, 0],
    },
    {
      id: "radius",
      kind: "radius",
      a: { contour: 0, kind: "arc", index: 0, segmentId: "arc-edge" },
      value: 5,
    },
  );
  const edited = editDrawingDimension(
    JSON.parse(JSON.stringify(next)),
    "radius",
    7,
  );
  const editedPath = edited.contours[0];
  if (editedPath.type !== "path") throw Error();
  const arc = editedPath.segments[1];
  if (arc.type !== "arc") throw Error();
  const result = sketchArcGeometry(
    editedPath.segments[0].end,
    arc.middle,
    arc.end,
  );
  expect(result.radius).toBeCloseTo(7);
  expect(result.center[0]).toBeCloseTo(0);
  expect(result.center[1]).toBeCloseTo(0);
});
