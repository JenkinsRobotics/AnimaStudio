import { describe, expect, it } from "vitest";
import {
  createCenterRectangleSketch,
  rectangleSketchRevision,
  reviseCenterRectangleSketch,
  sketchDefinitionState,
} from "./sketch-constraints";

describe("center rectangle sketch constraints", () => {
  it("starts origin-anchored but under-defined until width and height are dimensioned", () => {
    const sketch = createCenterRectangleSketch("sketch-1", "XY", 60, 40, false);

    expect(rectangleSketchRevision(sketch)).toMatchObject({
      horizontal: true,
      vertical: true,
      anchoredToOrigin: true,
      widthDimensioned: false,
      heightDimensioned: false,
    });
    expect(sketchDefinitionState(sketch)).toEqual({
      fullyDefined: false,
      remainingDegreesOfFreedom: 2,
      label: "Under-defined",
    });
  });

  it("becomes fully defined after both dimensions are applied", () => {
    const sketch = createCenterRectangleSketch("sketch-1", "XY", 60, 40, false);
    const revised = reviseCenterRectangleSketch(sketch, {
      ...rectangleSketchRevision(sketch),
      widthMillimeters: 80,
      heightMillimeters: 45,
      widthDimensioned: true,
      heightDimensioned: true,
    });

    expect(sketchDefinitionState(revised)).toEqual({
      fullyDefined: true,
      remainingDegreesOfFreedom: 0,
      label: "Fully defined",
    });
    expect(revised.dimensions.map((dimension) => dimension.id)).toEqual([
      "sketch-1:dimension:width",
      "sketch-1:dimension:height",
    ]);
  });

  it("counts an unconstrained center as two translational degrees of freedom", () => {
    const sketch = createCenterRectangleSketch("sketch-1", "YZ", 60, 40, true);
    const revised = reviseCenterRectangleSketch(sketch, {
      ...rectangleSketchRevision(sketch),
      anchoredToOrigin: false,
    });

    expect(sketchDefinitionState(revised).remainingDegreesOfFreedom).toBe(2);
    expect(rectangleSketchRevision(revised).plane).toBe("YZ");
  });
});

