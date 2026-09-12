/** SPIKE — is FreeCAD's PlaneGCS a drop-in for our hand-rolled solver?
 *
 *  Answers one question: does `@salusoft89/planegcs` (FreeCAD's Sketcher
 *  solver, compiled to WASM) reproduce `solveDrawingConstraints` closely
 *  enough to replace ~2.6k lines of residuals, damping and rank diagnostics?
 *
 *  Not a migration. The default solver is untouched; this runs only when
 *  AETHER_SOLVER=planegcs, so the existing solver test corpus can be pointed
 *  at it and the coverage counted. Geometry or constraint kinds this spike
 *  does not map throw `UnsupportedByPlanegcs`, so a test run separates
 *  "planegcs disagrees" from "the spike never tried".
 *
 *  ponytail: deliberately partial — lines, arcs and circles with the core
 *  constraint kinds. Ellipses, splines, patterns, slots and offsets are the
 *  long tail and only worth mapping if the core lands.
 */
import { appendFileSync } from "node:fs";
import type { SketchDrawing, SketchPoint } from "../drawing";
import { dimensionDriver } from "./dimension-links";
import type { DrawingConstraint, SketchEntityRef } from "./types";

export class UnsupportedByPlanegcs extends Error {
  constructor(readonly what: string) {
    super(`planegcs spike does not map ${what}`);
    this.name = "UnsupportedByPlanegcs";
  }
}

type Primitive = Record<string, unknown> & { id: string; type: string };

/** The wrapper needs an awaited WASM init, but our seam is synchronous — so it
 *  is initialized once up front and used synchronously afterwards. A real
 *  migration would pre-warm this during app startup. */
let wrapper: {
  clear_data: () => void;
  push_primitives_and_params: (items: Primitive[]) => void;
  solve: () => void;
  apply_solution: () => void;
  sketch_index: { get_primitives: () => Primitive[] };
  get_gcs_conflicting_constraints: () => string[];
  get_gcs_redundant_constraints: () => string[];
} | null = null;

export async function initPlanegcsSpike(): Promise<void> {
  if (wrapper) return;
  const { make_gcs_wrapper } = await import("@salusoft89/planegcs");
  const { createRequire } = await import("node:module");
  const require = createRequire(import.meta.url);
  const wasm = require.resolve(
    "@salusoft89/planegcs/dist/planegcs_dist/planegcs.wasm",
  );
  wrapper = (await make_gcs_wrapper(wasm)) as unknown as typeof wrapper;
}

export function planegcsReady(): boolean {
  return wrapper !== null;
}

const arcFromThreePoints = (
  start: SketchPoint, middle: SketchPoint, end: SketchPoint,
) => {
  // Circumcentre of the three points; the arc's own geometry module owns the
  // production version of this, but the spike keeps its input explicit.
  const [ax, ay] = start, [bx, by] = middle, [cx, cy] = end;
  const d = 2 * (ax * (by - cy) + bx * (cy - ay) + cx * (ay - by));
  if (Math.abs(d) < 1e-12) throw new UnsupportedByPlanegcs("a degenerate arc");
  const ux =
    ((ax * ax + ay * ay) * (by - cy) +
      (bx * bx + by * by) * (cy - ay) +
      (cx * cx + cy * cy) * (ay - by)) / d;
  const uy =
    ((ax * ax + ay * ay) * (cx - bx) +
      (bx * bx + by * by) * (ax - cx) +
      (cx * cx + cy * cy) * (bx - ax)) / d;
  const radius = Math.hypot(ax - ux, ay - uy);
  const angle = (p: SketchPoint) => Math.atan2(p[1] - uy, p[0] - ux);
  // planegcs arcs run counter-clockwise from start_angle to end_angle.
  const startAngle = angle(start), endAngle = angle(end), midAngle = angle(middle);
  const between = (from: number, to: number, probe: number) => {
    const span = (to - from + 2 * Math.PI) % (2 * Math.PI);
    const at = (probe - from + 2 * Math.PI) % (2 * Math.PI);
    return at <= span;
  };
  const counterClockwise = between(startAngle, endAngle, midAngle);
  return {
    center: [ux, uy] as SketchPoint,
    radius,
    startAngle: counterClockwise ? startAngle : endAngle,
    endAngle: counterClockwise ? endAngle : startAngle,
    reversed: !counterClockwise,
  };
};

