import {
  contourClosed,
  validateSketchDrawing,
  type SketchDrawing,
  type SketchPoint,
  type SketchSegment,
} from "../drawing";
import { curveJet } from "../curves/derivatives";
import type { SketchEntityRef } from "../solver/types";

export interface TangentArcSource {
  contour: number;
  segment: number;
  endpoint: 0 | 1;
}
function sourceJet(d: SketchDrawing, ref: TangentArcSource) {
  const path = d.contours[ref.contour];
  if (
    !path ||
    path.type !== "path" ||
    !Number.isInteger(ref.segment) ||
    ref.segment < 0 ||
    !path.segments[ref.segment] ||
    (ref.endpoint !== 0 && ref.endpoint !== 1)
  )
    throw new Error("Select an existing curve endpoint.");
  const start =
    ref.segment === 0 ? path.start : path.segments[ref.segment - 1].end;
  const jet = curveJet({ start, segment: path.segments[ref.segment] })(
    ref.endpoint,
  );
  const length = Math.hypot(...jet.first);
  if (length < 1e-10)
    throw new Error("This endpoint has no tangent direction.");
  const direction = ref.endpoint ? 1 : -1;
  return {
    point: jet.point,
    tangent: jet.first.map((v) => (direction * v) / length) as SketchPoint,
  };
}

/** Find an endpoint in sketch coordinates. Prefer a path's end at shared vertices. */
export function pickTangentArcSource(
  d: SketchDrawing,
  point: SketchPoint,
  tolerance: number,
): TangentArcSource {
  let best: TangentArcSource | undefined,
    distance = tolerance;
  d.contours.forEach((path, contour) => {
    if (path.type !== "path") return;
    path.segments.forEach((_, segment) => {
      for (const endpoint of [1, 0] as const) {
        const ref = { contour, segment, endpoint };
        try {
          const jet = sourceJet(d, ref),
            delta = Math.hypot(
              jet.point[0] - point[0],
              jet.point[1] - point[1],
            );
          if (delta < distance) {
            best = ref;
            distance = delta;
          }
        } catch {
          /* Stationary endpoints cannot start a tangent arc. */
        }
      }
    });
  });
  if (!best)
    throw new Error(
      "Click an existing line or curve endpoint to start a tangent arc.",
    );
  return best;
}

export function tangentArcContour(
  d: SketchDrawing,
  ref: TangentArcSource,
  end: SketchPoint,
) {
  const { point: start, tangent } = sourceJet(d, ref);
  if (!end.every(Number.isFinite))
    throw new Error("Arc endpoint must be finite.");
  const dx = end[0] - start[0],
    dy = end[1] - start[1];
  const normal: SketchPoint = [-tangent[1], tangent[0]];
  const height = dx * normal[0] + dy * normal[1];
  if (Math.hypot(dx, dy) < 1e-8 || Math.abs(height) < 1e-8)
    throw new Error("Move away from the tangent line to form an arc.");
  const offset = (dx * dx + dy * dy) / (2 * height);
  const center: SketchPoint = [
    start[0] + offset * normal[0],
    start[1] + offset * normal[1],
  ];
  const a = Math.atan2(start[1] - center[1], start[0] - center[0]);
  const b = Math.atan2(end[1] - center[1], end[0] - center[0]),
    tau = 2 * Math.PI;
  const sweep = offset > 0 ? (b - a + tau) % tau : -((a - b + tau) % tau);
  const radius = Math.abs(offset);
  const segment: SketchSegment = {
    type: "arc",
    end: [...end],
    middle: [
      center[0] + radius * Math.cos(a + sweep / 2),
      center[1] + radius * Math.sin(a + sweep / 2),
    ],
  };
  return {
    type: "path" as const,
    start: [...start] as SketchPoint,
    segments: [segment],
  };
}

/** Append when extending an open path; otherwise keep an explicit constrained branch. */
export function createSketchTangentArc(
  source: SketchDrawing,
  ref: TangentArcSource,
  end: SketchPoint,
  construction = false,
) {
  const preview = tangentArcContour(source, ref, end),
    next = structuredClone(source);
  const path = next.contours[ref.contour];
  let contour = next.contours.length,
    segment = 0;
  if (
    path.type === "path" &&
    ref.endpoint === 1 &&
    ref.segment === path.segments.length - 1 &&
    !contourClosed(path) &&
    Boolean(path.construction) === construction
  ) {
    contour = ref.contour;
    segment = path.segments.length;
    path.segments.push(preview.segments[0]);
  } else
    next.contours.push({
      ...preview,
      ...(construction ? { construction: true } : {}),
    });
  const constraints = (next.constraints ??= []);
  let sequence = 1;
  const ids = new Set(constraints.map((c) => c.id));
  while (ids.has(`tangent-arc-${sequence}`)) sequence++;
  const a: SketchEntityRef = {
    contour: ref.contour,
    kind: "curve",
    index: ref.segment,
    parameter: ref.endpoint,
  };
  const b: SketchEntityRef = {
    contour,
    kind: "curve",
    index: segment,
    parameter: 0,
  };
  constraints.push({ id: `tangent-arc-${sequence}`, kind: "tangent", a, b });
  validateSketchDrawing(next);
  return { drawing: next, contour, preview };
}
