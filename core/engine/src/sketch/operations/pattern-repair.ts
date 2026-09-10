import type { SketchEntityRef } from "../solver/types";
import {
  patternSourceKey,
  uniquePatternSources,
} from "../solver/pattern-source-key";
import { validateSketchDrawing, type SketchDrawing } from "../drawing";
import { patternInstanceCount } from "../pattern-groups";
import { resizePatternInstances } from "./pattern-resize";
/** Only surviving source memberships are knowable; fully detached sources are not inferred. */
export function missingPatternInstances(
  source: SketchDrawing,
  id: string,
): { sourceContour: number; source: SketchEntityRef; instance: number }[] {
  const group = source.patternGroups?.[id];
  if (!group) throw Error("Select an existing pattern group.");
  const count = patternInstanceCount(group),
    relations = (source.constraints ?? []).filter((c) => c.patternGroup === id);
  const sources = uniquePatternSources(relations.map((c) => c.a)),
    slots = new Set(
      relations.map((c) => `${patternSourceKey(c.a)}:${c.patternInstance}`),
    );
  if (!sources.length)
    throw Error(
      "No linked sources remain in this pattern. Create a new pattern from the desired source geometry.",
    );
  if (slots.size !== relations.length)
    throw Error("Pattern contains duplicate instance memberships.");
  return sources.flatMap((sourceContour) =>
    Array.from({ length: count - 1 }, (_, i) => i + 1)
      .filter(
        (instance) =>
          !slots.has(`${patternSourceKey(sourceContour)}:${instance}`),
      )
      .map((instance) => ({
        sourceContour: sourceContour.contour,
        source: { ...sourceContour },
        instance,
      })),
  );
}
/** Recreate missing linked copies; existing detached contours remain independent and untouched. */
export function restorePatternInstances(
  source: SketchDrawing,
  id: string,
): SketchDrawing {
  validateSketchDrawing(source);
  const missing = missingPatternInstances(source, id);
  if (!missing.length) return structuredClone(source);
  const next = resizePatternInstances(
    source,
    id,
    source.patternGroups![id],
    true,
  );
  validateSketchDrawing(next);
  return next;
}
