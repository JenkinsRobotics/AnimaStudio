import type { SketchDrawing } from "../drawing";
import type { SketchEntityRef } from "../drawing-constraints";
/** Reuse original circle relationships after replacing its contour with an arc path. */
export function remapCircleReferences(
  source: SketchDrawing,
  next: SketchDrawing,
  index: number,
): void {
  const circle = source.contours[index];
  if (circle.type !== "circle") throw new Error("Expected original circle.");
  const centerReferenced =
    source.constraints?.some((c) =>
      [c.a, ...(c.b ? [c.b] : [])].some(
        (r) => r.contour === index && r.kind === "point",
      ),
    ) ?? false;
  const centerIndex = next.contours.length;
  if (centerReferenced)
    next.contours.push({
      type: "path",
      start: [...circle.center],
      segments: [],
      construction: true,
    });
  const map = (r: SketchEntityRef): SketchEntityRef =>
    r.contour !== index
      ? r
      : r.kind === "circle"
        ? { contour: index, kind: "arc", index: 0 }
        : r.kind === "point"
          ? { contour: centerIndex, kind: "point", index: 0 }
          : r;
  next.constraints = (source.constraints ?? []).map((c) => ({
    ...c,
    a: map(c.a),
    ...(c.b ? { b: map(c.b) } : {}),
    ...(c.axis ? { axis: map(c.axis) } : {}),
  }));
  if (centerReferenced) {
    const base = `circle-${index}-center`,
      used = new Set(next.constraints.map((c) => c.id));
    let id = base,
      suffix = 0;
    while (used.has(id)) id = `${base}-${++suffix}`;
    next.constraints.push({
      id,
      kind: "concentric",
      a: { contour: index, kind: "arc", index: 0 },
      b: { contour: centerIndex, kind: "point", index: 0 },
    });
  }
}
