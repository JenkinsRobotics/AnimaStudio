import { expect, it } from "vitest";
import { pickSketchEntity } from "./picking";
import type { SketchDrawing } from "@aether/core/sketch";

it("prioritizes a coincident construction point over an earlier curve", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      { type: "circle", center: [0, 0], radius: 5 },
      { type: "path", construction: true, start: [0, 5], segments: [] },
    ],
  };
  expect(pickSketchEntity(d, [0, 5])?.ref).toMatchObject({
    contour: 1,
    kind: "point",
  });
  expect(pickSketchEntity(d, [5, 0])?.ref).toMatchObject({
    contour: 0,
    kind: "circle",
  });
});