/** Ids are derived from the drawing's own indices, so a solved primitive can
 *  be written straight back to the contour it came from. */
const pointID = (contour: number, index: number) => `p:${contour}:${index}`;
const centerID = (contour: number, segment?: number) =>
  segment === undefined ? `p:${contour}:center` : `p:${contour}:${segment}:center`;
const segmentID = (contour: number, segment: number) => `s:${contour}:${segment}`;
const circleID = (contour: number) => `c:${contour}`;

export function solveDrawingConstraintsWithPlanegcs(
  source: SketchDrawing,
  options: { fixedContours?: ReadonlySet<number> } = {},
): SketchDrawing {
  if (!wrapper) throw new Error("planegcs spike is not initialized");
  const drawing = structuredClone(source);
  const constraints = drawing.constraints ?? [];
  if (!constraints.length) return drawing;
  for (const constraint of constraints)
    if (
      constraint.valueFrom !== undefined || constraint.valueSign !== undefined ||
      constraint.valueScale !== undefined || constraint.valueOffset !== undefined
    ) dimensionDriver(drawing, constraint);

  const used = new Set(
    constraints
      .filter((c) => !c.reference)
      .flatMap((c) => [
        c.a.contour,
        ...(c.b ? [c.b.contour] : []),
        ...(c.axis ? [c.axis.contour] : []),
      ]),
  );
  const primitives: Primitive[] = [];

  drawing.contours.forEach((contour, index) => {
    const fixed = !used.has(index) || (options.fixedContours?.has(index) ?? false);
    if (contour.type === "circle") {
      primitives.push({
        id: centerID(index), type: "point",
        x: contour.center[0], y: contour.center[1], fixed,
      });
      primitives.push({
        id: circleID(index), type: "circle",
        c_id: centerID(index), radius: contour.radius,
      });
      return;
    }
    primitives.push({
      id: pointID(index, 0), type: "point",
      x: contour.start[0], y: contour.start[1], fixed,
    });
    contour.segments.forEach((segment, position) => {
      primitives.push({
        id: pointID(index, position + 1), type: "point",
        x: segment.end[0], y: segment.end[1], fixed,
      });
      if (segment.type === "line") {
        primitives.push({
          id: segmentID(index, position), type: "line",
          p1_id: pointID(index, position), p2_id: pointID(index, position + 1),
        });
        return;
      }
      if (segment.type === "arc") {
        const start = position === 0 ? contour.start : contour.segments[position - 1].end;
        const arc = arcFromThreePoints(start, segment.middle, segment.end);
        primitives.push({
          id: centerID(index, position), type: "point",
          x: arc.center[0], y: arc.center[1], fixed,
        });
        primitives.push({
          id: segmentID(index, position), type: "arc",
          c_id: centerID(index, position), radius: arc.radius,
          start_angle: arc.startAngle, end_angle: arc.endAngle,
          start_id: pointID(index, arc.reversed ? position + 1 : position),
          end_id: pointID(index, arc.reversed ? position : position + 1),
        });
        return;
      }
      throw new UnsupportedByPlanegcs(`a ${segment.type} segment`);
    });
  });

  const geometry = (ref: SketchEntityRef): string => {
    const contour = drawing.contours[ref.contour];
    if (!contour) throw new UnsupportedByPlanegcs("a projected reference");
    if (ref.kind === "circle") return circleID(ref.contour);
    if (ref.kind === "point") {
      if (contour.type === "circle") return centerID(ref.contour);
      if (ref.control !== undefined) throw new UnsupportedByPlanegcs("a spline control point");
      return pointID(ref.contour, ref.index ?? 0);
    }
    if (ref.kind === "line" || ref.kind === "arc") return segmentID(ref.contour, ref.index ?? 0);
    throw new UnsupportedByPlanegcs(`a ${ref.kind} reference`);
  };
  const centerOf = (ref: SketchEntityRef): string => {
    const contour = drawing.contours[ref.contour];
    if (contour?.type === "circle") return centerID(ref.contour);
    const segment = contour?.segments[ref.index ?? 0];
    if (segment?.type === "arc") return centerID(ref.contour, ref.index ?? 0);
    throw new UnsupportedByPlanegcs(`a centre for a ${ref.kind} reference`);
  };
  const endpointsOf = (ref: SketchEntityRef): [string, string] => {
    const contour = drawing.contours[ref.contour];
    const index = ref.index ?? 0;
    if (contour?.type === "circle" || contour?.segments[index]?.type !== "line")
      throw new UnsupportedByPlanegcs(`endpoints of a ${ref.kind} reference`);
    return [pointID(ref.contour, index), pointID(ref.contour, index + 1)];
  };
  const kindOf = (ref: SketchEntityRef): "point" | "line" | "arc" | "circle" => {
    const contour = drawing.contours[ref.contour];
    if (ref.kind === "point") return "point";
    if (ref.kind === "circle" || contour?.type === "circle") return "circle";
    if (ref.kind === "arc") return "arc";
    if (ref.kind === "line") return "line";
    const segment = contour?.segments[ref.index ?? 0];
    if (segment?.type === "arc") return "arc";
    if (segment?.type === "line") return "line";
    throw new UnsupportedByPlanegcs(`a ${ref.kind} reference`);
  };

  constraints.forEach((constraint, position) => {
    if (constraint.reference) return; // measurement only: no equation
    primitives.push(...mapConstraint(constraint, position, { geometry, kindOf, centerOf, endpointsOf }));
  });

  wrapper.clear_data();
  wrapper.push_primitives_and_params(primitives);
  wrapper.solve();
  if (wrapper.get_gcs_conflicting_constraints().length)
    throw new Error("Constraints conflict or cannot converge. No geometry was changed.");
  wrapper.apply_solution();

  const solved = new Map(wrapper.sketch_index.get_primitives().map((item) => [item.id, item]));
  const readPoint = (id: string): SketchPoint => {
    const item = solved.get(id);
    return [Number(item?.x), Number(item?.y)];
  };
  drawing.contours.forEach((contour, index) => {
    if (!used.has(index) || options.fixedContours?.has(index)) return;
    if (contour.type === "circle") {
      contour.center = readPoint(centerID(index));
      contour.radius = Number(solved.get(circleID(index))?.radius);
      return;
    }
    contour.start = readPoint(pointID(index, 0));
    contour.segments.forEach((segment, position) => {
      segment.end = readPoint(pointID(index, position + 1));
      if (segment.type !== "arc") return;
      // Our arcs carry a point ON the curve, so rebuild it from the solved
      // centre and the half-angle between the solved endpoints.
      const arc = solved.get(segmentID(index, position));
      const center = readPoint(centerID(index, position));
      const radius = Number(arc?.radius);
      const from = Number(arc?.start_angle), to = Number(arc?.end_angle);
      const span = (to - from + 2 * Math.PI) % (2 * Math.PI);
      const middle = from + span / 2;
      segment.middle = [
        center[0] + radius * Math.cos(middle),
        center[1] + radius * Math.sin(middle),
      ];
    });
  });
  return drawing;
}

