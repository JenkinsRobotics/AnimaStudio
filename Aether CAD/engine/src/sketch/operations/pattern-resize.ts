import { patternSourceContour } from "../solver/pattern-source";
import {
  patternSourceKey,
  uniquePatternSources,
} from "../solver/pattern-source-key";
import type { SketchDrawing } from "../drawing";
import {
  patternInstanceCount,
  patternInstanceTransform,
  type SketchPatternGroup,
} from "../pattern-groups";
import { deleteSketchContour } from "./delete";
import { transformContour } from "./transform";
/** Retain 2D grid coordinates, not flattened indices, when changing row widths. */
export function resizePatternInstances(
  source: SketchDrawing,
  id: string,
  definition: SketchPatternGroup,
  restoreMissing = false,
): SketchDrawing {
  const old = source.patternGroups![id],
    oldCount = patternInstanceCount(old),
    newCount = patternInstanceCount(definition);
  if (old.kind !== definition.kind)
    throw Error("Changing pattern kind is not supported.");
  const widthChanged =
    old.kind === "linear" &&
    definition.kind === "linear" &&
    old.countFirst !== definition.countFirst;
  if (oldCount === newCount && !widthChanged && !restoreMissing)
    return structuredClone(source);
  const relations = (source.constraints ?? []).filter(
      (c) => c.patternGroup === id,
    ),
    sources = uniquePatternSources(relations.map((c) => c.a));
  const slots = new Set(
    relations.map((c) => `${patternSourceKey(c.a)}:${c.patternInstance}`),
  );
  if (
    !sources.length ||
    (!restoreMissing && relations.length !== sources.length * (oldCount - 1)) ||
    slots.size !== relations.length
  )
    throw Error(
      "Restore or detach the incomplete pattern before changing its count.",
    );
  const retained = new Map<string, number>(),
    removed = new Set<number>(),
    removedRelations = new Set<string>();
  for (const c of relations) {
    if (!c.b && !c.patternSuppression)
      throw Error("Pattern instance is missing.");
    let instance = c.patternInstance!;
    if (old.kind === "linear" && definition.kind === "linear") {
      const x = instance % old.countFirst,
        y = Math.floor(instance / old.countFirst);
      instance =
        x < definition.countFirst && y < definition.countSecond
          ? y * definition.countFirst + x
          : -1;
    }
    if (instance < 1 || instance >= newCount) {
      if (c.b) removed.add(c.b.contour);
      removedRelations.add(c.id);
    } else retained.set(c.id, instance);
  }
  for (const c of source.constraints ?? [])
    if (
      !removedRelations.has(c.id) &&
      [c.a, c.b, c.axis].some((r) => r && removed.has(r.contour))
    )
      throw Error(
        "A removed pattern instance has dependent sketch constraints. Remove those dependencies first.",
      );
  const finalSize =
    source.contours.length -
    removed.size +
    sources.length * (newCount - 1) -
    retained.size;
  if (finalSize > 1000)
    throw Error(
      "A sketch supports at most 1000 contours. Reduce the pattern count.",
    );
  let next = structuredClone(source);
  next.constraints = next.constraints?.filter(
    (c) => !removedRelations.has(c.id),
  );
  for (const index of [...removed].sort((a, b) => b - a))
    next = deleteSketchContour(next, index);
  const remap = (index: number) =>
    index - [...removed].filter((i) => i < index).length;
  const mappedSources = sources.map((ref) => ({
      ...ref,
      contour: remap(ref.contour),
    })),
    existing = new Set<string>();
  for (const c of next.constraints ?? [])
    if (c.patternGroup === id) {
      c.patternInstance = retained.get(c.id)!;
      existing.add(`${patternSourceKey(c.a)}:${c.patternInstance}`);
    }
  const constraints = (next.constraints ??= []),
    used = new Set(constraints.map((c) => c.id));
  for (let instance = 1; instance < newCount; instance++)
    for (const contour of mappedSources) {
      if (existing.has(`${patternSourceKey(contour)}:${instance}`)) continue;
      const target = next.contours.length,
        copied = transformContour(
          patternSourceContour(next, contour),
          patternInstanceTransform(definition, instance),
        );
      delete copied.id;
      next.contours.push(copied);
      const base = `pattern-${target}`;
      let relationID = base,
        suffix = 0;
      while (used.has(relationID)) relationID = `${base}-${++suffix}`;
      used.add(relationID);
      constraints.push({
        id: relationID,
        kind: "pattern",
        a: { ...contour },
        b: { kind: "contour", contour: target },
        patternGroup: id,
        patternInstance: instance,
      });
    }
  return next;
}
