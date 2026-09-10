import type { SketchDrawing, SketchPoint, SketchSegment } from "../drawing";
import { closestSegmentParameter } from "./parameterization";
import type { Curve } from "./pairs";
export interface PickedCurve {
  contour: number;
  segment: number;
  parameter: number;
  distance: number;
  circle: boolean;
  point: boolean;
}
export function circleSegments(center: SketchPoint, radius: number): Curve[] {
  const right: SketchPoint = [center[0] + radius, center[1]],
    left: SketchPoint = [center[0] - radius, center[1]];
  return [
    {
      start: right,
      segment: {
        type: "arc",
        middle: [center[0], center[1] + radius],
        end: left,
      },
    },
    {
      start: left,
      segment: {
        type: "arc",
        middle: [center[0], center[1] - radius],
        end: right,
      },
    },
  ];
}
export function drawingCurves(
  drawing: SketchDrawing,
): { contour: number; segment: number; curve: Curve }[] {
  return drawing.contours.flatMap((c, contour) => {
    if (c.type === "circle")
      return circleSegments(c.center, c.radius).map((curve, segment) => ({
        contour,
        segment,
        curve,
      }));
    let start = c.start;
    return c.segments.map((s: SketchSegment, segment) => {
      const curve = { start, segment: s };
      start = s.end;
      return { contour, segment, curve };
    });
  });
}
export function pickCurve(
  drawing: SketchDrawing,
  point: SketchPoint,
  tolerance: number,
): PickedCurve {
  let best: PickedCurve | undefined;
  drawing.contours.forEach((c, contour) => {
    if (c.type === "circle") {
      const distance = Math.abs(
          Math.hypot(point[0] - c.center[0], point[1] - c.center[1]) - c.radius,
        ),
        angle =
          (Math.atan2(point[1] - c.center[1], point[0] - c.center[0]) +
            2 * Math.PI) %
          (2 * Math.PI);
      if (distance < tolerance && (!best || distance < best.distance - 1e-8))
        best = {
          contour,
          segment: 0,
          parameter: angle / (2 * Math.PI),
          distance,
          circle: true,
          point: false,
        };
    } else if (!c.segments.length) {
      const distance = Math.hypot(point[0] - c.start[0], point[1] - c.start[1]);
      if (distance < tolerance && (!best || distance < best.distance - 1e-8))
        best = {
          contour,
          segment: 0,
          parameter: 0,
          distance,
          circle: false,
          point: true,
        };
    } else {
      let start = c.start;
      c.segments.forEach((segment, index) => {
        const { parameter, distance } = closestSegmentParameter(
          start,
          segment,
          point,
        );
        if (distance < tolerance && (!best || distance < best.distance - 1e-8))
          best = {
            contour,
            segment: index,
            parameter,
            distance,
            circle: false,
            point: false,
          };
        start = segment.end;
      });
    }
  });
  if (!best) throw new Error("Select a sketch curve or point.");
  return best;
}
