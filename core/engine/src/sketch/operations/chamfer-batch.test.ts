import { it, expect } from "vitest";
import { chamferSketchCorners } from "./chamfer-batch";
import {
  editDrawingDimension,
  removeDrawingConstraint,
} from "./edit-dimension";
import { dimensionValue } from "../solver/dimension-links";
import { constraintResiduals } from "../drawing-constraints";
import type { SketchDrawing } from "../drawing";
const drawing = (): SketchDrawing => ({
  type: "drawing",
  contours: [
    {
      type: "path",
      start: [0, 0],
      segments: [
        { type: "line", end: [10, 0] },
        { type: "line", end: [10, 10] },
      ],
    },
    {
      type: "path",
      start: [30, 0],
      segments: [
        { type: "line", end: [40, 0] },
        { type: "line", end: [40, -10] },
      ],
    },
  ],
});
const corners = [
  { contour: 0, vertex: 1 },
  { contour: 1, vertex: 1 },
];
it("persists one setback driver for equal-distance chamfers across corners", () => {
  const result = chamferSketchCorners(drawing(), corners, {
    mode: "equal-distance",
    distance: 1,
  });
  const distances = result.constraints!.filter((c) => c.kind === "distance");
  expect(distances.filter((c) => c.value !== undefined)).toHaveLength(1);
  const edited = editDrawingDimension(
    JSON.parse(JSON.stringify(result)),
    distances[0].id,
    2,
  );
  for (const c of edited.constraints!.filter((c) => c.kind === "distance"))
    expect(dimensionValue(edited, c)).toBe(2);
  for (const c of edited.constraints!)
    for (const r of constraintResiduals(edited, c))
      expect(Math.abs(r)).toBeLessThan(1e-6);
});
it("links opposite-turn angle dimensions with orientation and edits through the follower", () => {
  const result = chamferSketchCorners(drawing(), corners, {
    mode: "distance-angle",
    distance: 1,
    angleDegrees: 30,
  });
  const angles = result.constraints!.filter((c) => c.kind === "angle");
  expect(angles.filter((c) => c.value !== undefined)).toHaveLength(1);
  const follower = angles.find((c) => c.valueFrom)!;
  expect(follower.valueSign).toBe(-1);
  const edited = editDrawingDimension(result, follower.id, 40);
  expect(
    dimensionValue(
      edited,
      edited.constraints!.find((c) => c.id === follower.id)!,
    ),
  ).toBe(40);
  expect(
    edited.constraints!.find((c) => c.id === follower.valueFrom)!.value,
  ).toBe(-40);
  for (const c of edited.constraints!)
    for (const r of constraintResiduals(edited, c))
      expect(Math.abs(r)).toBeLessThan(1e-6);
  const removed = removeDrawingConstraint(edited, follower.valueFrom!);
  const kept = removed.constraints!.find((c) => c.id === follower.id)!;
  expect(kept.value).toBe(40);
  expect(kept.valueSign).toBeUndefined();
});
it("uses two drivers for two-distance batches and rejects an oversized batch atomically", () => {
  const source = drawing(),
    before = structuredClone(source);
  const result = chamferSketchCorners(source, corners, {
    mode: "two-distances",
    distance: 1,
    secondDistance: 2,
  });
  expect(
    result.constraints!.filter(
      (c) => c.kind === "distance" && c.value !== undefined,
    ),
  ).toHaveLength(2);
  expect(() =>
    chamferSketchCorners(source, corners, {
      mode: "equal-distance",
      distance: 20,
    }),
  ).toThrow("large");
  expect(source).toEqual(before);
});
