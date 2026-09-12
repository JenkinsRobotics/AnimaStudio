import { solveDrawingConstraints } from "../sketch/drawing-constraints";
import type { SketchDrawing } from "../sketch/drawing";
import type { SketchEntityRef } from "../sketch/solver/types";

/** Resolve external IDs into temporary solver indices. Projected contours are
 * constant inputs, never solver variables or persisted copies. */
export function solveProjectedConstraints(
  authored: SketchDrawing,
  projected: SketchDrawing,
): SketchDrawing {
  const next = structuredClone(authored),
    count = next.contours.length;
  const fixed = new Set<number>(),
    mapped = new Map<string, number>();
  const map = (ref: SketchEntityRef): SketchEntityRef => {
    const id = ref.projectedContourId;
    if (id === undefined) return ref;
    if (typeof id !== "string" || !id.trim() || ref.contour !== -1)
      throw Error("Invalid projected constraint reference.");
    let index = mapped.get(id);
    if (index === undefined) {
      const matches = projected.contours.filter((c) => c.id === id);
      if (matches.length !== 1)
        throw Error(`Broken projected constraint reference: ${id}.`);
      index = next.contours.length;
      next.contours.push(structuredClone(matches[0]));
      fixed.add(index);
      mapped.set(id, index);
    }
    const { projectedContourId: _, ...local } = ref;
    return { ...local, contour: index };
  };
  next.constraints = next.constraints?.map((c) => ({
    ...c,
    a: map(c.a),
    ...(c.b ? { b: map(c.b) } : {}),
    ...(c.axis ? { axis: map(c.axis) } : {}),
  }));
  const solved = solveDrawingConstraints(next, { fixedContours: fixed });
  const restore = (
    original: SketchEntityRef,
    updated: SketchEntityRef,
  ): SketchEntityRef => ({
    ...structuredClone(original),
    ...(original.kind === "curve" && original.sliding
      ? { parameter: updated.parameter }
      : {}),
  });
  const constraints = authored.constraints?.map((c, i) => ({
    ...structuredClone(c),
    a: restore(c.a, solved.constraints![i].a),
    ...(c.b ? { b: restore(c.b, solved.constraints![i].b!) } : {}),
    ...(c.axis ? { axis: restore(c.axis, solved.constraints![i].axis!) } : {}),
  }));
  return {
    ...structuredClone(authored),
    contours: solved.contours.slice(0, count),
    constraints,
  };
}
