import { expect, it } from "vitest";
import { splitSketchSegment } from "./split";
import { editDrawingDimension } from "./edit-dimension";
import { constraintResiduals } from "../solver/residuals";
import { sketchArcGeometry } from "../arc-geometry";
import { validateSketchDrawing, type SketchDrawing } from "../drawing";
it.each([1, -1])(
  "retains original arc midpoint after Split and radius editing (%s sweep side)",
  (side) => {
    const d: SketchDrawing = {
      type: "drawing",
      contours: [
        {
          type: "path",
          start: [-5, 0],
          segments: [
            { id: "arc", type: "arc", middle: [0, side * 5], end: [5, 0] },
          ],
        },
        { type: "path", start: [0, side * 5], segments: [] },
      ],
      constraints: [
        {
          id: "mid",
          kind: "midpoint",
          a: { kind: "arc", contour: 0, index: 0, segmentId: "arc" },
          b: { kind: "point", contour: 1, index: 0 },
        },
        {
          id: "radius",
          kind: "radius",
          a: { kind: "arc", contour: 0, index: 0, segmentId: "arc" },
          value: 5,
        },
      ],
    };
    const original = structuredClone(d);
    const split = splitSketchSegment(d, [-3, side * 4], 0.01);
    expect(d).toEqual(original);
    expect(split.contours).toHaveLength(3);
    const again = splitSketchSegment(split, [3, side * 4], 0.01);
    expect(again.contours).toHaveLength(3);
    for (const c of again.constraints!)
      expect(
        constraintResiduals(again, c).every((r) => Math.abs(r) < 1e-6),
      ).toBe(true);
    const reopened = JSON.parse(JSON.stringify(split));
    validateSketchDrawing(reopened);
    const edited = editDrawingDimension(reopened, "radius", 7);
    const helper = edited.contours[2],
      point = edited.contours[1];
    if (
      helper.type !== "path" ||
      helper.segments[0].type !== "arc" ||
      point.type !== "path"
    )
      throw Error();
    const geometry = sketchArcGeometry(
      helper.start,
      helper.segments[0].middle,
      helper.segments[0].end,
    );
    expect(geometry.radius).toBeCloseTo(7, 5);
    expect(geometry.midpoint[0]).toBeCloseTo(point.start[0], 5);
    expect(geometry.midpoint[1]).toBeCloseTo(point.start[1], 5);
    for (const c of edited.constraints!)
      expect(
        constraintResiduals(edited, c).every((r) => Math.abs(r) < 1e-6),
      ).toBe(true);
    expect(reopened).toEqual(split);
  },
);
