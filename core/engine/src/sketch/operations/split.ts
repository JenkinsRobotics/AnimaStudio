import { retainSplitArcSpan } from "./split-arc-span";
import { needsSplitLineSpan, retainSplitLineSpan } from "./split-line-span";
import { remapSplitEllipse } from "./split-ellipse-relations";
import { identifySplitSegments } from "./split-identities";
import {
  resolveSegmentReference,
  identifySegmentReference,
} from "../solver/segment-reference";
import { splitPreservesContact, remapSplitContact } from "./split-contact";
import { remapSplitControl } from "./split-control";
import { remapCircleReferences } from "./circle-references";
import {
  linkSplitArcs,
  preservesArcLocus,
  linkSplitLines,
  preservesLineLocus,
} from "./split-relations";
import { assertConstraintsSatisfied } from "./preserve-constraints";
import {
  validateSketchDrawing,
  type SketchDrawing,
  type SketchPoint,
} from "../drawing";
import type { SketchEntityRef } from "../drawing-constraints";
import { closestSegmentParameter } from "../curves/parameterization";
import { subdivideSegment } from "../curves/subdivide";
/** Split one exact path segment. Point constraints survive through explicit index remapping. */
export function splitSketchSegment(
  drawing: SketchDrawing,
  point: SketchPoint,
  tolerance: number,
): SketchDrawing {
  let target: { contour: number; segment: number; t: number } | undefined,
    distance = tolerance;
  drawing.contours.forEach((c, i) => {
    if (c.type !== "path") return;
    let start = c.start;
    c.segments.forEach((segment, j) => {
      const closest = closestSegmentParameter(start, segment, point);
      if (closest.distance < distance) {
        distance = closest.distance;
        target = { contour: i, segment: j, t: closest.parameter };
      }
      start = segment.end;
    });
  });
  if (!target)
    throw new Error("Select a line, arc, ellipse segment or Bezier curve.");
  const selected = target;
  const normalize = (ref: SketchEntityRef) =>
    ref.contour === selected.contour
      ? resolveSegmentReference(drawing.contours[ref.contour], ref)
      : ref;
  const refersToSegment = (reference: SketchEntityRef) => {
    const ref = normalize(reference);
    return (
      ref.contour === selected.contour &&
      (ref.kind === "contour" || ref.index === selected.segment) &&
      (ref.kind !== "point" || ref.control !== undefined)
    );
  };
  const source = drawing.contours[selected.contour];
  const isEllipse =
    source.type === "path" &&
    source.segments[selected.segment].type === "ellipse";
  const isArc =
    source.type === "path" && source.segments[selected.segment].type === "arc";
  const isLine =
    source.type === "path" && source.segments[selected.segment].type === "line";
  if (
    drawing.constraints?.some((c) =>
      [c.a, c.b, c.axis].some(
        (ref) =>
          ref &&
          refersToSegment(ref) &&
          !(ref.kind === "point" && ref.control !== undefined) &&
          !splitPreservesContact(c, ref) &&
          !(
            (isEllipse &&
              [
                "ellipse-shape",
                "ellipse-locus",
                "concentric",
                "quadrant",
              ].includes(c.kind)) ||
            (isArc && (preservesArcLocus(c) || c.kind === "midpoint")) ||
            (isLine && (preservesLineLocus(c) || needsSplitLineSpan(c)))
          ),
      ),
    )
  )
    throw new Error(
      "This segment has constraints that require split remapping. Its geometry was not changed.",
    );
  const next = structuredClone(drawing),
    c = next.contours[selected.contour];
  if (c.type !== "path") throw new Error("Select a path segment.");
  const start =
    selected.segment === 0 ? c.start : c.segments[selected.segment - 1].end;
  c.segments.splice(
    selected.segment,
    1,
    ...identifySplitSegments(
      c.segments[selected.segment],
      subdivideSegment(start, c.segments[selected.segment], selected.t),
    ),
  );
  const remap = (ref: SketchEntityRef) =>
    ref.contour === selected.contour &&
    ref.kind === "point" &&
    ref.control !== undefined &&
    ref.index === selected.segment
      ? remapSplitControl(ref, selected.contour, selected.segment, selected.t)
      : ref.contour === selected.contour &&
          ref.kind === "curve" &&
          ref.index === selected.segment
        ? remapSplitContact(ref, selected.contour, selected.segment, selected.t)
        : ref.contour === selected.contour &&
            ref.index !== undefined &&
            ref.index > selected.segment
          ? { ...ref, index: ref.index + 1 }
          : ref;
  const map = (reference: SketchEntityRef) => {
    const ref = normalize(reference),
      mapped = remap(ref);
    if (
      ref.contour !== selected.contour ||
      ref.segmentId === undefined ||
      ref.index !== selected.segment
    )
      return mapped;
    const { segmentId: discarded, ...local } = mapped;
    return identifySegmentReference(c, local);
  };
  next.constraints = next.constraints?.map((c) => ({
    ...c,
    a: map(c.a),
    ...(c.b ? { b: map(c.b) } : {}),
    ...(c.axis ? { axis: map(c.axis) } : {}),
  }));
  if (isEllipse)
    remapSplitEllipse(drawing, next, selected.contour, selected.segment);
  if (isArc)
    retainSplitArcSpan(drawing, next, selected.contour, selected.segment);
  if (isArc)
    linkSplitArcs(
      (next.constraints ??= []),
      selected.contour,
      selected.segment,
    );
  if (isLine) retainSplitLineSpan(next, selected.contour, selected.segment);
  if (isLine)
    linkSplitLines(
      (next.constraints ??= []),
      selected.contour,
      selected.segment,
    );
  assertConstraintsSatisfied(next);
  validateSketchDrawing(next);
  return next;
}

/** A circle needs two selected positions; retain the original circular design relations. */
export function splitSketchCircle(
  drawing: SketchDrawing,
  index: number,
  first: SketchPoint,
  second: SketchPoint,
): SketchDrawing {
  const circle = drawing.contours[index];
  if (circle?.type !== "circle") throw new Error("Select a circle.");
  if (![...first, ...second].every(Number.isFinite))
    throw new Error("Split points must be finite.");
  const angle = (p: SketchPoint) => {
    if (Math.hypot(p[0] - circle.center[0], p[1] - circle.center[1]) < 1e-8)
      throw new Error("Choose a position on the circumference.");
    return Math.atan2(p[1] - circle.center[1], p[0] - circle.center[0]);
  };
  const a = angle(first),
    b = angle(second),
    tau = 2 * Math.PI,
    sweep = (b - a + tau) % tau;
  if (sweep < 1e-5 || tau - sweep < 1e-5)
    throw new Error("Choose two distinct positions on the circle.");
  const at = (t: number): SketchPoint => [
    circle.center[0] + circle.radius * Math.cos(t),
    circle.center[1] + circle.radius * Math.sin(t),
  ];
  const next = structuredClone(drawing);
  next.contours[index] = {
    type: "path",
    start: at(a),
    ...(circle.sourceLayer !== undefined
      ? { sourceLayer: circle.sourceLayer }
      : {}),
    construction: circle.construction,
    hole: circle.hole,
    segments: [
      { type: "arc", middle: at(a + sweep / 2), end: at(a + sweep) },
      { type: "arc", middle: at(a + sweep + (tau - sweep) / 2), end: at(a) },
    ],
  };
  remapCircleReferences(drawing, next, index);
  linkSplitArcs(next.constraints!, index, 0);
  assertConstraintsSatisfied(next);
  validateSketchDrawing(next);
  return next;
}
