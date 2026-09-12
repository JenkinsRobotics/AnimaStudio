import { describe, expect, it } from "vitest";
import { sketchContourPolyline, sketchDrawingPolylines, sketchProfilePolylines } from "./sample";

describe("sketch sampling", () => {
  it("samples paths with lines and arcs ending exactly on segment endpoints", () => {
    const polyline = sketchContourPolyline({
      type: "path",
      start: [0, 0],
      segments: [
        { type: "line", end: [10, 0] },
        { type: "arc", middle: [15, 5], end: [20, 0] },
      ],
    });
    expect(polyline[0]).toEqual([0, 0]);
    expect(polyline[1]).toEqual([10, 0]);
    expect(polyline.at(-1)).toEqual([20, 0]);
    expect(polyline.length).toBeGreaterThan(10);
  });

  it("closes circles and skips construction contours by default", () => {
    const loops = sketchDrawingPolylines({
      type: "drawing",
      contours: [
        { type: "circle", center: [0, 0], radius: 5 },
        { type: "path", start: [0, 0], segments: [{ type: "line", end: [1, 1] }], construction: true },
      ],
    });
    expect(loops).toHaveLength(1);
    expect(loops[0][0][0]).toBeCloseTo(5);
    expect(loops[0].at(-1)![0]).toBeCloseTo(5);
  });

  it("converts polygon and circle profiles", () => {
    expect(sketchProfilePolylines({ type: "polygon", pointsMillimeters: [[0, 0], [10, 0], [10, 5]] })[0]).toHaveLength(4);
    expect(sketchProfilePolylines({ type: "circle", centerMillimeters: [1, 2], radiusMillimeters: 3 })[0].length).toBeGreaterThan(40);
    expect(sketchProfilePolylines({ type: "projection" })).toEqual([]);
  });
});
