import { identifySourceEdges } from "./identify-source-edges";
import { patternSourceContour } from "../solver/pattern-source";
import { uniquePatternSources } from "../solver/pattern-source-key";
import type { SketchEntityRef } from "../solver/types";
import { resizePatternInstances } from "./pattern-resize";
import { validateSketchDrawing, type SketchDrawing } from "../drawing";
import {
  patternInstanceCount,
  patternInstanceTransform,
  type SketchPatternGroup,
} from "../pattern-groups";
import { transformContour } from "./transform";
import { solveDrawingConstraints } from "../solver/solve";
export function createPatternGroup(
  source: SketchDrawing,
  selection: readonly (number | SketchEntityRef)[],
  definition: SketchPatternGroup,
): SketchDrawing {
  validateSketchDrawing(source);
  const next = structuredClone(source);
  const count = patternInstanceCount(definition),
    refs = uniquePatternSources(
      identifySourceEdges(
        next,
        selection.map((value) =>
          typeof value === "number"
            ? { kind: "contour", contour: value }
            : value,
        ),
      ),
    );
  if (!refs.length) throw Error("Select one or more sketch sources.");
  if (source.contours.length + refs.length * (count - 1) > 1000)
    throw Error(
      "A sketch supports at most 1000 contours. Reduce the pattern count.",
    );
  const groups = (next.patternGroups ??= {}),
    constraints = (next.constraints ??= []);
  let id = "pattern-group",
    suffix = 0;
  while (Object.hasOwn(groups, id)) id = `pattern-group-${++suffix}`;
  groups[id] = structuredClone(definition);
  const used = new Set(constraints.map((c) => c.id));
  for (let instance = 1; instance < count; instance++)
    for (const ref of refs) {
      const copy = transformContour(
        patternSourceContour(next, ref),
        patternInstanceTransform(definition, instance),
      );
      delete copy.id;
      const target = next.contours.length;
      next.contours.push(copy);
      const base = `pattern-${target}`;
      let relationId = base,
        n = 0;
      while (used.has(relationId)) relationId = `${base}-${++n}`;
      used.add(relationId);
      constraints.push({
        id: relationId,
        kind: "pattern",
        a: { ...ref },
        b: { kind: "contour", contour: target },
        patternGroup: id,
        patternInstance: instance,
      });
    }
  validateSketchDrawing(next);
  return next;
}
/** Edit shared placement settings; retained instance and relation identities never change. */
export function editPatternGroup(
  source: SketchDrawing,
  id: string,
  definition: SketchPatternGroup,
): SketchDrawing {
  validateSketchDrawing(source);
  const original = source.patternGroups?.[id];
  if (!original) throw Error("Select an existing pattern group.");
  patternInstanceCount(definition);
  const next = resizePatternInstances(source, id, definition);
  next.patternGroups![id] = structuredClone(definition);
  for (const c of next.constraints ?? [])
    if (c.patternGroup === id && !c.patternSuppression) {
      if (!c.b) throw Error("Pattern instance is missing.");
      const old = next.contours[c.b.contour];
      next.contours[c.b.contour] = {
        ...transformContour(
          patternSourceContour(next, c.a),
          patternInstanceTransform(definition, c.patternInstance!),
        ),
        id: old.id,
        construction: old.construction,
        hole: old.hole,
      };
    }
  const solved = solveDrawingConstraints(next);
  validateSketchDrawing(solved);
  return solved;
}
