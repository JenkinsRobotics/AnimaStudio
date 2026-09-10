import type { SketchPoint, SketchDrawing } from "./drawing";
import type { DrawingConstraint } from "./solver/types";
import { similarityTransform } from "./curves/similarity";
export type SketchPatternGroup =
  | {
      kind: "linear";
      first: SketchPoint;
      second: SketchPoint;
      countFirst: number;
      countSecond: number;
    }
  | {
      kind: "circular";
      center: SketchPoint;
      count: number;
      stepDegrees: number;
    };
export function patternInstanceCount(group: SketchPatternGroup): number {
  const count = (n: number) => {
    if (!Number.isInteger(n) || n < 1 || n > 100)
      throw Error("Pattern counts must be integers from 1 to 100.");
  };
  const point = (p: SketchPoint) => {
    if (!Array.isArray(p) || p.length !== 2 || !p.every(Number.isFinite))
      throw Error("Pattern coordinates must be finite.");
  };
  if (group.kind === "linear") {
    count(group.countFirst);
    count(group.countSecond);
    point(group.first);
    point(group.second);
    if (
      group.countFirst * group.countSecond < 2 ||
      (group.countFirst > 1 && Math.hypot(...group.first) < 1e-8) ||
      (group.countSecond > 1 && Math.hypot(...group.second) < 1e-8)
    )
      throw Error(
        "A pattern needs at least two instances with nonzero spacing.",
      );
    return group.countFirst * group.countSecond;
  }
  if (group.kind !== "circular") throw Error("Invalid pattern group kind.");
  count(group.count);
  point(group.center);
  if (
    group.count < 2 ||
    !Number.isFinite(group.stepDegrees) ||
    Math.abs(group.stepDegrees % 360) < 1e-8
  )
    throw Error("Use at least two instances and a nonzero angular step.");
  return group.count;
}
export function patternInstanceTransform(
  group: SketchPatternGroup,
  instance: number,
) {
  const count = patternInstanceCount(group);
  if (!Number.isInteger(instance) || instance < 1 || instance >= count)
    throw Error("Pattern instance index is out of range.");
  if (group.kind === "circular")
    return similarityTransform(
      group.center,
      [0, 0],
      instance * group.stepDegrees,
    );
  const i = instance % group.countFirst,
    j = Math.floor(instance / group.countFirst);
  return similarityTransform(
    [0, 0],
    [
      i * group.first[0] + j * group.second[0],
      i * group.first[1] + j * group.second[1],
    ],
    0,
  );
}
export function patternRelationTransform(
  d: SketchDrawing,
  c: DrawingConstraint,
) {
  if (c.patternGroup !== undefined) {
    if (c.transform || c.axis)
      throw Error(
        "Grouped patterns cannot also contain a fixed transform or mirror axis.",
      );
    const group = d.patternGroups?.[c.patternGroup];
    if (!group) throw Error("Missing pattern group.");
    return patternInstanceTransform(group, c.patternInstance!);
  }
  return c.transform;
}
export function validatePatternGroups(d: SketchDrawing) {
  if (d.patternGroups === undefined) return;
  if (
    !d.patternGroups ||
    typeof d.patternGroups !== "object" ||
    Array.isArray(d.patternGroups)
  )
    throw Error("Invalid pattern groups.");
  for (const [id, group] of Object.entries(d.patternGroups)) {
    if (!id.trim() || id.length > 128)
      throw Error("Invalid pattern group identity.");
    patternInstanceCount(group);
  }
}
