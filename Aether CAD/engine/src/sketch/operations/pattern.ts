import type { SketchEntityRef } from "../solver/types";
import type { SketchDrawing, SketchPoint } from "../drawing";
import { createPatternGroup } from "./pattern-group";
export function linearPattern(
  drawing: SketchDrawing,
  selection: readonly (number | SketchEntityRef)[],
  first: SketchPoint,
  countFirst: number,
  second: SketchPoint = [0, 0],
  countSecond = 1,
): SketchDrawing {
  return createPatternGroup(drawing, selection, {
    kind: "linear",
    first,
    second,
    countFirst,
    countSecond,
  });
}
export function circularPattern(
  drawing: SketchDrawing,
  selection: readonly (number | SketchEntityRef)[],
  center: SketchPoint,
  instances: number,
  stepDegrees: number,
): SketchDrawing {
  return createPatternGroup(drawing, selection, {
    kind: "circular",
    center,
    count: instances,
    stepDegrees,
  });
}
