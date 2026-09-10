import {
  pickCurve,
  sketchArcGeometry,
  sketchEntities,
  sketchEntityPoint,
  type SketchPoint,
  type SketchDrawing,
} from "@aether/core/sketch";
export function pickSketchEntity(drawing: SketchDrawing, p: SketchPoint) {
  const distance = (a: SketchPoint) => Math.hypot(a[0] - p[0], a[1] - p[1]);
  const candidates = sketchEntities(drawing)
    .map((entity) => {
      const c = drawing.contours[entity.ref.contour],
        r = entity.ref;
      let d = Infinity;
      if (c.type === "circle")
        d =
          r.kind === "point"
            ? distance(c.center)
            : Math.abs(distance(c.center) - c.radius);
      else if (r.kind === "point") {
        const point = sketchEntityPoint(drawing, r);
        if (point) d = distance(point);
      } else if (r.kind === "arc" && c.type === "path") {
        const segment = c.segments[r.index!];
        if (segment.type === "arc") {
          const start = r.index === 0 ? c.start : c.segments[r.index! - 1].end,
            arc = sketchArcGeometry(start, segment.middle, segment.end);
          const angle = Math.atan2(p[1] - arc.center[1], p[0] - arc.center[0]),
            tau = 2 * Math.PI;
          const delta =
            arc.sweep >= 0
              ? (angle - arc.startAngle + tau) % tau
              : (arc.startAngle - angle + tau) % tau;
          d =
            delta <= Math.abs(arc.sweep)
              ? Math.abs(distance(arc.center) - arc.radius)
              : Math.min(distance(start), distance(segment.end));
        }
      } else if (r.kind === "line") {
        const a = r.index === 0 ? c.start : c.segments[r.index! - 1].end,
          b = c.segments[r.index!].end;
        const dx = b[0] - a[0],
          dy = b[1] - a[1],
          t = Math.max(
            0,
            Math.min(
              1,
              ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / (dx * dx + dy * dy),
            ),
          );
        d = distance([a[0] + t * dx, a[1] + t * dy]);
      }
      return { ...entity, d };
    })
    .sort((a, b) => {
      // A construction point on a curve must remain pickable even when the
      // curve precedes it in document order. Ignore numerical distance noise.
      if (Math.abs(a.d - b.d) < 1e-7)
        return Number(b.ref.kind === "point") - Number(a.ref.kind === "point");
      return a.d - b.d;
    });
  try {
    const curve = pickCurve(drawing, p, Infinity),
      contour = drawing.contours[curve.contour];
    if (
      !curve.circle &&
      !curve.point &&
      contour.type === "path" &&
      ["bezier", "ellipse"].includes(contour.segments[curve.segment].type) &&
      (!candidates[0] || curve.distance < candidates[0].d - 1e-7)
    )
      return {
        ref: {
          contour: curve.contour,
          kind: "curve" as const,
          index: curve.segment,
          parameter: curve.parameter,
        },
        label: `${curve.contour + 1}: Segment ${curve.segment + 1}`,
        d: curve.distance,
      };
  } catch {
    /* Empty sketches have no selectable curves. */
  }
  return candidates[0];
}
