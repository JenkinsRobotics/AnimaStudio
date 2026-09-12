import { expect, it } from "vitest";
import { textPlacementTransform } from "./placement";
import { transformPoint } from "../curves/similarity";
it.each([
  [false, false, 8, 23],
  [true, false, 8, 17],
  [false, true, 12, 23],
  [true, true, 12, 17],
] as const)(
  "applies flips %s/%s in local text axes before rotation",
  (flipHorizontal, flipVertical, x, y) => {
    const point = transformPoint(
      [3, 2],
      textPlacementTransform({
        originMillimeters: [10, 20],
        rotationDegrees: 90,
        flipHorizontal,
        flipVertical,
      }),
    );
    expect(point[0]).toBeCloseTo(x);
    expect(point[1]).toBeCloseTo(y);
  },
);
it("keeps the baseline origin fixed and scales normalized previews", () => {
  const transform = textPlacementTransform(
    { originMillimeters: [5, 6], flipHorizontal: true },
    10,
  );
  expect(transformPoint([0, 0], transform)).toEqual([5, 6]);
  expect(transformPoint([1, 2], transform)).toEqual([-5, 26]);
});
it("rejects malformed orientation fields", () => {
  expect(() => textPlacementTransform({ flipHorizontal: 1 as any })).toThrow(
    /boolean/,
  );
  expect(() => textPlacementTransform({}, 0)).toThrow(/positive/);
});
