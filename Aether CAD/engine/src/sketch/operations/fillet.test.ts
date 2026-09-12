import { it, expect } from "vitest";
import { filletSketchCorner } from "./fillet";
import { sketchArcGeometry } from "../arc-geometry";
import { solveDrawingConstraints } from "../drawing-constraints";
import { contourClosed, type SketchDrawing } from "../drawing";
const corner = (): SketchDrawing => ({
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
});
it("creates an exact tangent corner and preserves editable radius/virtual sharp", () => {
  const source = corner(),
    next = filletSketchCorner(source, 0, 1, 2),
    c = next.contours[0];
  if (c.type !== "path" || c.segments[1].type !== "arc") throw Error("arc");
  expect(c.segments[0].end[0]).toBeCloseTo(-2);
  expect(c.segments[1].end[1]).toBeCloseTo(2);
  expect(
    sketchArcGeometry(
      c.segments[0].end,
      c.segments[1].middle,
      c.segments[1].end,
    ).radius,
  ).toBeCloseTo(2);
  next.constraints!.find((c) => c.kind === "radius")!.value = 3;
  const solved = solveDrawingConstraints(next),
    p = solved.contours[0];
  if (p.type !== "path" || p.segments[1].type !== "arc") throw Error("arc");
  expect(
    sketchArcGeometry(
      p.segments[0].end,
      p.segments[1].middle,
      p.segments[1].end,
    ).radius,
  ).toBeCloseTo(3, 5);
  expect(source.contours).toHaveLength(1);
});
it("fillets the closing seam without opening a closed profile", () => {
  const source: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [0, 0],
        segments: [
          { type: "line", end: [10, 0] },
          { type: "line", end: [10, 10] },
          { type: "line", end: [0, 10] },
          { type: "line", end: [0, 0] },
        ],
      },
    ],
  };
  const next = filletSketchCorner(source, 0, 0, 2);
  expect(contourClosed(next.contours[0])).toBe(true);
  expect(() => filletSketchCorner(source, 0, 0, 20)).toThrow("too large");
});
it("keeps original corner references and line dimensions attached to the virtual sharp", () => {
  const source = corner();
  source.constraints = [
    {
      id: "corner",
      kind: "fix",
      a: { contour: 0, kind: "point", index: 1 },
      point: [0, 0],
    },
    {
      id: "length",
      kind: "length",
      a: { contour: 0, kind: "line", index: 0 },
      value: 10,
    },
    {
      id: "horizontal",
      kind: "horizontal",
      a: { contour: 0, kind: "line", index: 0 },
    },
  ];
  const next = filletSketchCorner(source, 0, 1, 2);
  expect(next.constraints![0].a).toEqual({
    contour: 1,
    kind: "point",
    index: 0,
  });
  expect(next.constraints![1]).toMatchObject({
    id: "length",
    kind: "distance",
    value: 10,
    b: { contour: 1, kind: "point", index: 0 },
  });
});
