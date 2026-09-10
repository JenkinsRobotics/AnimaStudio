import { expect, it } from "vitest";
import { collinearLineContact } from "./line-overlap";

it("detects finite overlap, containment, reversal and endpoint contact", () => {
  for (const [c, d] of [
    [
      [5, 0],
      [15, 0],
    ],
    [
      [8, 0],
      [2, 0],
    ],
    [
      [-5, 0],
      [15, 0],
    ],
    [
      [10, 0],
      [12, 0],
    ],
  ] as [[number, number], [number, number]][])
    expect(collinearLineContact([0, 0], [10, 0], c, d)).toBe(true);
});

it("rejects separated, parallel and crossing noncollinear segments", () => {
  expect(collinearLineContact([0, 0], [10, 0], [11, 0], [15, 0])).toBe(false);
  expect(collinearLineContact([0, 0], [10, 0], [0, 1], [10, 1])).toBe(false);
  expect(collinearLineContact([0, 0], [10, 0], [5, -1], [5, 1])).toBe(false);
});

it("uses distance tolerance for long, short and rotated segments", () => {
  expect(collinearLineContact([0, 0], [1e6, 0], [1, 1e-9], [2, 1e-9])).toBe(
    true,
  );
  expect(collinearLineContact([0, 0], [1e-4, 0], [0, 1e-6], [1e-4, 1e-6])).toBe(
    false,
  );
  expect(collinearLineContact([2, 3], [12, 13], [7, 8], [22, 23])).toBe(true);
});
