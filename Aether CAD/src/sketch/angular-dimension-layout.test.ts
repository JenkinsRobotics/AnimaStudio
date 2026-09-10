import { expect, it } from "vitest";
import { angularDimensionLayout } from "./angular-dimension-layout";
it("positions the signed angle arc at the supporting line intersection", () => {
  const layout = angularDimensionLayout(
    [
      [2, 3],
      [7, 3],
    ],
    [
      [4, 1],
      [4, 9],
    ],
    2,
  );
  expect(layout.center).toEqual([4, 3]);
  expect(layout.start).toEqual([6, 3]);
  expect(layout.end[0]).toBeCloseTo(4);
  expect(layout.end[1]).toBeCloseTo(5);
  expect(layout.path).toContain("0 0 0");
  const clockwise = angularDimensionLayout(
    [
      [2, 3],
      [7, 3],
    ],
    [
      [4, 9],
      [4, 1],
    ],
    2,
  );
  expect(clockwise.path).toContain("0 0 1");
});
it("keeps parallel layouts finite and rejects degenerate references", () => {
  const parallel = angularDimensionLayout(
    [
      [0, 0],
      [5, 0],
    ],
    [
      [2, 3],
      [7, 3],
    ],
    2,
  );
  expect([...parallel.center, ...parallel.label].every(Number.isFinite)).toBe(
    true,
  );
  expect(() =>
    angularDimensionLayout(
      [
        [0, 0],
        [0, 0],
      ],
      [
        [0, 0],
        [1, 0],
      ],
      2,
    ),
  ).toThrow();
});
