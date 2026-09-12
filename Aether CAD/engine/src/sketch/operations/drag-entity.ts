import {
  contourClosed,
  validateSketchDrawing,
  type SketchDrawing,
  type SketchPoint,
} from "../drawing";
import {
  sketchEntityPoint,
  solveDrawingConstraints,
  type SketchEntityRef,
  type DrawingConstraint,
} from "../drawing-constraints";
import { translateRetainedTextForDrag } from "../text/drag";
/** Solve a pointer move with temporary point targets; no drag constraints are persisted. */
export function dragSketchEntity(
  source: SketchDrawing,
  ref: SketchEntityRef,
  delta: SketchPoint,
): SketchDrawing {
  if (!delta.every(Number.isFinite))
    throw new Error("Pointer movement must be finite.");
  const next = structuredClone(source);
  const retainedText = translateRetainedTextForDrag(next, ref.contour, delta);
  const path = next.contours[ref.contour];
  if (!path) throw new Error("Select existing geometry.");
  const refs: SketchEntityRef[] =
    ref.kind === "point"
      ? [ref]
      : path.type === "circle"
        ? [{ contour: ref.contour, kind: "point", index: 0 }]
        : [
            { contour: ref.contour, kind: "point", index: ref.index! },
            { contour: ref.contour, kind: "point", index: ref.index! + 1 },
          ];
  if (path.type === "path" && ref.kind !== "point") {
    const segment = path.segments[ref.index!];
    if (!segment) throw new Error("Select an existing segment.");
    if (segment.type === "bezier")
      refs.push(
        ...([0, 1] as const).map((control) => ({
          contour: ref.contour,
          kind: "point" as const,
          index: ref.index,
          control,
        })),
      );
    if (segment.type === "arc" && !retainedText)
      segment.middle = [
        segment.middle[0] + delta[0],
        segment.middle[1] + delta[1],
      ];
  }
  const used = new Set(next.constraints?.map((c) => c.id)),
    targets: DrawingConstraint[] = [];
  for (const [i, r] of refs.entries()) {
    const old = sketchEntityPoint(source, r),
      p = sketchEntityPoint(next, r);
    if (!old || !p) throw new Error("The selected entity cannot be moved.");
    const target: SketchPoint = [old[0] + delta[0], old[1] + delta[1]];
    p[0] = target[0];
    p[1] = target[1];
    if (
      path.type === "path" &&
      r.control === undefined &&
      contourClosed(source.contours[ref.contour]) &&
      (r.index === 0 || r.index === path.segments.length)
    ) {
      path.start = [...target];
      path.segments.at(-1)!.end = [...target];
    }
    let id = `drag-target-${i}`;
    while (used.has(id)) id += "-";
    used.add(id);
    targets.push({ id, kind: "fix", a: r, point: target });
  }
  next.constraints = [...(next.constraints ?? []), ...targets];
  const solved = solveDrawingConstraints(next);
  const temporaryIds = new Set(targets.map((c) => c.id));
  solved.constraints =
    source.constraints === undefined
      ? undefined
      : solved.constraints?.filter((c) => !temporaryIds.has(c.id));
  validateSketchDrawing(solved);
  return solved;
}
