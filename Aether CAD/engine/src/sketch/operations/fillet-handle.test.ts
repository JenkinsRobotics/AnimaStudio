import { it, expect } from "vitest";
import { filletSketchCorner } from "./fillet";
import { filletRadiusHandle, filletRadiusFromHandle } from "./fillet-handle";
it("projects radius from the original sharp corner along the handle direction", () => {
  const d = filletSketchCorner(
    {
      type: "drawing",
      contours: [
        {
          type: "path",
          start: [-10, 0],
          segments: [
            { type: "line", end: [0, 0] },
            { type: "line", end: [0, 10] },
          ],
        },
      ],
    },
    0,
    1,
    2,
  );
  const id = d.constraints!.find((c) => c.kind === "radius")!.id,
    handle = filletRadiusHandle(d, id)!;
  expect(handle.origin).toEqual([0, 0]);
  expect(
    filletRadiusFromHandle(handle, [
      handle.position[0] * 2,
      handle.position[1] * 2,
    ]),
  ).toBeCloseTo(4);
  expect(() => filletRadiusFromHandle(handle, [0, 0])).toThrow("positive");
});
