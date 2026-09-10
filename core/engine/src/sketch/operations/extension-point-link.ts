import { extensionCurveBoundary } from "./extension-boundary";
import { validateSketchDrawing, type SketchDrawing } from "../drawing";
import { sketchEntityPoint } from "../solver/entities";
import type { SketchEntityRef } from "../solver/types";
/** Keep a successful extension attached to its reached point or curve boundary. */
export function linkExtendedEndpoint(
  source: SketchDrawing,
  endpoint: SketchEntityRef,
): SketchDrawing {
  const next = structuredClone(source),
    p = sketchEntityPoint(next, endpoint);
  if (!p) throw Error("Select the extended endpoint.");
  const index = next.contours.findIndex(
    (c, i) =>
      i !== endpoint.contour &&
      c.type === "path" &&
      !c.segments.length &&
      Math.hypot(c.start[0] - p[0], c.start[1] - p[1]) < 1e-7,
  );
  const target: SketchEntityRef | undefined =
    index >= 0
      ? { kind: "point", contour: index, index: 0 }
      : extensionCurveBoundary(next, endpoint, p);
  if (!target) return next;
  const same = (a: SketchEntityRef | undefined, b: SketchEntityRef) =>
    a?.kind === b.kind &&
    a.contour === b.contour &&
    a.index === b.index &&
    a.control === b.control &&
    a.parameter === b.parameter;
  const constraints = (next.constraints ??= []);
  if (
    !constraints.some(
      (c) =>
        c.kind === "coincident" &&
        ((same(c.a, endpoint) && same(c.b, target)) ||
          (same(c.b, endpoint) && same(c.a, target))),
    )
  ) {
    const used = new Set(constraints.map((c) => c.id));
    let n = 1;
    while (used.has(`extend-point-${n}`)) n++;
    constraints.push({
      id: `extend-point-${n}`,
      kind: "coincident",
      a: { ...endpoint },
      b: target,
    });
  }
  validateSketchDrawing(next);
  return next;
}