interface Resolvers {
  geometry: (ref: SketchEntityRef) => string;
  kindOf: (ref: SketchEntityRef) => "point" | "line" | "arc" | "circle";
  centerOf: (ref: SketchEntityRef) => string;
  endpointsOf: (ref: SketchEntityRef) => [string, string];
}

function mapConstraint(
  constraint: DrawingConstraint,
  position: number,
  { geometry, kindOf, centerOf, endpointsOf }: Resolvers,
): Primitive[] {
  const id = `k:${position}`;
  const { kind, a, b, axis, value } = constraint;
  const need = (ref: SketchEntityRef | undefined, what: string) => {
    if (!ref) throw new UnsupportedByPlanegcs(`${kind} without ${what}`);
    return ref;
  };
  const number = () => {
    if (typeof value !== "number") throw new UnsupportedByPlanegcs(`${kind} without a value`);
    return value;
  };
  const one = (type: string, extra: Record<string, unknown>) => [{ id, type, ...extra }];

  switch (kind) {
    case "coincident":
      return one("p2p_coincident", { p1_id: geometry(a), p2_id: geometry(need(b, "a second point")) });
    case "concentric":
      return one("p2p_coincident", { p1_id: centerOf(a), p2_id: centerOf(need(b, "a second circle")) });
    case "horizontal":
      return b
        ? one("horizontal_pp", { p1_id: geometry(a), p2_id: geometry(b) })
        : one("horizontal_l", { l_id: geometry(a) });
    case "vertical":
      return b
        ? one("vertical_pp", { p1_id: geometry(a), p2_id: geometry(b) })
        : one("vertical_l", { l_id: geometry(a) });
    case "parallel":
      return one("parallel", { l1_id: geometry(a), l2_id: geometry(need(b, "a second line")) });
    case "perpendicular":
      return one("perpendicular_ll", { l1_id: geometry(a), l2_id: geometry(need(b, "a second line")) });
    case "equal": {
      const second = need(b, "a second entity");
      const pair = `${kindOf(a)}-${kindOf(second)}`;
      const equal: Record<string, [string, string, string]> = {
        "line-line": ["equal_length", "l1_id", "l2_id"],
        "circle-circle": ["equal_radius_cc", "c1_id", "c2_id"],
        "arc-arc": ["equal_radius_aa", "a1_id", "a2_id"],
        "circle-arc": ["equal_radius_ca", "c_id", "a_id"],
      };
      const mapped = equal[pair] ?? (pair === "arc-circle" ? equal["circle-arc"] : undefined);
      if (!mapped) throw new UnsupportedByPlanegcs(`equal between ${pair}`);
      const [type, first, last] = mapped;
      const swap = pair === "arc-circle";
      return one(type, {
        [first]: geometry(swap ? second : a),
        [last]: geometry(swap ? a : second),
      });
    }
    case "tangent": {
      const second = need(b, "a second entity");
      const pair = `${kindOf(a)}-${kindOf(second)}`;
      const tangent: Record<string, [string, string, string]> = {
        "line-circle": ["tangent_lc", "l_id", "c_id"],
        "line-arc": ["tangent_la", "l_id", "a_id"],
        "circle-circle": ["tangent_cc", "c1_id", "c2_id"],
        "arc-arc": ["tangent_aa", "a1_id", "a2_id"],
        "circle-arc": ["tangent_ca", "c_id", "a_id"],
      };
      const flipped: Record<string, string> = {
        "circle-line": "line-circle", "arc-line": "line-arc", "arc-circle": "circle-arc",
      };
      const key = tangent[pair] ? pair : flipped[pair];
      const mapped = key ? tangent[key] : undefined;
      if (!mapped) throw new UnsupportedByPlanegcs(`tangent between ${pair}`);
      const [type, first, last] = mapped;
      const swap = key !== pair;
      return one(type, {
        [first]: geometry(swap ? second : a),
        [last]: geometry(swap ? a : second),
      });
    }
    case "symmetric":
      return one("p2p_symmetric_ppl", {
        p1_id: geometry(a),
        p2_id: geometry(need(b, "a second point")),
        l_id: geometry(need(axis, "an axis")),
      });
    case "midpoint":
      return one("point_on_perp_bisector_pl", {
        p_id: geometry(a), l_id: geometry(need(b, "a line")),
      });
    case "distance":
    case "length": {
      const first = kindOf(a);
      if (!b) {
        if (first !== "line") throw new UnsupportedByPlanegcs(`${kind} on a ${first}`);
        const [from, to] = endpointsOf(a);
        return one("p2p_distance", { p1_id: from, p2_id: to, distance: number() });
      }
      const pair = `${first}-${kindOf(b)}`;
      if (pair === "point-point")
        return one("p2p_distance", { p1_id: geometry(a), p2_id: geometry(b), distance: number() });
      if (pair === "point-line")
        return one("p2l_distance", { p_id: geometry(a), l_id: geometry(b), distance: number() });
      if (pair === "line-point")
        return one("p2l_distance", { p_id: geometry(b), l_id: geometry(a), distance: number() });
      if (pair === "circle-circle")
        return one("c2cdistance", { c1_id: geometry(a), c2_id: geometry(b), dist: number() });
      throw new UnsupportedByPlanegcs(`${kind} between ${pair}`);
    }
    case "radius":
      return kindOf(a) === "arc"
        ? one("arc_radius", { a_id: geometry(a), radius: number() })
        : one("circle_radius", { c_id: geometry(a), radius: number() });
    case "diameter":
      return kindOf(a) === "arc"
        ? one("arc_diameter", { a_id: geometry(a), diameter: number() })
        : one("circle_diameter", { c_id: geometry(a), diameter: number() });
    case "angle":
      return one("l2l_angle_ll", {
        l1_id: geometry(a), l2_id: geometry(need(b, "a second line")),
        angle: (number() * Math.PI) / 180,
      });
    case "horizontal-distance":
    case "vertical-distance": {
      const axisKey = kind === "horizontal-distance" ? "x" : "y";
      if (!b) throw new UnsupportedByPlanegcs(`${kind} without a second point`);
      return [
        { id, type: "difference", p1_id: geometry(a), p2_id: geometry(b), difference: number(), param: axisKey },
      ];
    }
    case "fix":
      return []; // handled by marking the primitive fixed
    default:
      throw new UnsupportedByPlanegcs(`the "${kind}" constraint`);
  }
}

