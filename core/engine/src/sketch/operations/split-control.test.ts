import { expect, it } from "vitest";
import { addSketchSplineHandle } from "./spline-handle";
import { insertSketchSplinePoint } from "./insert-spline-point";
import { editDrawingDimension } from "./edit-dimension";
import { segmentPoint } from "../curves/parameterization";
import { resolve } from "../solver/entities";
import { constraintResiduals } from "../solver/residuals";
import { fitSketchSpline } from "../curves/fit-spline";
import { constrainFitSpline } from "./spline-relations";
import type { SketchDrawing } from "../drawing";
it("retains both dimensioned handles during cubic and fit-spline insertion", () => {
  for (const fit of [false, true]) {
    let d: SketchDrawing = fit
      ? constrainFitSpline(
          {
            type: "drawing",
            contours: [
              fitSketchSpline([
                [0, 0],
                [10, 8],
                [20, 0],
              ]),
            ],
          },
          0,
        )
      : {
          type: "drawing",
          contours: [
            {
              type: "path",
              start: [0, 0],
              segments: [
                {
                  type: "bezier",
                  controls: [
                    [0, 5],
                    [10, 5],
                  ],
                  end: [10, 0],
                },
              ],
            },
          ],
        };
    const ref = { kind: "curve" as const, contour: 0, index: 0 };
    const start = addSketchSplineHandle(d, ref, "start");
    d = start.drawing;
    const end = addSketchSplineHandle(d, ref, "end");
    d = end.drawing;
    const before = structuredClone(d),
      path = d.contours[0];
    if (path.type !== "path") throw Error("path");
    const handle = resolve(d, start.handle).line!;
    const length = Math.hypot(
      handle[1][0] - handle[0][0],
      handle[1][1] - handle[0][1],
    );
    d.constraints!.push({
      id: "handle-size",
      kind: "length",
      a: start.handle,
      value: length,
    });
    const inserted = insertSketchSplinePoint(
      d,
      segmentPoint(path.start, path.segments[0], 0.3),
      0.01,
    );
    expect(inserted.contours.slice(1)).toEqual(before.contours.slice(1));
    const controls = inserted
      .constraints!.flatMap((c) => [c.a, c.b])
      .filter((r) => r?.control !== undefined);
    expect(controls.map((r) => r!.controlScale)).toEqual([
      expect.closeTo(1 / 0.3),
      expect.closeTo(1 / 0.7),
    ]);
    const splitPath = inserted.contours[0];
    if (splitPath.type !== "path") throw Error("path");
    const repeated = insertSketchSplinePoint(
      inserted,
      segmentPoint(splitPath.start, splitPath.segments[0], 0.5),
      0.01,
    );
    expect(repeated.contours.slice(1)).toEqual(before.contours.slice(1));
    expect(
      repeated.constraints!.some(
        (c) => Math.abs((c.b?.controlScale ?? 0) - 2 / 0.3) < 1e-5,
      ),
    ).toBe(true);
    const reopened = JSON.parse(JSON.stringify(repeated));
    const updated = editDrawingDimension(reopened, "handle-size", length * 1.1);
    for (const c of updated.constraints!)
      expect(
        constraintResiduals(updated, c).every((v) => Math.abs(v) < 1e-6),
      ).toBe(true);
    expect(d.contours).toEqual(before.contours);
  }
});
it("rejects corrupt control scales", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [0, 0],
        segments: [
          {
            type: "bezier",
            controls: [
              [0, 5],
              [10, 5],
            ],
            end: [10, 0],
          },
        ],
      },
    ],
  };
  for (const controlScale of [0, -1, Infinity, NaN])
    expect(() =>
      resolve(d, {
        kind: "point",
        contour: 0,
        index: 0,
        control: 0,
        controlScale,
      }),
    ).toThrow("scale");
});
