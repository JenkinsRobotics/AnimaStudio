import { resolveSegmentReference } from "../solver/segment-reference";
import { contourClosed } from "../drawing";
import { slotChainContour } from "./slot-chain";
import { sketchArcGeometry } from "../arc-geometry";
import type {
  SketchDrawing,
  SketchPoint,
  SketchSegment,
  SketchContour,
} from "../drawing";
import type { SketchEntityRef } from "../solver/types";
import { offsetSketchContour } from "./offset";
import { curveJet } from "./derivatives";
export function slotCenterline(
  d: SketchDrawing,
  ref: SketchEntityRef,
): { start: SketchPoint; segment: SketchSegment } {
  const p = d.contours[ref.contour];
  ref = resolveSegmentReference(p, ref);
  if (
    p?.type !== "path" ||
    !Number.isInteger(ref.index) ||
    ref.index! < 0 ||
    !["line", "arc"].includes(ref.kind) ||
    p.segments[ref.index!]?.type !== ref.kind
  )
    throw Error("Select a line or circular arc as the slot centerline.");
  return {
    start: ref.index === 0 ? p.start : p.segments[ref.index! - 1].end,
    segment: p.segments[ref.index!],
  };
}
/** Exact closed slot around one line/circular arc. Width is the cap diameter. */
export function slotContour(
  start: SketchPoint,
  segment: SketchSegment,
  width: number,
): Extract<SketchContour, { type: "path" }> {
  if (!Number.isFinite(width) || width <= 1e-8)
    throw Error("Slot width must be positive and finite.");
  if (segment.type === "arc") {
    const arc = sketchArcGeometry(start, segment.middle, segment.end);
    if (
      Math.abs(arc.sweep) > Math.PI &&
      width >=
        Math.hypot(segment.end[0] - start[0], segment.end[1] - start[1]) - 1e-8
    )
      throw Error(
        "Slot end caps overlap; this width requires topology repair.",
      );
  }
  // Each boundary is new geometry; source subentity IDs must not be copied twice.
  const { id: sourceId, endVertexId: sourceVertexId, ...geometry } = segment;
  const radius = width / 2,
    centerline: SketchContour = { type: "path", start, segments: [geometry] };
  const left = offsetSketchContour(centerline, radius),
    right = offsetSketchContour(centerline, -radius);
  if (left.type !== "path" || right.type !== "path") throw Error();
  const jet = curveJet({ start, segment }),
    first = jet(0).first,
    last = jet(1).first;
  const cap = (p: SketchPoint, v: SketchPoint, sign: number): SketchPoint => {
    const n = Math.hypot(...v);
    if (n < 1e-10) throw Error("Slot centerline has no tangent.");
    return [
      p[0] + (sign * radius * v[0]) / n,
      p[1] + (sign * radius * v[1]) / n,
    ];
  };
  const end = segment.end;
  return {
    type: "path",
    start: left.start,
    segments: [
      left.segments[0],
      { type: "arc", middle: cap(end, last, 1), end: right.segments[0].end },
      { ...right.segments[0], end: right.start },
      { type: "arc", middle: cap(start, first, -1), end: left.start },
    ],
  };
}

export function slotCenterlinePath(
  d: SketchDrawing,
  ref: SketchEntityRef,
): Extract<SketchContour, { type: "path" }> {
  if (ref.kind === "contour") {
    const p = d.contours[ref.contour];
    if (
      p?.type !== "path" ||
      contourClosed(p) ||
      !p.segments.length ||
      p.segments.some((s) => s.type !== "line" && s.type !== "arc")
    )
      throw Error("Select an open line/arc chain.");
    return p;
  }
  const { start, segment } = slotCenterline(d, ref);
  return { type: "path", start, segments: [segment] };
}
export function slotProfile(
  d: SketchDrawing,
  ref: SketchEntityRef,
  width: number,
): Extract<SketchContour, { type: "path" }> {
  const path = slotCenterlinePath(d, ref);
  return path.segments.length === 1
    ? slotContour(path.start, path.segments[0], width)
    : slotChainContour(path, width);
}
