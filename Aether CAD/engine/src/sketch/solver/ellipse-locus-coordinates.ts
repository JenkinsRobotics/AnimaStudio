import type { SketchDrawing, SketchPoint } from "../drawing";
import { ellipseFrame } from "../curves/parameterization";
import { resolveSegmentReference } from "./segment-reference";
import { ellipseLocusResiduals } from "./ellipse-locus";

/** A linked, all-ellipse path has one supporting conic. Solve that conic and
 * vertex angles directly, avoiding the singular endpoint/radius conversion at
 * half-ellipses. These are transient solver coordinates, never saved state. */
export function ellipseLocusCoordinates(
  drawing: SketchDrawing,
  fixed?: ReadonlySet<number>,
) {
  const covered = new Set<number>();
  const coordinates: { get: () => number; set: (value: number) => void }[] = [];
  drawing.contours.forEach((path, contour) => {
    if (
      fixed?.has(contour) ||
      path.type !== "path" ||
      path.segments.length < 2 ||
      path.segments.some((s) => s.type !== "ellipse")
    )
      return;
    const linked = new Set([0]);
    const pairs: [number, number][] = [];
    for (const c of drawing.constraints ?? []) {
      if (
        c.kind !== "ellipse-locus" ||
        c.reference ||
        c.a.contour !== contour ||
        c.b?.contour !== contour
      )
        continue;
      pairs.push([
        resolveSegmentReference(path, c.a).index!,
        resolveSegmentReference(path, c.b).index!,
      ]);
    }
    for (let changed = true; changed;) {
      changed = false;
      for (const [a, b] of pairs) {
        if (linked.has(a) === linked.has(b)) continue;
        linked.add(linked.has(a) ? b : a);
        changed = true;
      }
    }
    if (linked.size !== path.segments.length) return;
    const frames = path.segments.map((s, i) => {
      if (s.type !== "ellipse") throw Error("Expected ellipse.");
      return ellipseFrame(i ? path.segments[i - 1].end : path.start, s);
    });
    const base = frames[0];
    if (
      frames.some(
        (f) =>
          ellipseLocusResiduals(base, f).some((r) => Math.abs(r) > 1e-7) ||
          Math.abs(f.radiusX - base.radiusX) > 1e-7 ||
          Math.abs(f.radiusY - base.radiusY) > 1e-7 ||
          Math.abs(
            Math.atan2(
              Math.sin(f.rotation - base.rotation),
              Math.cos(f.rotation - base.rotation),
            ),
          ) > 1e-7,
      )
    )
      return;
    const points = [path.start, ...path.segments.map((s) => s.end)];
    const closed =
      Math.hypot(
        points[0][0] - points.at(-1)![0],
        points[0][1] - points.at(-1)![1],
      ) < 1e-7;
    const cos = Math.cos(base.rotation),
      sin = Math.sin(base.rotation);
    const angles = points.slice(0, closed ? -1 : undefined).map((p) => {
      const x = p[0] - base.center[0],
        y = p[1] - base.center[1];
      return Math.atan2(
        (-sin * x + cos * y) / base.radiusY,
        (cos * x + sin * y) / base.radiusX,
      );
    });
    const state = [
      base.center[0],
      base.center[1],
      Math.log(base.radiusX),
      Math.log(base.radiusY),
      base.rotation,
      ...angles,
    ];
    const render = () => {
      const rx = Math.exp(state[2]),
        ry = Math.exp(state[3]),
        c = Math.cos(state[4]),
        s = Math.sin(state[4]);
      const at = (a: number): SketchPoint => [
        state[0] + c * rx * Math.cos(a) - s * ry * Math.sin(a),
        state[1] + s * rx * Math.cos(a) + c * ry * Math.sin(a),
      ];
      for (let i = 0; i < points.length; i++) {
        const p = at(state[5 + (i % angles.length)]);
        points[i][0] = p[0];
        points[i][1] = p[1];
      }
      path.segments.forEach((segment, i) => {
        if (segment.type !== "ellipse") return;
        segment.radiusX = rx;
        segment.radiusY = ry;
        segment.rotationDegrees = (state[4] * 180) / Math.PI;
        const a = state[5 + i],
          b = state[5 + ((i + 1) % angles.length)];
        const tau = 2 * Math.PI;
        const travel = (((segment.sweep ? b - a : a - b) % tau) + tau) % tau;
        segment.largeArc = travel > Math.PI;
      });
    };
    covered.add(contour);
    state.forEach((_, i) =>
      coordinates.push({
        get: () => state[i],
        set: (value) => {
          state[i] = value;
          render();
        },
      }),
    );
  });
  return { covered, coordinates };
}