/* ---------- spike instrumentation (deleted with the spike) ---------- */

/** Records how PlaneGCS behaved on a real solve the production solver just
 *  performed. Appends one JSON line per call so separate test workers can all
 *  write to the same report. */
export function recordComparison(
  source: SketchDrawing,
  options: { fixedContours?: ReadonlySet<number> },
  expected: SketchDrawing | Error,
): void {
  const report = process.env.AETHER_SOLVER_REPORT;
  if (!report) return;
  const kinds = [...new Set((source.constraints ?? []).map((c) => c.kind))].sort();
  const entry: Record<string, unknown> = {
    kinds,
    constraints: (source.constraints ?? []).length,
    contours: source.contours.length,
  };
  try {
    const actual = solveDrawingConstraintsWithPlanegcs(source, options);
    if (expected instanceof Error) {
      entry.verdict = "planegcs_solved_what_we_rejected";
      entry.detail = expected.message;
    } else {
      const drift = maximumDrift(expected, actual);
      entry.verdict = drift <= 1e-6 ? "agreed" : "disagreed";
      entry.drift = drift;
    }
  } catch (error) {
    const failure = error as Error;
    if (failure.name === "UnsupportedByPlanegcs") {
      entry.verdict = "unsupported";
      entry.detail = failure.message;
    } else if (expected instanceof Error) {
      entry.verdict = "agreed_rejection";
    } else {
      entry.verdict = "planegcs_failed";
      entry.detail = failure.message;
    }
  }
  appendFileSync(report, `${JSON.stringify(entry)}\n`);
}

function maximumDrift(expected: SketchDrawing, actual: SketchDrawing): number {
  let worst = 0;
  const compare = (a: number, b: number) => {
    worst = Math.max(worst, Math.abs(a - b));
  };
  expected.contours.forEach((contour, index) => {
    const other = actual.contours[index];
    if (!other || contour.type !== other.type) {
      worst = Infinity;
      return;
    }
    if (contour.type === "circle" && other.type === "circle") {
      compare(contour.center[0], other.center[0]);
      compare(contour.center[1], other.center[1]);
      compare(contour.radius, other.radius);
      return;
    }
    if (contour.type === "circle" || other.type === "circle") return;
    compare(contour.start[0], other.start[0]);
    compare(contour.start[1], other.start[1]);
    contour.segments.forEach((segment, position) => {
      const peer = other.segments[position];
      if (!peer) {
        worst = Infinity;
        return;
      }
      compare(segment.end[0], peer.end[0]);
      compare(segment.end[1], peer.end[1]);
      if (segment.type === "arc" && peer.type === "arc") {
        compare(segment.middle[0], peer.middle[0]);
        compare(segment.middle[1], peer.middle[1]);
      }
    });
  });
  return worst;
}
