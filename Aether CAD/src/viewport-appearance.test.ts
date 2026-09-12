import { describe, expect, it } from "vitest";
import { cadDisplayStylePolicy, cadFloorVisibility } from "./viewport-appearance";

describe("CAD display style policy", () => {
  it("keeps shaded and shaded-with-edges distinct", () => {
    expect(cadDisplayStylePolicy("shaded", true).edgesVisible).toBe(false);
    expect(cadDisplayStylePolicy("shaded-edges", true).edgesVisible).toBe(true);
    expect(cadDisplayStylePolicy("shaded-edges", false).edgesVisible).toBe(false);
  });

  it("uses surface depth to occlude rear edges in hidden-line mode", () => {
    const policy = cadDisplayStylePolicy("hidden-line", false);
    expect(policy).toMatchObject({
      surfaceWireframe: false,
      surfaceOpacity: 1,
      surfaceDepthWrite: true,
      edgesVisible: true,
      masksSurfaceWithBackground: true,
    });
  });

  it("makes ghost mode translucent without writing depth", () => {
    expect(cadDisplayStylePolicy("ghost", true)).toMatchObject({
      surfaceOpacity: 0.22,
      surfaceDepthWrite: false,
      edgesVisible: true,
    });
  });
});

// A sketch renders its own grid on its own plane. The world floor grid sits in a
// different plane at the world origin, so leaving it on during a sketch shows two
// unrelated planes floating near each other.
it("hides the world floor and grid while a sketch plane is open", () => {
  for (const mode of ["none", "grid", "floor", "both"] as const)
    expect(cadFloorVisibility(mode, true)).toEqual({ grid: false, floor: false });
  expect(cadFloorVisibility("grid", false)).toEqual({ grid: true, floor: false });
  expect(cadFloorVisibility("floor", false)).toEqual({ grid: false, floor: true });
  expect(cadFloorVisibility("both", false)).toEqual({ grid: true, floor: true });
  expect(cadFloorVisibility("none", false)).toEqual({ grid: false, floor: false });
});
