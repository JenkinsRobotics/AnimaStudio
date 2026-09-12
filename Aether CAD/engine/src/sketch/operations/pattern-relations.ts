import { validateSketchDrawing, type SketchDrawing } from "../drawing";
import {
  copySketchContours,
  selectedContours,
  type SketchTransform,
} from "./transform";
/** One relation per source/instance contour; the source's original constraints remain canonical. */
export function copyPatternContours(
  source: SketchDrawing,
  selection: readonly number[],
  transforms: readonly SketchTransform[],
): SketchDrawing {
  const indices = selectedContours(source, selection),
    next = copySketchContours(source, indices, transforms, {
      preserveConstraints: false,
      preserveText: false,
    });
  const constraints = (next.constraints ??= []);
  const used = new Set(constraints.map((c) => c.id));
  let target = source.contours.length;
  for (const transform of transforms)
    for (const contour of indices) {
      const base = `pattern-${target}`;
      let id = base,
        suffix = 0;
      while (used.has(id)) id = `${base}-${++suffix}`;
      used.add(id);
      constraints.push({
        id,
        kind: "pattern",
        a: { kind: "contour", contour },
        b: { kind: "contour", contour: target++ },
        transform: { ...transform },
      });
    }
  validateSketchDrawing(next);
  return next;
}
