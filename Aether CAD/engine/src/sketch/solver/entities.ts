import { ellipseFrame } from "../curves/parameterization";
import { scaledControlPoint } from "./control-point";
import { referencedContour } from "./projected-context";
import {
  identifySegmentReference,
  resolveSegmentReference,
} from "./segment-reference";
import { curveJet } from "../curves/derivatives";
import { sketchArcGeometry } from "../arc-geometry";
import type { SketchDrawing, SketchPoint } from "../drawing";
import type { SketchEntityRef } from "./types";
export function sketchEntities(
  d: SketchDrawing,
): { ref: SketchEntityRef; label: string }[] {
  const local = d.contours.flatMap<{ ref: SketchEntityRef; label: string }>(
    (c, i) =>
      c.type === "circle"
        ? [
            {
              ref: { contour: i, kind: "circle" as const },
              label: `${i + 1}: Circle`,
            },
            {
              ref: { contour: i, kind: "point" as const, index: 0 },
              label: `${i + 1}: Center`,
            },
          ]
        : [
            ...(c.segments.length &&
            c.segments.every((s) => s.type === "bezier")
              ? [
                  {
                    ref: { contour: i, kind: "contour" as const },
                    label: `${i + 1}: Fit spline contour`,
                  },
                ]
              : []),
            ...(c.segments.length === 2 &&
            c.segments.every((s) => s.type === "ellipse")
              ? [
                  {
                    ref: { contour: i, kind: "contour" as const },
                    label: `${i + 1}: Full ellipse`,
                  },
                ]
              : []),
            {
              ref: { contour: i, kind: "point" as const, index: 0 },
              label: `${i + 1}: Start`,
            },
            ...c.segments.flatMap((s, j) => [
              ...([0, 1] as const).map((parameter) => ({
                ref: {
                  contour: i,
                  kind: "curve" as const,
                  index: j,
                  parameter,
                },
                label: `${i + 1}: Segment ${j + 1} ${parameter === 0 ? "start" : "end"} contact`,
              })),
              ...(s.type === "ellipse"
                ? [
                    {
                      ref: { contour: i, kind: "ellipse" as const, index: j },
                      label: `${i + 1}: Ellipse ${j + 1}`,
                    },
                  ]
                : []),
              ...(s.type === "arc"
                ? [
                    {
                      ref: { contour: i, kind: "arc" as const, index: j },
                      label: `${i + 1}: Arc ${j + 1}`,
                    },
                  ]
                : []),
              ...(s.type === "bezier"
                ? ([0, 1] as const).map((control) => ({
                    ref: {
                      contour: i,
                      kind: "point" as const,
                      index: j,
                      control,
                    },
                    label: `${i + 1}: Curve ${j + 1} control ${control + 1}`,
                  }))
                : []),
              {
                ref: { contour: i, kind: "point" as const, index: j + 1 },
                label: `${i + 1}: Point ${j + 1}`,
              },
              ...(s.type === "line"
                ? [
                    {
                      ref: { contour: i, kind: "line" as const, index: j },
                      label: `${i + 1}: Line ${j + 1}`,
                    },
                  ]
                : []),
            ]),
          ],
  );
  return local;
}
export function projectedSketchEntities(
  d: SketchDrawing,
): { ref: SketchEntityRef; label: string }[] {
  const projected = (d.projectionContext ?? []).flatMap((c) =>
    c.id === undefined
      ? []
      : sketchEntities({ type: "drawing", contours: [c] }).map((e) => ({
          ref: {
            ...identifySegmentReference(c, e.ref),
            contour: -1,
            projectedContourId: c.id,
          },
          label: `Projected ${c.id}: ${e.label}`,
        })),
  );
  return projected;
}
export function sketchEntityPoint(
  d: SketchDrawing,
  r: SketchEntityRef,
): SketchPoint | undefined {
  const c = referencedContour(d, r);
  r = resolveSegmentReference(c, r);
  if (c?.type === "circle") return c.center;
  if (c?.type !== "path" || r.kind !== "point") return;
  if (r.control !== undefined) {
    return scaledControlPoint(c, r);
  }
  return r.index === 0 ? c.start : c.segments[r.index! - 1]?.end;
}
export function resolve(d: SketchDrawing, r: SketchEntityRef) {
  const c = referencedContour(d, r);
  r = resolveSegmentReference(c, r);
  if (!c) throw new Error("Constraint references missing geometry.");
  if (r.kind === "contour") return { contour: c };
  if (r.kind === "curve" && c.type === "path") {
    const segment = c.segments[r.index!],
      parameter = r.parameter;
    if (
      !Number.isInteger(r.index) ||
      !segment ||
      parameter === undefined ||
      !Number.isFinite(parameter) ||
      parameter < 0 ||
      parameter > 1
    )
      throw new Error(
        "Curve contact requires a valid segment and parameter between zero and one.",
      );
    const curve = curveJet({
      start: r.index === 0 ? c.start : c.segments[r.index! - 1].end,
      segment,
    })(parameter);
    return { curve };
  }
  if (r.kind === "ellipse" && c.type === "path") {
    const segment = c.segments[r.index!];
    if (
      segment?.type === "ellipse" &&
      d.constraints?.some(
        (q) => q.kind === "ellipse-shape" && q.a.contour === r.contour,
      )
    ) {
      const first = c.segments[0];
      if (first.type !== "ellipse") throw Error("Invalid full ellipse.");
      return {
        ellipse: {
          center: [
            (c.start[0] + first.end[0]) / 2,
            (c.start[1] + first.end[1]) / 2,
          ] as SketchPoint,
          radiusX: first.radiusX,
          radiusY: first.radiusY,
          rotation: (first.rotationDegrees * Math.PI) / 180,
        },
      };
    }
    if (segment?.type === "ellipse")
      return {
        ellipse: ellipseFrame(
          r.index === 0 ? c.start : c.segments[r.index! - 1].end,
          segment,
        ),
      };
  }
  if (r.kind === "arc" && c.type === "path") {
    const segment = c.segments[r.index!];
    if (segment?.type === "arc") {
      const arc = sketchArcGeometry(
        r.index === 0 ? c.start : c.segments[r.index! - 1].end,
        segment.middle,
        segment.end,
      );
      return { circle: arc, arc };
    }
  }
  if (r.kind === "circle" && c.type === "circle") return { circle: c };
  if (r.kind === "point") {
    if (r.control !== undefined) {
      const point = sketchEntityPoint(d, r);
      if (point) return { point };
      throw new Error("Missing curve control point.");
    }
    if (c.type === "circle" && r.index === 0) return { point: c.center };
    if (
      c.type === "path" &&
      Number.isInteger(r.index) &&
      r.index! >= 0 &&
      r.index! <= c.segments.length
    )
      return { point: r.index === 0 ? c.start : c.segments[r.index! - 1].end };
  }
  if (
    r.kind === "line" &&
    c.type === "path" &&
    c.segments[r.index!]?.type === "line"
  )
    return {
      line: [
        r.index === 0 ? c.start : c.segments[r.index! - 1].end,
        c.segments[r.index!].end,
      ] as [SketchPoint, SketchPoint],
    };
  throw new Error("Constraint requires a compatible point, line or circle.");
}
