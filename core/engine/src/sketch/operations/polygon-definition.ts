import { contourClosed, sameSketchPoint, type SketchDrawing } from "../drawing";
/** Recognize the ordinary constraint recipe emitted by constrainSketchPolygon.
 * Side count is derived from geometry, never stored as a second truth. */
export function sketchPolygonDefinition(d: SketchDrawing, contour: number) {
  const path = d.contours[contour];
  if (
    path?.type !== "path" ||
    !contourClosed(path) ||
    path.segments.length < 3 ||
    path.segments.some((s) => s.type !== "line")
  )
    throw Error("Select a constrained regular polygon.");
  const cs = d.constraints ?? [],
    n = path.segments.length;
  const candidates = d.contours.flatMap((c, outer) => {
    if (c.type !== "circle" || !c.construction) return [];
    const x = path.start[0] - c.center[0],
      y = path.start[1] - c.center[1],
      q = path.segments[0].end;
    const orientation = Math.sign(
      x * (q[1] - c.center[1]) - y * (q[0] - c.center[0]),
    );
    if (!orientation) return [];
    for (let i = 0; i < n; i++) {
      const angle = (orientation * i * 2 * Math.PI) / n,
        co = Math.cos(angle),
        si = Math.sin(angle);
      const p = i === 0 ? path.start : path.segments[i - 1].end;
      if (
        !sameSketchPoint(p, [
          c.center[0] + co * x - si * y,
          c.center[1] + si * x + co * y,
        ])
      )
        return [];
    }
    const owned = [];
    for (let i = 0; i < n; i++) {
      const hit = cs.filter(
        (c) =>
          c.kind === "coincident" &&
          c.a.kind === "point" &&
          c.a.contour === contour &&
          c.a.index === i &&
          c.b?.kind === "circle" &&
          c.b.contour === outer,
      );
      if (hit.length !== 1) return [];
      owned.push(hit[0]);
      if (i) {
        const equal = cs.filter(
          (c) =>
            c.kind === "equal" &&
            c.a.kind === "line" &&
            c.a.contour === contour &&
            c.a.index === 0 &&
            c.b?.kind === "line" &&
            c.b.contour === contour &&
            c.b.index === i,
        );
        if (equal.length !== 1) return [];
        owned.push(equal[0]);
      }
    }
    const inner = cs
      .filter(
        (c) =>
          c.kind === "concentric" &&
          c.a.kind === "circle" &&
          c.a.contour === outer &&
          c.b?.kind === "circle" &&
          d.contours[c.b.contour]?.construction,
      )
      .flatMap((c) => {
        const tangent = cs.filter(
          (t) =>
            t.kind === "tangent" &&
            t.a.kind === "line" &&
            t.a.contour === contour &&
            t.a.index === 0 &&
            t.b?.kind === "circle" &&
            t.b.contour === c.b!.contour,
        );
        return tangent.length === 1
          ? [{ index: c.b!.contour, constraints: [c, tangent[0]] }]
          : [];
      });
    if (inner.length > 1)
      throw Error("Polygon sizing references are ambiguous.");
    return [
      {
        outer,
        inner: inner[0]?.index,
        owned: [...owned, ...(inner[0]?.constraints ?? [])],
        sides: n,
        orientation,
      },
    ];
  });
  if (candidates.length !== 1)
    throw Error("Select a polygon with intact regularity constraints.");
  return candidates[0];
}
