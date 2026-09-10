import { expect, it } from "vitest";
import { addSketchEllipseCenter } from "./ellipse-center";
import { constrainSketchEllipse } from "./ellipse-relations";
import { centerSnapPoints, inferCenterSnaps } from "./center-snaps";
import { sketchVariantContour } from "../primitives";
import { dragSketchEntity } from "./drag-entity";
import { resolve } from "../solver/entities";
import { validateSketchDrawing } from "../drawing";
const ref = { kind: "ellipse" as const, contour: 0, index: 0 };
const fixture = () =>
  constrainSketchEllipse(
    {
      type: "drawing",
      contours: [
        sketchVariantContour("ellipse", [
          [10, 10],
          [15, 10],
          [10, 12],
        ]),
      ],
    },
    0,
  );
it("exposes a persistent ellipse center that drags the full ellipse after native roundtrip", () => {
  const source = fixture(),
    d = addSketchEllipseCenter(source, ref);
  expect(source.contours).toHaveLength(1);
  expect(addSketchEllipseCenter(d, ref)).toEqual(d);
  const next = dragSketchEntity(
    JSON.parse(JSON.stringify(d)),
    { kind: "point", contour: 1, index: 0 },
    [2, 3],
  );
  const ellipse = resolve(next, ref).ellipse!;
  expect(ellipse.center[0]).toBeCloseTo(12);
  expect(ellipse.center[1]).toBeCloseTo(13);
  validateSketchDrawing(next);
  expect(() =>
    addSketchEllipseCenter(source, { kind: "line", contour: 0, index: 0 }),
  ).toThrow(/elliptical/);
});
it("infers ellipse center attachment for new geometry and retains it through dragging", () => {
  const before = fixture(),
    after = structuredClone(before);
  expect(centerSnapPoints(before)[0]).toMatchObject({ point: [10, 10], ref });
  after.contours.push({
    type: "path",
    start: [10, 10],
    segments: [{ type: "line", end: [20, 20] }],
  });
  const next = inferCenterSnaps(before, after);
  expect(next.constraints!.filter((c) => c.kind === "concentric")).toHaveLength(
    1,
  );
  const moved = dragSketchEntity(
    next,
    { kind: "point", contour: 1, index: 0 },
    [-2, 1],
  );
  const center = resolve(moved, ref).ellipse!.center;
  expect(center[0]).toBeCloseTo(8);
  expect(center[1]).toBeCloseTo(11);
  validateSketchDrawing(moved);
});
