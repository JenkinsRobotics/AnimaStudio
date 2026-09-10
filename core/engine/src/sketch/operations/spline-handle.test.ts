import { expect, it } from "vitest";
import { addSketchSplineHandle } from "./spline-handle";
import { editDrawingDimension } from "./edit-dimension";
import { constraintResiduals } from "../solver/residuals";
import { resolve } from "../solver/entities";
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
            [0, 5],
            [10, 5],
          ],
          end: [10, 0],
        },
      ],
    },
  ],
});
const ref = { kind: "curve" as const, contour: 0, index: 0 };
it("exposes both cubic handles once and dimensions canonical controls after reopening", () => {
  for (const end of ["start", "end"] as const) {
    const source = fixture(),
      { drawing, handle } = addSketchSplineHandle(source, ref, end);
    expect(source.contours).toHaveLength(1);
    expect(drawing.contours[1].construction).toBe(true);
    expect(addSketchSplineHandle(drawing, ref, end)).toEqual({
      drawing,
      handle,
    });
    drawing.constraints!.push({
      id: "length",
      kind: "length",
      a: handle,
      value: 5,
    });
    const edited = editDrawingDimension(
      JSON.parse(JSON.stringify(drawing)),
      "length",
      8,
    );
    const line = resolve(edited, handle).line!;
    expect(
      Math.hypot(line[1][0] - line[0][0], line[1][1] - line[0][1]),
    ).toBeCloseTo(8, 5);
    const c = edited.contours[0];
    if (c.type !== "path" || c.segments[0].type !== "bezier")
      throw Error("curve");
    const endpoint = end === "start" ? c.start : c.segments[0].end,
      control = c.segments[0].controls[end === "start" ? 0 : 1];
    expect(
      Math.hypot(control[0] - endpoint[0], control[1] - endpoint[1]),
    ).toBeCloseTo(8, 5);
    for (const constraint of edited.constraints!)
      expect(
        constraintResiduals(edited, constraint).every(
          (v) => Math.abs(v) < 1e-6,
        ),
      ).toBe(true);
  }
});
it("rejects invalid references and stationary tangent controls", () => {
  expect(() =>
    addSketchSplineHandle(fixture(), { ...ref, kind: "line" }, "start"),
  ).toThrow("cubic");
  const d = fixture(),
    c = d.contours[0];
  if (c.type !== "path" || c.segments[0].type !== "bezier") throw Error();
  c.segments[0].controls[0] = [0, 0];
  expect(() => addSketchSplineHandle(d, ref, "start")).toThrow("direction");
  expect(d.contours).toHaveLength(1);
});

it("keeps fit-spline interpolation while adjusting a tangent handle", async () => {
  const { fitSketchSpline } = await import("../curves/fit-spline");
  const { constrainFitSpline } = await import("./spline-relations");
  const fit = constrainFitSpline(
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
  );
  const { drawing, handle } = addSketchSplineHandle(fit, ref, "start");
  const line = resolve(drawing, handle).line!;
  const length = Math.hypot(line[1][0] - line[0][0], line[1][1] - line[0][1]);
  drawing.constraints!.push({
    id: "handle-length",
    kind: "length",
    a: handle,
    value: length,
  });
  const changed = editDrawingDimension(drawing, "handle-length", length * 1.1);
  for (const c of changed.constraints!)
    expect(
      constraintResiduals(changed, c).every((v) => Math.abs(v) < 1e-6),
    ).toBe(true);
});
