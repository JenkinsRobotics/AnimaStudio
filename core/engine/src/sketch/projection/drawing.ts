import { collapsedConicPoints, collapsedInterval } from "./collapsed-conic";
import { solveDrawingConstraints } from "../drawing-constraints";
import {
  validateSketchDrawing,
  sameSketchPoint,
  contourClosed,
  type SketchDrawing,
  type SketchFrame,
  type SketchContour,
  type SketchSegment,
} from "../drawing";
import { ellipseFrame } from "../curves/parameterization";
import { sketchArcGeometry } from "../arc-geometry";
import { sketchFrameMap, type SketchFrameMap } from "./frame-map";
import { projectedEllipse, projectedConicSegment } from "./conic";
/** Exact geometry projection. Constraint intent belongs to the source sketch;
 * a future document reference owns association, rather than copying dimensions
 * which generally cease to be valid after an oblique projection. */
export function projectSketchDrawing(
  source: SketchDrawing,
  sourceFrame: SketchFrame,
  targetFrame: SketchFrame,
): SketchDrawing {
  return mapSketchDrawing(
    source,
    sketchFrameMap(sourceFrame, targetFrame),
    1e-14,
  );
}

/** Shared exact affine geometry mapping, including nonuniform import transforms. */
export function mapSketchDrawing(
  source: SketchDrawing,
  map: SketchFrameMap,
  collapseTolerance = 0,
): SketchDrawing {
  const drawing = solveDrawingConstraints(source);
  if (
    !Number.isFinite(map.determinant) ||
    !Number.isFinite(collapseTolerance) ||
    collapseTolerance < 0
  )
    throw Error("Invalid affine mapping tolerance or determinant.");
  const collapsed =
    map.determinant === 0 || Math.abs(map.determinant) < collapseTolerance;
  const contours = drawing.contours.map((c): SketchContour => {
    const flags = {
      ...(c.sourceLayer !== undefined ? { sourceLayer: c.sourceLayer } : {}),
      ...(c.id !== undefined ? { id: c.id } : {}),
      ...(c.hole !== undefined ? { hole: c.hole } : {}),
      ...(c.construction !== undefined ? { construction: c.construction } : {}),
    };
    if (c.type === "circle") {
      if (collapsed) {
        const [start, end] = collapsedInterval(
          collapsedConicPoints(map, {
            center: c.center,
            radiusX: c.radius,
            radiusY: c.radius,
            rotation: 0,
            startAngle: 0,
            sweep: 2 * Math.PI,
          }),
        );
        return {
          type: "path",
          start,
          segments: sameSketchPoint(start, end) ? [] : [{ type: "line", end }],
          ...flags,
          hole: false,
        };
      }
      const axes = projectedEllipse(map, c.radius, c.radius, 0);
      if (
        Math.abs(axes.radiusX - axes.radiusY) <
        1e-10 * Math.max(1, axes.radiusX)
      )
        return {
          type: "circle",
          center: map.point(c.center),
          radius: axes.radiusX,
          ...flags,
        };
      const start: [number, number] = [c.center[0] + c.radius, c.center[1]],
        opposite: [number, number] = [c.center[0] - c.radius, c.center[1]];
      return {
        type: "path",
        start: map.point(start),
        segments: [
          projectedConicSegment(map, axes, opposite, Math.PI),
          projectedConicSegment(map, axes, start, Math.PI),
        ],
        ...flags,
      };
    }
    let previous = c.start;
    let segments = c.segments.flatMap((segment): SketchSegment[] => {
      const start = previous;
      previous = segment.end;
      if (segment.type === "line")
        return collapsed &&
          sameSketchPoint(map.point(start), map.point(segment.end))
          ? []
          : [{ type: "line", end: map.point(segment.end) }];
      if (segment.type === "bezier")
        return [
          {
            type: "bezier",
            end: map.point(segment.end),
            controls: [
              map.point(segment.controls[0]),
              map.point(segment.controls[1]),
            ],
          },
        ];
      if (collapsed) {
        const frame =
          segment.type === "arc"
            ? (() => {
                const a = sketchArcGeometry(start, segment.middle, segment.end);
                return {
                  ...a,
                  radiusX: a.radius,
                  radiusY: a.radius,
                  rotation: 0,
                };
              })()
            : ellipseFrame(start, segment);
        const points = collapsedConicPoints(map, frame);
        return points
          .slice(1)
          .flatMap((end, i) =>
            sameSketchPoint(points[i], end)
              ? []
              : [{ type: "line" as const, end }],
          );
      }
      if (segment.type === "arc") {
        const arc = sketchArcGeometry(start, segment.middle, segment.end);
        return [
          projectedConicSegment(
            map,
            projectedEllipse(map, arc.radius, arc.radius, 0),
            segment.end,
            arc.sweep,
          ),
        ];
      }
      const ellipse = ellipseFrame(start, segment);
      return [
        projectedConicSegment(
          map,
          projectedEllipse(
            map,
            ellipse.radiusX,
            ellipse.radiusY,
            ellipse.rotation,
          ),
          segment.end,
          ellipse.sweep,
        ),
      ];
    });
    if (!collapsed)
      segments.forEach((segment, index) => {
        if (c.segments[index].id !== undefined)
          segment.id = c.segments[index].id;
        if (c.segments[index].endVertexId !== undefined)
          segment.endVertexId = c.segments[index].endVertexId;
      });
    let start = map.point(c.start);
    if (
      collapsed &&
      contourClosed(c) &&
      c.segments.every((s) => s.type !== "bezier")
    ) {
      const interval = collapsedInterval([
        start,
        ...segments.map((s) => s.end),
      ]);
      start = interval[0];
      segments = sameSketchPoint(...interval)
        ? []
        : [{ type: "line", end: interval[1] }];
    }
    return {
      type: "path",
      start,
      segments,
      ...(!collapsed && c.startVertexId !== undefined
        ? { startVertexId: c.startVertexId }
        : {}),
      ...flags,
      ...(collapsed ? { hole: false } : {}),
    };
  });
  const result: SketchDrawing = { type: "drawing", contours };
  validateSketchDrawing(result);
  return result;
}
