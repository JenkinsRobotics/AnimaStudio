import type { DrawingConstraint } from "../solver/types";

/** Link a construction span to the outer vertices of two split child edges. */
export function linkSplitSpanEndpoints(
  constraints: DrawingConstraint[],
  helper: number,
  contour: number,
  segment: number,
): void {
  const used = new Set(constraints.map((c) => c.id));
  for (const [vertex, sourceVertex] of [
    [0, segment],
    [1, segment + 2],
  ]) {
    const base = `split-span-${contour}-${segment}-${vertex}`;
    let id = base,
      suffix = 0;
    while (used.has(id)) id = `${base}-${++suffix}`;
    used.add(id);
    constraints.push({
      id,
      kind: "coincident",
      a: { contour: helper, kind: "point", index: vertex },
      b: { contour, kind: "point", index: sourceVertex },
    });
  }
}
