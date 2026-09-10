import type { SketchDrawing, SketchPoint } from "../drawing";
import type { SketchEntityRef } from "../solver/types";
import { sketchArcGeometry } from "../arc-geometry";
import { angularSpanDistance } from "../curves/angular-span";
/** Circle axis points and only the quadrants within an arc's directed span. */
export function circularQuadrantSnaps(drawing: SketchDrawing) {
  const result: {
    point: SketchPoint;
    ellipse: SketchEntityRef;
    quadrant: 0 | 1 | 2 | 3;
  }[] = [];
  const add = (
    center: SketchPoint,
    radius: number,
    ref: SketchEntityRef,
    start = 0,
    sweep = 2 * Math.PI,
  ) => {
    for (const q of [0, 1, 2, 3] as const) {
      const angle = (q * Math.PI) / 2;
      if (angularSpanDistance(start, sweep, angle) > 0) continue;
      result.push({
        point: [
          center[0] + radius * Math.cos(angle),
          center[1] + radius * Math.sin(angle),
        ],
        ellipse: ref,
        quadrant: q,
      });
    }
  };
  drawing.contours.forEach((c, contour) => {
    if (c.type === "circle") {
      add(c.center, c.radius, { contour, kind: "circle" });
      return;
    }
    c.segments.forEach((segment, index) => {
      if (segment.type !== "arc") return;
      try {
        const arc = sketchArcGeometry(
          index === 0 ? c.start : c.segments[index - 1].end,
          segment.middle,
          segment.end,
        );
        add(
          arc.center,
          arc.radius,
          { contour, kind: "arc", index },
          arc.startAngle,
          arc.sweep,
        );
      } catch {
        // Incomplete/degenerate draft arcs provide no quadrant candidates.
      }
    });
  });
  return result;
}
