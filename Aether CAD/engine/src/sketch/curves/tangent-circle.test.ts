import { it, expect } from "vitest";
import { tangentCircles } from "./tangent-circle";
import { curveJet } from "./derivatives";
import { circleSegments } from "./picking";
import type { Curve } from "./pairs";
function verify(a: Curve, b: Curve, radius: number) {
  const solutions = tangentCircles(a, b, radius);
  expect(solutions.length).toBeGreaterThan(0);
  for (const solution of solutions)
    for (const [curve, t] of [
      [a, solution.firstParameter],
      [b, solution.secondParameter],
    ] as const) {
      const jet = curveJet(curve)(t),
        dx = jet.point[0] - solution.center[0],
        dy = jet.point[1] - solution.center[1];
      expect(Math.hypot(dx, dy)).toBeCloseTo(radius, 5);
      expect(
        (dx * jet.first[0] + dy * jet.first[1]) / Math.hypot(...jet.first),
      ).toBeCloseTo(0, 5);
    }
}
it("finds exact tangent circles for line/arc and line/cubic pairs", () => {
  const line: Curve = {
    start: [0, 0],
    segment: { type: "line", end: [20, 0] },
  };
  verify(line, circleSegments([10, 5], 5)[1], 2);
  verify(
    { start: [-10, 0], segment: { type: "line", end: [0, 0] } },
    {
      start: [0, 0],
      segment: {
        type: "bezier",
        controls: [
          [1, 3],
          [2, 7],
        ],
        end: [0, 10],
      },
    },
    1,
  );
});
it("finds arc/arc tangent circles and rejects invalid radii", () => {
  verify(circleSegments([0, 0], 5)[0], circleSegments([8, 0], 5)[0], 1);
  expect(() =>
    tangentCircles(
      circleSegments([0, 0], 5)[0],
      circleSegments([8, 0], 5)[0],
      -1,
    ),
  ).toThrow("positive");
});
