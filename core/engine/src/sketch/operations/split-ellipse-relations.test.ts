import { expect, it } from "vitest";
import { splitSketchSegment } from "./split";
import { constrainSketchEllipse } from "./ellipse-relations";
import { sketchVariantContour } from "../primitives";
import { constraintResiduals } from "../solver/residuals";
it("splits a full ellipse and moves its quadrant reference onto a visible child", () => {
  const d = constrainSketchEllipse(
    {
      type: "drawing",
      contours: [
        sketchVariantContour("ellipse", [
          [0, 0],
          [5, 0],
          [0, 3],
        ]),
      ],
    },
    0,
  );
  d.contours.push({ type: "circle", center: [0, -3], radius: 1 });
  d.constraints!.push({
    id: "bottom",
    kind: "quadrant",
    a: { kind: "point", contour: 1, index: 0 },
    b: { kind: "ellipse", contour: 0, index: 0 },
    quadrant: 3,
  });
  const next = splitSketchSegment(d, [0, 3], 0.1),
    path = next.contours[0];
  if (path.type !== "path") throw Error();
  expect(path.segments).toHaveLength(3);
  expect(
    next.constraints!.filter((c) => c.kind === "ellipse-locus"),
  ).toHaveLength(2);
  expect(next.constraints!.some((c) => c.kind === "ellipse-shape")).toBe(false);
  for (const c of next.constraints!)
    expect(
      Math.max(...constraintResiduals(next, c).map(Math.abs)),
    ).toBeLessThan(1e-6);
  const again = splitSketchSegment(next, [0, -3], 0.1);
  expect(again.contours[0].type).toBe("path");
  expect(
    again.constraints!.filter((c) => c.kind === "ellipse-locus"),
  ).toHaveLength(3);
  for (const c of again.constraints!)
    expect(
      Math.max(...constraintResiduals(again, c).map(Math.abs)),
    ).toBeLessThan(1e-6);
});
