import { describe, expect, it } from "vitest";
import {
  referenceGeometry,
  sketchPlaneForReference,
} from "./reference-geometry";

describe("reference geometry browser", () => {
  it("keeps the CAD origin and three principal planes", () => {
    expect(referenceGeometry.map((item) => item.id)).toEqual([
      "origin",
      "top-plane",
      "front-plane",
      "right-plane",
    ]);
  });

  it("maps principal reference planes onto sketch coordinate planes", () => {
    expect(sketchPlaneForReference("top-plane")).toBe("XY");
    expect(sketchPlaneForReference("front-plane")).toBe("XZ");
    expect(sketchPlaneForReference("right-plane")).toBe("YZ");
    expect(sketchPlaneForReference("origin")).toBeNull();
  });
});
