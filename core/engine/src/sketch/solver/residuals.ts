import { ellipseLocusResiduals } from "./ellipse-locus";
import { angularSpanDistance } from "../curves/angular-span";
import { circleContinuityResiduals } from "./circle-continuity";
import { patternSourceContour } from "./pattern-source";
import { validatePatternSuppression } from "./pattern-suppression";
import { patternRelationTransform } from "../pattern-groups";
import { mirrorTransform } from "../curves/reflection";
import { patternResiduals } from "./pattern";
import { lineLineMeasurement } from "./line-line-measurement";
import { splineShapeResiduals } from "./spline-shape";
import {
  ellipseQuadrant,
  pointOnEllipse,
  quadrantFrame,
  quadrantSpan,
} from "./ellipse-contact";
import { ellipseShapeResiduals } from "./ellipse-shape";
import { symmetricResiduals } from "./symmetric";
import { slotResiduals } from "./slot";
import { offsetResiduals } from "./offset";
import { normalResiduals } from "./normal";
import { dimensionValue } from "./dimension-links";
import { measuredDimensionValue } from "./measured-dimension";
import { pointLineMeasurement } from "./point-line-measurement";
import { curveContinuityResiduals } from "./curve-continuity";
import type { SketchDrawing, SketchPoint } from "../drawing";
import type { DrawingConstraint } from "./types";
import { resolve } from "./entities";
export function constraintResiduals(
  d: SketchDrawing,
  c: DrawingConstraint,
): number[] {
  if (c.reference !== undefined && typeof c.reference !== "boolean")
    throw Error("Invalid reference dimension flag.");
  if (c.reference) {
    if (!Number.isFinite(measuredDimensionValue(d, c)))
      throw Error("Invalid reference measurement.");
    return [];
  }
  if (c.kind === "pattern") {
    const source = patternSourceContour(d, c.a);
    if (c.patternSuppression !== undefined) {
      validatePatternSuppression(d, c);
      return [];
    }
    const target = c.b ? resolve(d, c.b).contour : undefined;
    if (c.axis) {
      if (c.transform)
        throw Error("A live mirror axis cannot also have a fixed transform.");
      const axis = resolve(d, c.axis).line;
      if (!axis) throw Error("Select a line.");
      return patternResiduals(
        source,
        target,
        mirrorTransform(axis[0], axis[1]),
      );
    }
    return patternResiduals(source, target, patternRelationTransform(d, c));
  }
  const a = resolve(d, c.a),
    b = c.b ? resolve(d, c.b) : undefined;
  const point = (e: ReturnType<typeof resolve> | undefined) => {
    if (!e?.point) throw new Error("Select a point.");
    return e.point;
  };
  const line = (e: ReturnType<typeof resolve> | undefined) => {
    if (!e?.line) throw new Error("Select a line.");
    return e.line;
  };
  const circle = (e: ReturnType<typeof resolve> | undefined) => {
    if (!e?.circle) throw new Error("Select a circle.");
    return e.circle;
  };
  const delta = (l: [SketchPoint, SketchPoint]): SketchPoint => [
    l[1][0] - l[0][0],
    l[1][1] - l[0][1],
  ];
  const length = (l: [SketchPoint, SketchPoint]) => Math.hypot(...delta(l));
  const value = () => dimensionValue(d, c);
  const positive = () => {
    const n = value();
    if (n <= 0) throw new Error("Dimension must be positive.");
    return n;
  };
  switch (c.kind) {
    case "horizontal":
      return a.point && b?.point
        ? [a.point[1] - b.point[1]]
        : [delta(line(a))[1]];
    case "vertical":
      return a.point && b?.point
        ? [a.point[0] - b.point[0]]
        : [delta(line(a))[0]];
    case "coincident": {
      if (a.point && b?.point)
        return [a.point[0] - b.point[0], a.point[1] - b.point[1]];
      const p = a.point ?? b?.point,
        other = a.point ? b : a;
      if (!p || !other)
        throw new Error("Select a point and a point, line, circle or arc.");
      if (other.curve)
        return [p[0] - other.curve.point[0], p[1] - other.curve.point[1]];
      if (other.ellipse) return [pointOnEllipse(other.ellipse, p)];
      if (other.circle)
        return [
          Math.hypot(
            p[0] - other.circle.center[0],
            p[1] - other.circle.center[1],
          ) - other.circle.radius,
        ];
      const l = line(other),
        u = delta(l);
      return [
        (u[0] * (p[1] - l[0][1]) - u[1] * (p[0] - l[0][0])) /
          Math.max(length(l), 1e-10),
      ];
    }
    case "fix": {
      const p = point(a);
      if (!c.point || c.point.length !== 2 || !c.point.every(Number.isFinite))
        throw new Error("Fix needs a finite point.");
      return [p[0] - c.point[0], p[1] - c.point[1]];
    }
    case "concentric": {
      const p = a.point ?? a.ellipse?.center ?? circle(a).center,
        q = b?.point ?? b?.ellipse?.center ?? circle(b).center;
      return [p[0] - q[0], p[1] - q[1]];
    }
    case "length":
      return [length(line(a)) - positive()];
    case "radius":
      return [circle(a).radius - positive()];
    case "diameter":
      return [2 * circle(a).radius - positive()];
    case "distance": {
      if (a.line && b?.line) {
        const m = lineLineMeasurement(a.line, b.line);
        return [m.parallelError, m.distance - positive()];
      }
      if (a.point && b?.line)
        return [pointLineMeasurement(a.point, b.line).distance - positive()];
      if (a.line && b?.point)
        return [pointLineMeasurement(b.point, a.line).distance - positive()];
      const p = point(a),
        q = point(b);
      return [Math.hypot(p[0] - q[0], p[1] - q[1]) - positive()];
    }
    case "horizontal-distance":
    case "vertical-distance": {
      const axis = c.kind === "horizontal-distance" ? 0 : 1;
      return [point(b)[axis] - point(a)[axis] - value()];
    }
    case "equal":
      return a.circle && b?.circle
        ? [a.circle.radius - b.circle.radius]
        : [length(line(a)) - length(line(b))];
    case "midpoint": {
      const p = point(b);
      if (a.arc) return [p[0] - a.arc.midpoint[0], p[1] - a.arc.midpoint[1]];
      const l = line(a);
      return [p[0] - (l[0][0] + l[1][0]) / 2, p[1] - (l[0][1] + l[1][1]) / 2];
    }
    case "parallel":
    case "perpendicular":
    case "angle": {
      const u = delta(line(a)),
        v = delta(line(b)),
        scale = Math.max(Math.hypot(...u) * Math.hypot(...v), 1e-10);
      if (c.kind === "parallel") return [(u[0] * v[1] - u[1] * v[0]) / scale];
      if (c.kind === "perpendicular")
        return [(u[0] * v[0] + u[1] * v[1]) / scale];
      const angle =
        Math.atan2(u[0] * v[1] - u[1] * v[0], u[0] * v[0] + u[1] * v[1]) -
        (value() * Math.PI) / 180;
      return [Math.atan2(Math.sin(angle), Math.cos(angle))];
    }
    case "quadrant": {
      const p = a.point ?? b?.point,
        e = quadrantFrame(a) ?? (b ? quadrantFrame(b) : undefined);
      if (!p || !e) throw Error("Select a point and a circle, arc or ellipse.");
      const q = ellipseQuadrant(e, c.quadrant!),
        span = quadrantSpan(a) ?? (b ? quadrantSpan(b) : undefined);
      return [
        p[0] - q[0],
        p[1] - q[1],
        ...(span
          ? [
              Math.min(e.radiusX, e.radiusY) *
                angularSpanDistance(
                  span.startAngle,
                  span.sweep,
                  (c.quadrant! * Math.PI) / 2,
                ),
            ]
          : []),
      ];
    }
    case "spline-shape":
      if (!a.contour) throw Error("Select the whole fit spline contour.");
      return splineShapeResiduals(a.contour, c.splineSpanIntervals);
    case "ellipse-locus":
      if (!a.ellipse || !b?.ellipse) throw Error("Select two elliptical arcs.");
      return ellipseLocusResiduals(a.ellipse, b.ellipse);
    case "ellipse-shape":
      if (!a.contour) throw Error("Select the whole ellipse contour.");
      return ellipseShapeResiduals(a.contour);
    case "symmetric":
      if (
        c.splineReversed !== undefined &&
        (typeof c.splineReversed !== "boolean" || !a.contour || !b?.contour)
      )
        throw Error("Spline direction applies only to whole spline symmetry.");
      return symmetricResiduals(
        a,
        b,
        c.axis ? resolve(d, c.axis) : undefined,
        c.splineReversed,
      );
    case "slot":
      return slotResiduals(d, c);
    case "offset":
      return offsetResiduals(a, b, value());
    case "normal":
      return normalResiduals(a, b);
    case "curvature": {
      if (a.circle && b?.curve)
        return circleContinuityResiduals(a.circle, b.curve, true);
      if (a.curve && b?.circle)
        return circleContinuityResiduals(b.circle, a.curve, true);
      if (!a.curve || !b?.curve)
        throw new Error(
          "Select two finite curve contacts for curvature continuity.",
        );
      return curveContinuityResiduals(a.curve, b.curve, true);
    }
    case "tangent": {
      if (a.circle && b?.curve)
        return circleContinuityResiduals(a.circle, b.curve);
      if (a.curve && b?.circle)
        return circleContinuityResiduals(b.circle, a.curve);
      if (a.curve && b?.curve) {
        return curveContinuityResiduals(a.curve, b.curve);
      }
      if (a.circle && b?.circle) {
        const distance = Math.hypot(
          a.circle.center[0] - b.circle.center[0],
          a.circle.center[1] - b.circle.center[1],
        );
        return [
          distance -
            (c.tangentMode === "internal"
              ? Math.abs(a.circle.radius - b.circle.radius)
              : a.circle.radius + b.circle.radius),
        ];
      }
      const p = circle(a.circle ? a : b),
        l = line(a.line ? a : b),
        u = delta(l),
        len = Math.max(length(l), 1e-10);
      return [
        Math.abs(
          u[0] * (p.center[1] - l[0][1]) - u[1] * (p.center[0] - l[0][0]),
        ) /
          len -
          p.radius,
      ];
    }
    default:
      throw new Error("Unsupported sketch constraint.");
  }
}
