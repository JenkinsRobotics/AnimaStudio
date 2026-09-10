import { trimPickedCurve } from "./trim";
import { remapExtendedContacts } from "./extension-contacts";
import { linkExtendedEndpoint } from "./extension-point-link";
import { sketchPointBoundaries, pointOnLineParameter } from "../curves/point-boundaries";
import { assertConstraintsSatisfied } from "./preserve-constraints";
import { lineSegmentIntersections } from "../curves/intersections";
import {
  contourClosed,
  validateSketchDrawing,
  type SketchDrawing,
  type SketchPoint,
} from "../drawing";
const epsilon = 1e-8;
const subtract = (a: SketchPoint, b: SketchPoint): SketchPoint => [
  a[0] - b[0],
  a[1] - b[1],
];
interface LineTarget {
  contour: number;
  segment: number;
  start: SketchPoint;
  end: SketchPoint;
  parameter: number;
}
export function nearestSketchLine(
  drawing: SketchDrawing,
  point: SketchPoint,
  tolerance: number,
): LineTarget {
  let selected: LineTarget | undefined,
    best = tolerance;
  drawing.contours.forEach((c, i) => {
    if (c.type !== "path") return;
    let start = c.start;
    c.segments.forEach((segment, j) => {
      if (segment.type === "line") {
        const vector = subtract(segment.end, start),
          length = vector[0] ** 2 + vector[1] ** 2;
        const t = length
          ? Math.max(
              0,
              Math.min(
                1,
                ((point[0] - start[0]) * vector[0] +
                  (point[1] - start[1]) * vector[1]) /
                  length,
              ),
            )
          : 0;
        const distance = Math.hypot(
          point[0] - start[0] - t * vector[0],
          point[1] - start[1] - t * vector[1],
        );
        if (distance < best) {
          best = distance;
          selected = {
            contour: i,
            segment: j,
            start: [...start],
            end: [...segment.end],
            parameter: t,
          };
        }
      }
      start = segment.end;
    });
  });
  if (!selected) throw new Error("Select a straight sketch segment.");
  return selected;
}
/** Exact intersections of a target line with line and circle boundaries. */
function intersections(drawing: SketchDrawing, target: LineTarget, includePoints=false): number[] {
  const out: number[] = [],
    direction = subtract(target.end, target.start);
  if(includePoints)for(const point of sketchPointBoundaries(drawing)){const t=pointOnLineParameter(point,target.start,target.end);if(t!==undefined)out.push(t);}
  drawing.contours.forEach((c, i) => {
    if (c.type === "circle") {
      const q = subtract(target.start, c.center),
        a = direction[0] ** 2 + direction[1] ** 2,
        b = 2 * (q[0] * direction[0] + q[1] * direction[1]),
        cc = q[0] ** 2 + q[1] ** 2 - c.radius ** 2,
        discriminant = b * b - 4 * a * cc;
      if (discriminant >= -epsilon) {
        const root = Math.sqrt(Math.max(0, discriminant));
        out.push((-b - root) / (2 * a), (-b + root) / (2 * a));
      }
    } else {
      let start = c.start;
      c.segments.forEach((s, j) => {
        if (!(i === target.contour && j === target.segment))
          out.push(
            ...lineSegmentIntersections(target.start, target.end, start, s),
          );
        start = s.end;
      });
    }
  });
  return out
    .sort((a, b) => a - b)
    .filter((v, i, list) => i === 0 || Math.abs(v - list[i - 1]) > epsilon);
}
/** Straight-line picking with the same topology/constraint handling as general Trim. */
export function trimSketchLine(
  drawing: SketchDrawing,
  point: SketchPoint,
  tolerance: number,
): SketchDrawing {
  const target = nearestSketchLine(drawing, point, tolerance);
  return trimPickedCurve(drawing, { ...target, point: false });
}
export class ExtensionNeedsEndpoint extends Error {
  constructor() {
    super("No boundary intersects this extension. Choose a new endpoint.");
  }
}
export function extendSketchLine(
  drawing: SketchDrawing,
  point: SketchPoint,
  tolerance: number,
  newEndpoint?: SketchPoint,
): SketchDrawing {
  const target = nearestSketchLine(drawing, point, tolerance);
  const original = drawing.contours[target.contour];
  if (original.type !== "path") throw new Error("Select a path.");
  const start = target.parameter < 0.5;
  if (
    contourClosed(original) ||
    (start
      ? target.segment !== 0
      : target.segment !== original.segments.length - 1)
  )
    throw new Error("Select the free end of an open contour.");
  const candidates = intersections(drawing, target, true),
    boundary = start
      ? [...candidates].reverse().find((t) => t < -epsilon)
      : candidates.find((t) => t > 1 + epsilon);
  let parameter = boundary;
  if (parameter === undefined) {
    if (!newEndpoint) throw new ExtensionNeedsEndpoint();
    if (!newEndpoint.every(Number.isFinite))
      throw new Error("Enter a finite endpoint.");
    const dx = target.end[0] - target.start[0],
      dy = target.end[1] - target.start[1];
    parameter =
      ((newEndpoint[0] - target.start[0]) * dx +
        (newEndpoint[1] - target.start[1]) * dy) /
      (dx * dx + dy * dy);
    if (start ? parameter >= -epsilon : parameter <= 1 + epsilon)
      throw new Error("The new endpoint must extend beyond the selected end.");
  }
  const end: SketchPoint = [
    target.start[0] + parameter * (target.end[0] - target.start[0]),
    target.start[1] + parameter * (target.end[1] - target.start[1]),
  ];
  const next = structuredClone(drawing),
    c = next.contours[target.contour];
  if (c.type === "path") {
    if (start) c.start = end;
    else c.segments[target.segment].end = end;
  }
  remapExtendedContacts(next, target.contour, target.segment, start ? parameter : 0, start ? 1 : parameter);
  assertConstraintsSatisfied(next);
  validateSketchDrawing(next);
  return linkExtendedEndpoint(next, {kind:"point",contour:target.contour,index:start?0:target.segment+1});
}
