import { expect, it } from "vitest";
import { sketchVariantContour } from "../primitives";
import {
  setSketchEllipseDiameter,
  sketchEllipseDiameters,
} from "./set-ellipse-diameter";
import { constrainSketchEllipse } from "./ellipse-relations";
import type { SketchDrawing } from "../drawing";
it.each([false, true])(
  "sets reusable primary and secondary drivers for partial=%s",
  (partial) => {
    let source: SketchDrawing = {
      type: "drawing",
      contours: [
        partial
          ? sketchVariantContour(
              "elliptical-arc",
              [
                [0, 0],
                [5, 0],
                [0, 3],
                [5, 0],
              ],
              6,
              { clockwise: true },
            )
          : sketchVariantContour("ellipse", [
              [0, 0],
              [5, 0],
              [0, 3],
            ]),
      ],
    };
    if (!partial) source = constrainSketchEllipse(source, 0);
    const ref = { contour: 0, kind: "ellipse" as const, index: 0 },
      before = structuredClone(source);
    const width = setSketchEllipseDiameter(source, ref, "x", 14);
    const both = setSketchEllipseDiameter(width, ref, "y", 8);
    const edited = setSketchEllipseDiameter(
      JSON.parse(JSON.stringify(both)),
      ref,
      "x",
      16,
    );
    expect(sketchEllipseDiameters(edited, ref)[0]).toBeCloseTo(16, 4);
    expect(sketchEllipseDiameters(edited, ref)[1]).toBeCloseTo(8, 4);
    expect(edited.constraints!.filter((c) => c.kind === "length")).toHaveLength(
      2,
    );
    expect(edited.contours).toHaveLength(both.contours.length);
    expect(source).toEqual(before);
    expect(() => setSketchEllipseDiameter(source, ref, "x", -1)).toThrow(
      /positive/,
    );
    expect(source).toEqual(before);
  },
);
