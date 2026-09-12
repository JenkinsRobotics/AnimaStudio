import { describe, expect, it } from "vitest";
import { principalFrame } from "@aether/core/document";
import {
  referenceGeometry,
  sketchPlaneForReference,
  parseReferenceVisibility,
} from "./reference-geometry";

describe("reference geometry browser", () => {
  it("keeps the CAD origin and three principal planes", () => {
    expect(referenceGeometry.map((item) => item.id)).toEqual([
      "origin",
      "axes",
      "top-plane",
      "front-plane",
      "right-plane",
    ]);
  });

  it("lists axes separately from the origin point and keeps them unavailable", () => {
    const origin = referenceGeometry.find((item) => item.id === "origin");
    const axes = referenceGeometry.find((item) => item.id === "axes");
    expect(origin?.unavailableReason).toBeUndefined();
    expect(axes?.unavailableReason).toBeTruthy();
  });

  it("maps principal reference planes onto sketch coordinate planes", () => {
    expect(sketchPlaneForReference("top-plane")).toBe("XY");
    expect(sketchPlaneForReference("front-plane")).toBe("XZ");
    expect(sketchPlaneForReference("right-plane")).toBe("YZ");
    expect(sketchPlaneForReference("origin")).toBeNull();
  });

  it("restores stored visibility and drops anything it cannot trust", () => {
    expect(parseReferenceVisibility('{"top-plane":true,"origin":false}')).toEqual({
      "top-plane": true,
      origin: false,
    });
    expect(parseReferenceVisibility('{"top-plane":true,"ghost-plane":true,"axes":"yes"}')).toEqual({
      "top-plane": true,
    });
    for (const bad of [null, "", "not json", "[1,2]", '"text"', "7"])
      expect(parseReferenceVisibility(bad)).toEqual({});
  });
});

// A datum plane and a sketch drawn on it must share one basis, or the sketch
// card appears rotated against the plane it sits on. Both sides derive it from
// principalFrame; this pins what that basis is, per plane.
describe("principal plane orientation", () => {
  const basis = (plane: "XY" | "XZ" | "YZ") => {
    const { xDirection: x, normal: n } = principalFrame(plane);
    // y = n x x, exactly as the viewer and the CSS3D sketch surface compute it.
    const y: [number, number, number] = [
      n[1] * x[2] - n[2] * x[1],
      n[2] * x[0] - n[0] * x[2],
      n[0] * x[1] - n[1] * x[0],
    ];
    // Cross products yield -0 components; normalise so equality reads cleanly.
    const zero = (v: readonly number[]) => v.map((c) => (c === 0 ? 0 : c));
    return { x: zero(x), y: zero(y), n: zero(n) };
  };

  it("keeps every principal plane right-handed with a sensible up", () => {
    // Top: screen-right is +X, up is +Y. Front and Right both stand up in +Z.
    expect(basis("XY")).toEqual({ x: [1, 0, 0], y: [0, 1, 0], n: [0, 0, 1] });
    expect(basis("XZ")).toEqual({ x: [1, 0, 0], y: [0, 0, 1], n: [0, -1, 0] });
    expect(basis("YZ")).toEqual({ x: [0, 1, 0], y: [0, 0, 1], n: [1, 0, 0] });
  });

  it("orients every reference plane the sketch tool can target", () => {
    for (const id of ["top-plane", "front-plane", "right-plane"] as const) {
      const plane = sketchPlaneForReference(id);
      expect(plane, `${id} must map to a sketch plane`).toBeTruthy();
      const { x, y, n } = basis(plane!);
      // Right-handed: x x y === n.
      expect(
        [
          x[1] * y[2] - x[2] * y[1],
          x[2] * y[0] - x[0] * y[2],
          x[0] * y[1] - x[1] * y[0],
        ].map((c) => (c === 0 ? 0 : c)),
      ).toEqual(n);
    }
  });
});
