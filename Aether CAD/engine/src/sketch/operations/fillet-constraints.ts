import type { SketchDrawing } from "../drawing";
import type { SketchEntityRef } from "../drawing-constraints";
/** Attach the shared persisted contract for a finite-curve fillet to an operation's draft. */
export function addFilletConstraints(
  draft: SketchDrawing,
  contour: number,
  incoming: number,
  arc: number,
  outgoing: number,
  radius: number,
): void {
  const constraints = (draft.constraints ??= []),
    used = new Set(constraints.map((c) => c.id));
  const id = (kind: string) => {
    const base = `fillet-curve-${contour}-${kind}`;
    let result = base,
      n = 0;
    while (used.has(result)) result = `${base}-${++n}`;
    used.add(result);
    return result;
  };
  const endpoint = (index: number, parameter: number): SketchEntityRef => ({
    contour,
    kind: "curve",
    index,
    parameter,
  });
  constraints.push(
    {
      id: id("radius"),
      kind: "radius",
      a: { contour, kind: "arc", index: arc },
      value: radius,
    },
    {
      id: id("tangent-a"),
      kind: "tangent",
      a: endpoint(incoming, 1),
      b: endpoint(arc, 0),
    },
    {
      id: id("tangent-b"),
      kind: "tangent",
      a: endpoint(arc, 1),
      b: endpoint(outgoing, 0),
    },
  );
}
