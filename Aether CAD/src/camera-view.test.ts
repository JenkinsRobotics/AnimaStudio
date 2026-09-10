import { describe, expect, it } from "vitest";
import {
  cameraViewDefinition,
  nudgeCameraBasis,
  rollCameraBasis,
  standardCameraViews,
} from "./camera-view";

describe("standard camera views", () => {
  it("provides all six orthographic directions plus isometric", () => {
    expect(standardCameraViews.map((view) => view.id)).toEqual([
      "isometric",
      "front",
      "back",
      "left",
      "right",
      "top",
      "bottom",
    ]);
  });

  it("uses a non-collinear up vector for the top view", () => {
    const top = cameraViewDefinition("top");
    expect(top.direction).toEqual([0, 1, 0]);
    expect(top.up).toEqual([0, 0, -1]);
  });

  it("nudges the orbit basis in deterministic 15 degree increments", () => {
    const radians = Math.PI / 12;
    const horizontal = nudgeCameraBasis(
      { direction: [0, 0, 1], up: [0, 1, 0] },
      radians,
      0,
    );
    expect(horizontal.direction[0]).toBeCloseTo(Math.sin(radians));
    expect(horizontal.direction[2]).toBeCloseTo(Math.cos(radians));

    const vertical = nudgeCameraBasis(
      { direction: [0, 0, 1], up: [0, 1, 0] },
      0,
      radians,
    );
    expect(vertical.direction[1]).toBeCloseTo(Math.sin(radians));
    expect(vertical.direction[2]).toBeCloseTo(Math.cos(radians));
  });

  it("rolls by 90 degrees while retaining an orthonormal camera basis", () => {
    const rolled = rollCameraBasis(
      { direction: [0, 0, 1], up: [0, 1, 0] },
      Math.PI / 2,
    );
    expect(rolled.direction).toEqual([0, 0, 1]);
    expect(rolled.up[0]).toBeCloseTo(-1);
    expect(rolled.up[1]).toBeCloseTo(0);
  });
});
