import { it, expect } from "vitest";
import { filletSketchCorners } from "./fillet-batch";
import {
  editFilletRadius,
  findFilletRadiusDimension,
} from "./fillet-radius-edit";
import { sketchArcGeometry } from "../arc-geometry";
it("finds and edits the driving dimension from either fillet in a saved batch", () => {
  const source = filletSketchCorners(
    {
      type: "drawing",
      contours: [
        {
          type: "path",
          start: [0, 0],
          segments: [
            { type: "line", end: [20, 0] },
            { type: "line", end: [20, 20] },
            { type: "line", end: [0, 20] },
            { type: "line", end: [0, 0] },
          ],
        },
      ],
    },
    [
      { contour: 0, vertex: 0 },
      { contour: 0, vertex: 2 },
    ],
    2,
  );
  const path = source.contours[0];
  if (path.type !== "path") throw Error();
  const arcs = path.segments.flatMap((s, index) =>
    s.type === "arc" ? [index] : [],
  );
  const ids = arcs.map((index) =>
    findFilletRadiusDimension(source, { contour: 0, kind: "arc", index }),
  );
  expect(ids[0]).toBeTruthy();
  expect(ids[0]).toBe(ids[1]);
  const next = editFilletRadius(source, ids[1]!, 3),
    c = next.contours[0];
  if (c.type !== "path") throw Error();
  let start = c.start;
  for (const segment of c.segments) {
    if (segment.type === "arc")
      expect(
        sketchArcGeometry(start, segment.middle, segment.end).radius,
      ).toBeCloseTo(3, 5);
    start = segment.end;
  }
  expect(source.constraints!.find((c) => c.id === ids[0])!.value).toBe(2);
  expect(() => editFilletRadius(source, ids[0]!, -1)).toThrow("positive");
});
