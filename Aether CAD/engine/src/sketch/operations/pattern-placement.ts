import { patternSourceKey } from "../solver/pattern-source-key";
import { validateSketchDrawing, type SketchDrawing } from "../drawing";
import { patternInstanceCount } from "../pattern-groups";
import { setPatternInstanceSuppressed } from "./pattern-suppression";
export function patternPlacements(source: SketchDrawing, id: string) {
  const group = source.patternGroups?.[id];
  if (!group) throw Error("Select an existing pattern group.");
  const relations = (source.constraints ?? []).filter(
      (c) => c.patternGroup === id,
    ),
    expected = new Set(relations.map((c) => patternSourceKey(c.a))).size;
  return Array.from({ length: patternInstanceCount(group) - 1 }, (_, i) => {
    const instance = i + 1,
      members = relations.filter((c) => c.patternInstance === instance);
    return {
      instance,
      relationIds: members.map((c) => c.id),
      suppressed: members.filter((c) => c.patternSuppression).length,
      complete:
        expected > 0 &&
        members.length === expected &&
        new Set(members.map((c) => patternSourceKey(c.a))).size === expected,
    };
  });
}
/** Batch all source contours at one placement; callers commit only the final successful result. */
export function setPatternPlacementSuppressed(
  source: SketchDrawing,
  id: string,
  instance: number,
  suppressed: boolean,
): SketchDrawing {
  validateSketchDrawing(source);
  const placement = patternPlacements(source, id).find(
    (p) => p.instance === instance,
  );
  if (!placement) throw Error("Select an existing repeated pattern placement.");
  if (!placement.complete)
    throw Error(
      "Restore missing pattern instances before changing the whole placement.",
    );
  let next = structuredClone(source);
  for (const relationId of placement.relationIds)
    next = setPatternInstanceSuppressed(next, relationId, suppressed);
  return next;
}
