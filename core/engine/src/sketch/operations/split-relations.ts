import type {
  DrawingConstraint,
  SketchEntityRef,
} from "../drawing-constraints";
/** These relations describe an arc's supporting circle, not its finite extent. */
export function preservesArcLocus(constraint: DrawingConstraint): boolean {
  return [
    "radius",
    "diameter",
    "concentric",
    "equal",
    "tangent",
    "symmetric",
  ].includes(constraint.kind);
}
/** Both split arcs retain one circle when either arc is subsequently edited. */
export function linkSplitArcs(
  constraints: DrawingConstraint[],
  contour: number,
  segment: number,
): void {
  const used = new Set(constraints.map((c) => c.id));
  const id = (kind: string) => {
    const base = `split-${contour}-${segment}-${kind}`;
    let result = base,
      suffix = 0;
    while (used.has(result)) result = `${base}-${++suffix}`;
    used.add(result);
    return result;
  };
  const a: SketchEntityRef = { contour, kind: "arc", index: segment };
  const b: SketchEntityRef = { ...a, index: segment + 1 };
  constraints.push(
    { id: id("concentric"), kind: "concentric", a, b },
    { id: id("equal"), kind: "equal", a, b },
  );
}

/** Relations that do not depend on a line segment's original finite extent. */
export function preservesLineLocus(constraint: DrawingConstraint): boolean {
  return [
    "horizontal",
    "vertical",
    "symmetric",
    "parallel",
    "perpendicular",
    "angle",
    "tangent",
    "coincident",
    "length",
    "distance",
  ].includes(constraint.kind);
}
/** Shared endpoint plus parallelism retains collinearity; length spans original outer endpoints. */
export function linkSplitLines(
  constraints: DrawingConstraint[],
  contour: number,
  segment: number,
): void {
  for (const constraint of constraints) {
    if (
      constraint.kind === "length" &&
      constraint.a.contour === contour &&
      constraint.a.kind === "line" &&
      constraint.a.index === segment
    ) {
      constraint.kind = "distance";
      constraint.a = { contour, kind: "point", index: segment };
      constraint.b = { contour, kind: "point", index: segment + 2 };
    }
  }
  const base = `split-${contour}-${segment}-parallel`;
  let id = base,
    suffix = 0;
  const used = new Set(constraints.map((c) => c.id));
  while (used.has(id)) id = `${base}-${++suffix}`;
  constraints.push({
    id,
    kind: "parallel",
    a: { contour, kind: "line", index: segment },
    b: { contour, kind: "line", index: segment + 1 },
  });
}
