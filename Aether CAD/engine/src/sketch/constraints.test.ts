import { describe, expect, it } from "vitest";
import {
  createCenterRectangleSketch,
  rectangleSketchRevision,
  reviseCenterRectangleSketch,
  sketchDefinitionState,
} from "./constraints";

describe("sketch constraint state", () => {
  it("tracks under-defined and fully-defined rectangle degrees of freedom", () => {
    const initial = createCenterRectangleSketch("sketch-1", "XY", 60, 40, false);
    expect(sketchDefinitionState(initial).remainingDegreesOfFreedom).toBe(2);

    const dimensioned = reviseCenterRectangleSketch(initial, {
      ...rectangleSketchRevision(initial),
      widthDimensioned: true,
      heightDimensioned: true,
    });
    expect(sketchDefinitionState(dimensioned)).toEqual({
      fullyDefined: true,
      remainingDegreesOfFreedom: 0,
      label: "Fully defined",
    });
  });
});
