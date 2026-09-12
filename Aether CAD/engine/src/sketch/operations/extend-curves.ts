import { remapExtendedContacts } from "./extension-contacts";
import { linkExtendedEndpoint } from "./extension-point-link";
import { sketchPointBoundaries } from "../curves/point-boundaries";
import { assertConstraintsSatisfied } from "./preserve-constraints";
import {
  contourClosed,
  validateSketchDrawing,
  type SketchDrawing,
  type SketchPoint,
  type SketchSegment,
} from "../drawing";
import { circleSegments, drawingCurves, pickCurve } from "../curves/picking";
import { curveIntersections } from "../curves/pairs";
import {
  ellipseFrame,
  ellipsePoint,
  type EllipseFrame,
} from "../curves/parameterization";
import { sketchArcGeometry } from "../arc-geometry";
import { extendSketchLine, ExtensionNeedsEndpoint } from "./trim-extend";
const tau = Math.PI * 2;
const positive = (angle: number) => ((angle % tau) + tau) % tau;
/** Extend a free conic endpoint along its original locus, never a tangent approximation. */
export function extendSketchCurve(
  drawing: SketchDrawing,
  point: SketchPoint,
  tolerance: number,
  endpoint?: SketchPoint,
): SketchDrawing {
  const target = pickCurve(drawing, point, tolerance);
  const source = drawing.contours[target.contour];
  if (source.type !== "path" || !source.segments.length)
    throw new Error("Select an open curve endpoint.");
  const segment = source.segments[target.segment];
  if (segment.type === "line")
    return extendSketchLine(drawing, point, tolerance, endpoint);
  if (segment.type !== "arc" && segment.type !== "ellipse")
    throw new Error("Cubic extension is not implemented yet.");
  const atStart = target.parameter < 0.5;
  if (
    contourClosed(source) ||
    (atStart
      ? target.segment !== 0
      : target.segment !== source.segments.length - 1)
  )
    throw new Error("Select a free contour endpoint.");
  const start = target.segment
    ? source.segments[target.segment - 1].end
    : source.start;
  let frame: EllipseFrame;
  if (segment.type === "ellipse") frame = ellipseFrame(start, segment);
  else {
    const arc = sketchArcGeometry(start, segment.middle, segment.end);
    frame = { ...arc, radiusX: arc.radius, radiusY: arc.radius, rotation: 0 };
  }
  const direction = Math.sign(frame.sweep) * (atStart ? -1 : 1);
  const origin = frame.startAngle + (atStart ? 0 : frame.sweep);
  const available = tau - Math.abs(frame.sweep);
  const distance = (p: SketchPoint) => {
    const x = p[0] - frame.center[0],
      y = p[1] - frame.center[1],
      c = Math.cos(frame.rotation),
      s = Math.sin(frame.rotation);
    const angle = Math.atan2(
      (-s * x + c * y) / frame.radiusY,
      (c * x + s * y) / frame.radiusX,
    );
    return positive(direction * (angle - origin));
  };
  // Two exact half-ellipses cover the locus. Finite boundaries supply candidates.
  const at = (angle: number) =>
    ellipsePoint({ ...frame, startAngle: angle, sweep: 1 }, 0);
  const locus =
    segment.type === "arc"
      ? circleSegments(frame.center, frame.radiusX)
      : [0, Math.PI].map((angle) => ({
          start: at(angle),
          segment: {
            type: "ellipse" as const,
            end: at(angle + Math.PI),
            radiusX: frame.radiusX,
            radiusY: frame.radiusY,
            rotationDegrees: (frame.rotation * 180) / Math.PI,
            largeArc: false,
            sweep: true,
          },
        }));
  const candidates: number[] = [];
  for(const point of sketchPointBoundaries(drawing)){
    const delta=distance(point),projected=at(origin+direction*delta);
    if(delta>1e-7&&delta<available-1e-7&&Math.hypot(projected[0]-point[0],projected[1]-point[1])<1e-7)candidates.push(delta);
  }
  for (const boundary of drawingCurves(drawing)) {
    if (
      boundary.contour === target.contour &&
      boundary.segment === target.segment
    )
      continue;
    for (const half of locus)
      for (const hit of curveIntersections(half, boundary.curve)) {
        const delta = distance(hit.point);
        if (delta > 1e-7 && delta < available - 1e-7) candidates.push(delta);
      }
  }
  let delta = candidates.length ? Math.min(...candidates) : undefined;
  if (delta === undefined) {
    if (!endpoint) throw new ExtensionNeedsEndpoint();
    if (
      Math.hypot(endpoint[0] - frame.center[0], endpoint[1] - frame.center[1]) <
      1e-9
    )
      throw new Error("Choose an endpoint away from the curve center.");
    delta = distance(endpoint);
    if (delta <= 1e-7 || delta >= available - 1e-7)
      throw new Error(
        "Choose a point beyond the free end without closing the curve.",
      );
  }
  const newStart = atStart
    ? frame.startAngle + direction * delta
    : frame.startAngle;
  const sweep = frame.sweep + Math.sign(frame.sweep) * delta;
  const updatedFrame = { ...frame, startAngle: newStart, sweep };
  const end = ellipsePoint(updatedFrame, 1);
  const updated: SketchSegment =
    segment.type === "arc"
      ? { type: "arc", middle: ellipsePoint(updatedFrame, 0.5), end }
      : {
          ...segment,
          end,
          radiusX: frame.radiusX,
          radiusY: frame.radiusY,
          largeArc: Math.abs(sweep) > Math.PI,
          sweep: sweep > 0,
        };
  const next = structuredClone(drawing);
  const contour = next.contours[target.contour];
  if (contour.type !== "path") throw new Error("Expected path.");
  if (atStart) contour.start = ellipsePoint(updatedFrame, 0);
  contour.segments[target.segment] = updated;
  const extension = delta / Math.abs(frame.sweep);
  remapExtendedContacts(next, target.contour, target.segment, atStart ? -extension : 0, atStart ? 1 : 1 + extension);
  assertConstraintsSatisfied(next);
  validateSketchDrawing(next);
  return linkExtendedEndpoint(next, {kind:"point",contour:target.contour,index:atStart?0:target.segment+1});
}
