import { expect, it } from "vitest";
import { slotSketchEntities } from "./slot";
import { slotWidthHandle, slotWidthFromHandle } from "./slot-handle";
it.each(["line", "arc"] as const)(
  "projects %s slot width as diameter on either side",
  (kind) => {
    const drawing = slotSketchEntities(
      {
        type: "drawing",
        contours: [
          {
            type: "path",
            start: [5, 0],
            segments: [
              kind === "line"
                ? { type: "line", end: [15, 0] }
                : {
                    type: "arc",
                    middle: [Math.sqrt(12.5), Math.sqrt(12.5)],
                    end: [0, 5],
                  },
            ],
          },
        ],
      },
      [{ contour: 0, kind, index: 0 }],
      2,
    );
    const h = slotWidthHandle(drawing, "slot-1")!;
    expect(slotWidthFromHandle(h, h.position)).toBeCloseTo(2, 6);
    const [x, y] = h.origin,
      [nx, ny] = h.normal;
    expect(
      slotWidthFromHandle(h, [x - 3 * nx + 20 * ny, y - 3 * ny - 20 * nx]),
    ).toBeCloseTo(6, 6);
    expect(slotWidthHandle(drawing, "missing")).toBeUndefined();
    expect(() => slotWidthFromHandle(h, [NaN, 0])).toThrow("finite");
  },
);
