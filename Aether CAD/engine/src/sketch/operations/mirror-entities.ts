import { identifySourceEdges } from "./identify-source-edges";
import { uniquePatternSources } from "../solver/pattern-source-key";
import {
  validateSketchDrawing,
  type SketchDrawing,
  type SketchPoint,
} from "../drawing";
import type { SketchEntityRef } from "../solver/types";
import { resolve } from "../solver/entities";
import {
  patternSourceContour,
  mirrorAxisConflicts,
} from "../solver/pattern-source";
import { mirrorTransform } from "../curves/reflection";
import { transformContour } from "./transform";
/** Entity references remain live; each copied segment gets its own generated contour. */
export function mirrorSketchEntities(
  source: SketchDrawing,
  selection: readonly SketchEntityRef[],
  start: SketchPoint,
  end: SketchPoint,
  axis?: SketchEntityRef,
): SketchDrawing {
  validateSketchDrawing(source);
  const next = structuredClone(source);
  const refs = uniquePatternSources(identifySourceEdges(next, selection));
  if (!refs.length) throw Error("Select edges or points to mirror.");
  if (source.contours.length + refs.length > 1000)
    throw Error("A sketch supports at most 1000 contours.");
  const line = axis ? resolve(next, axis).line : undefined;
  if (axis && !line) throw Error("Mirror axis must be a line.");
  if (axis) axis = identifySourceEdges(next, [axis])[0];
  if (
    axis &&
    refs.some((ref) => mirrorAxisConflicts(ref, axis, undefined, next))
  )
    throw Error("Exclude the mirror axis itself from the selected geometry.");
  const transform = mirrorTransform(line?.[0] ?? start, line?.[1] ?? end),
    constraints = (next.constraints ??= []),
    used = new Set(constraints.map((c) => c.id));
  for (const ref of refs) {
    const copy = transformContour(patternSourceContour(next, ref), transform);
    delete copy.id;
    const target = next.contours.length;
    next.contours.push(copy);
    const base = `mirror-${target}`;
    let id = base,
      suffix = 0;
    while (used.has(id)) id = `${base}-${++suffix}`;
    used.add(id);
    constraints.push({
      id,
      kind: "pattern",
      a: { ...ref },
      b: { kind: "contour", contour: target },
      ...(axis ? { axis: { ...axis } } : { transform: { ...transform } }),
    });
  }
  validateSketchDrawing(next);
  return next;
}
