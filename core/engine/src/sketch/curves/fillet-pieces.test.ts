import { it, expect } from "vitest";
import { filletCurvePieces } from "./fillet-pieces";
import { curveJet } from "./derivatives";
import { sketchArcGeometry } from "../arc-geometry";
import type { Curve } from "./pairs";
it("joins exact line and cubic portions with matching tangent directions", () => {
  const a: Curve = { start: [-10, 0], segment: { type: "line", end: [0, 0] } },
    b: Curve = {
      start: [0, 0],
      segment: {
        type: "bezier",
        controls: [
          [1, 3],
          [2, 7],
        ],
        end: [0, 10],
      },
    };
  const result = filletCurvePieces(a, b, 1, 0.5, 0.7);
  expect(result.segments.map((s) => s.type)).toEqual(["line", "arc", "bezier"]);
  const [first, arc, last] = result.segments;
  if (arc.type !== "arc") throw Error();
  expect(sketchArcGeometry(first.end, arc.middle, arc.end).radius).toBeCloseTo(
    1,
    5,
  );
  const curves = [
    { start: result.start, segment: first },
    { start: first.end, segment: arc },
    { start: arc.end, segment: last },
  ];
  for (let i = 0; i < 2; i++) {
    const p = curveJet(curves[i])(1).first,
      q = curveJet(curves[i + 1])(0).first;
    expect(
      (p[0] * q[0] + p[1] * q[1]) / (Math.hypot(...p) * Math.hypot(...q)),
    ).toBeCloseTo(1, 5);
  }
});
