import { expect, it } from "vitest";
import { sketchVariantContour } from "./primitives";
import { sketchArcGeometry } from "./arc-geometry";
it.each([false, true])(
  "constructs exact center arcs with selected clockwise=%s",
  (clockwise) => {
    const contour = sketchVariantContour(
      "center-arc",
      [
        [0, 0],
        [5, 0],
        [0, 9],
      ],
      6,
      { clockwise },
    );
    if (contour.type !== "path" || contour.segments[0].type !== "arc")
      throw Error();
    const segment = contour.segments[0],
      g = sketchArcGeometry(contour.start, segment.middle, segment.end);
    expect(g.radius).toBeCloseTo(5);
    expect(g.sweep).toBeCloseTo(clockwise ? -Math.PI * 1.5 : Math.PI / 2);
    expect(segment.end[0]).toBeCloseTo(0);
    expect(segment.end[1]).toBeCloseTo(5);
    expect(() =>
      sketchVariantContour(
        "center-arc",
        [
          [0, 0],
          [5, 0],
          [10, 0],
        ],
        6,
        { clockwise },
      ),
    ).toThrow(/endpoints/);
  },
);
