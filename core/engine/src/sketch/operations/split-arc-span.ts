import type { SketchDrawing } from "../drawing";
import { linkSplitSpanEndpoints } from "./split-span-links";

/** Preserve angular midpoint semantics on the original arc, using an endpoint-
 * and circle-linked construction arc. Its middle point retains sweep direction. */
export function retainSplitArcSpan(
  source: SketchDrawing,
  next: SketchDrawing,
  contour: number,
  segment: number,
): void {
  const constraints = next.constraints ?? [];
  const attached = constraints.filter(
    (c) =>
      c.kind === "midpoint" &&
      c.a.contour === contour &&
      c.a.kind === "arc" &&
      c.a.index === segment,
  );
  if (!attached.length) return;
  const path = source.contours[contour];
  if (path.type !== "path" || path.segments[segment].type !== "arc")
    throw Error("Expected original arc.");
  const arc = path.segments[segment];
  const helper = next.contours.length;
  next.contours.push({
    type: "path",
    construction: true,
    start: [...(segment === 0 ? path.start : path.segments[segment - 1].end)],
    segments: [{ type: "arc", middle: [...arc.middle], end: [...arc.end] }],
  });
  for (const c of attached) c.a = { contour: helper, kind: "arc", index: 0 };
  linkSplitSpanEndpoints(constraints, helper, contour, segment);
  const used = new Set(constraints.map((c) => c.id));
  for (const kind of ["concentric", "equal"] as const) {
    const base = `split-arc-span-${contour}-${segment}-${kind}`;
    let id = base,
      suffix = 0;
    while (used.has(id)) id = `${base}-${++suffix}`;
    used.add(id);
    constraints.push({
      id,
      kind,
      a: { contour: helper, kind: "arc", index: 0 },
      b: { contour, kind: "arc", index: segment },
    });
  }
}
