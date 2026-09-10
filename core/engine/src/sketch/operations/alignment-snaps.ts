import type { SketchDrawing } from "../drawing";

/** Retain exact axis alignment of newly drawn line segments. Does not move
 * geometry or infer relationships retroactively on existing segments. */
export function inferLineAlignment(
  before: SketchDrawing,
  after: SketchDrawing,
): SketchDrawing {
  const next = structuredClone(after),
    constraints = (next.constraints ??= []);
  const ids = new Set(constraints.map((c) => c.id));
  let sequence = 1;
  next.contours.forEach((path, contour) => {
    if (path.type !== "path") return;
    const previous = before.contours[contour];
    path.segments.forEach((segment, index) => {
      if (
        segment.type !== "line" ||
        (previous?.type === "path" && index < previous.segments.length)
      )
        return;
      const start = index === 0 ? path.start : path.segments[index - 1].end;
      const dx = segment.end[0] - start[0],
        dy = segment.end[1] - start[1];
      if (Math.hypot(dx, dy) < 1e-7) return;
      const kind =
        Math.abs(dy) < 1e-7
          ? "horizontal"
          : Math.abs(dx) < 1e-7
            ? "vertical"
            : undefined;
      if (
        !kind ||
        constraints.some(
          (c) =>
            c.kind === kind &&
            c.a.kind === "line" &&
            c.a.contour === contour &&
            c.a.index === index,
        )
      )
        return;
      while (ids.has(`alignment-inferred-${sequence}`)) sequence++;
      const id = `alignment-inferred-${sequence++}`;
      ids.add(id);
      constraints.push({ id, kind, a: { kind: "line", contour, index } });
    });
  });
  return next;
}
