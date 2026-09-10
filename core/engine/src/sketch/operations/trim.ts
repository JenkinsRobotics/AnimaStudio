import { linkRetainedEllipse } from "./retained-ellipse-relations";
import { identifyTrimmedPaths } from "./trim-identities";
import { sketchArcGeometry } from "../arc-geometry";
import { remapTrimReferences, type TrimSegmentOrigin } from "./trim-references";
import { remapCircleReferences } from "./circle-references";
import { assertConstraintsSatisfied } from "./preserve-constraints";
import {
  contourClosed,
  validateSketchDrawing,
  type SketchDrawing,
  type SketchPoint,
  type SketchSegment,
} from "../drawing";
import { curveIntersections, type Curve } from "../curves/pairs";
import {
  drawingCurves,
  pickCurve,
  circleSegments,
  type PickedCurve,
} from "../curves/picking";
import { segmentPoint } from "../curves/parameterization";
import { subdivideSegment } from "../curves/subdivide";
import { deleteSketchContour } from "./delete";
const epsilon = 1e-7;
const unique = (values: number[]) =>
  values
    .sort((a, b) => a - b)
    .filter((v, i, a) => !i || Math.abs(v - a[i - 1]) > epsilon);
/** Remove the clicked interval, retaining exact curve segments and source immutability. */
export function trimSketchCurve(
  drawing: SketchDrawing,
  point: SketchPoint,
  tolerance: number,
): SketchDrawing {
  return trimPickedCurve(drawing, pickCurve(drawing, point, tolerance));
}
/** Shared trim implementation; callers retain their own picking policy. */
export function trimPickedCurve(
  drawing: SketchDrawing,
  target: Pick<PickedCurve, "contour" | "segment" | "parameter" | "point">,
): SketchDrawing {
  if (target.point) return deleteSketchContour(drawing, target.contour);
  const source = drawing.contours[target.contour],
    curves = drawingCurves(drawing);
  if (source.type === "circle") {
    const targets = circleSegments(source.center, source.radius),
      parameters: number[] = [];
    for (const boundary of curves) {
      if (boundary.contour === target.contour) continue;
      const other = drawing.contours[boundary.contour];
      if (
        other.type === "circle" &&
        Math.hypot(
          other.center[0] - source.center[0],
          other.center[1] - source.center[1],
        ) < 1e-8 &&
        Math.abs(other.radius - source.radius) < 1e-8
      )
        continue;
      targets.forEach((curve, half) => {
        for (const hit of curveIntersections(curve, boundary.curve))
          parameters.push(((half + hit.first) / 2) % 1);
      });
    }
    const cuts = unique(parameters);
    if (cuts.length < 2) return deleteSketchContour(drawing, target.contour);
    const before =
      [...cuts].reverse().find((t) => t < target.parameter - epsilon) ??
      cuts.at(-1)! - 1;
    const after =
      cuts.find((t) => t > target.parameter + epsilon) ?? cuts[0] + 1;
    const start = after * 2 * Math.PI,
      end = (before + 1) * 2 * Math.PI;
    const at = (a: number): SketchPoint => [
      source.center[0] + source.radius * Math.cos(a),
      source.center[1] + source.radius * Math.sin(a),
    ];
    const next = structuredClone(drawing);
    next.contours[target.contour] = {
      type: "path",
      ...(source.sourceLayer !== undefined
        ? { sourceLayer: source.sourceLayer }
        : {}),
      construction: source.construction,
      hole: false,
      start: at(start),
      segments: [{ type: "arc", middle: at((start + end) / 2), end: at(end) }],
    };
    remapCircleReferences(drawing, next, target.contour);
    assertConstraintsSatisfied(next);
    validateSketchDrawing(next);
    return next;
  }
  const curve: Curve = {
    start:
      target.segment === 0
        ? source.start
        : source.segments[target.segment - 1].end,
    segment: source.segments[target.segment],
  };
  const cuts: number[] = [0, 1];
  for (const boundary of curves) {
    if (
      boundary.contour === target.contour &&
      boundary.segment === target.segment
    )
      continue;
    const other = drawing.contours[boundary.contour];
    if (other.type === "circle" && curve.segment.type === "arc") {
      const arc = sketchArcGeometry(
        curve.start,
        curve.segment.middle,
        curve.segment.end,
      );
      if (
        Math.hypot(
          other.center[0] - arc.center[0],
          other.center[1] - arc.center[1],
        ) < 1e-8 &&
        Math.abs(other.radius - arc.radius) < 1e-8
      )
        continue;
    }
    for (const hit of curveIntersections(curve, boundary.curve))
      if (hit.first > epsilon && hit.first < 1 - epsilon) cuts.push(hit.first);
  }
  const boundaries = unique(cuts),
    lo =
      [...boundaries].reverse().find((t) => t < target.parameter - epsilon) ??
      0,
    hi = boundaries.find((t) => t > target.parameter + epsilon) ?? 1;
  const left: SketchSegment[] = structuredClone(
    source.segments.slice(0, target.segment),
  );
  if (lo > epsilon)
    left.push(subdivideSegment(curve.start, curve.segment, lo)[0]);
  const right: SketchSegment[] = [];
  if (hi < 1 - epsilon)
    right.push(subdivideSegment(curve.start, curve.segment, hi)[1]);
  right.push(...structuredClone(source.segments.slice(target.segment + 1)));
  const origin = (segment: number): TrimSegmentOrigin => ({
    segment,
    keepStart: true,
    keepEnd: true,
    whole: true,
    interval: [0, 1],
  });
  const leftOrigins = source.segments
    .slice(0, target.segment)
    .map((_, i) => origin(i));
  if (lo > epsilon)
    leftOrigins.push({
      segment: target.segment,
      keepStart: true,
      keepEnd: false,
      whole: false,
      interval: [0, lo],
    });
  const rightOrigins: TrimSegmentOrigin[] = [];
  if (hi < 1 - epsilon)
    rightOrigins.push({
      segment: target.segment,
      keepStart: false,
      keepEnd: true,
      whole: false,
      interval: [hi, 1],
    });
  rightOrigins.push(
    ...source.segments
      .slice(target.segment + 1)
      .map((_, i) => origin(target.segment + 1 + i)),
  );
  const layout: TrimSegmentOrigin[][] = contourClosed(source)
    ? right.length + left.length
      ? [[...rightOrigins, ...leftOrigins]]
      : []
    : [
        ...(left.length ? [leftOrigins] : []),
        ...(right.length ? [rightOrigins] : []),
      ];
  const replacement: SketchDrawing["contours"] = [];
  const rightStart = segmentPoint(curve.start, curve.segment, hi);
  if (contourClosed(source)) {
    const segments = [...right, ...left];
    if (segments.length)
      replacement.push({ ...source, hole: false, start: rightStart, segments });
  } else {
    if (left.length)
      replacement.push({
        ...source,
        hole: false,
        start: [...source.start],
        segments: left,
      });
    if (right.length)
      replacement.push({
        ...source,
        hole: false,
        start: rightStart,
        segments: right,
      });
  }
  identifyTrimmedPaths(source, replacement, layout);
  const next = structuredClone(drawing);
  if (replacement.length > 1)
    for (const contour of replacement) delete contour.id;
  next.contours.splice(target.contour, 1, ...replacement);
  remapTrimReferences(
    drawing,
    next,
    target.contour,
    layout,
    contourClosed(source),
  );
  linkRetainedEllipse(drawing, next, target.contour, layout.length);
  assertConstraintsSatisfied(next);
  validateSketchDrawing(next);
  return next;
}
