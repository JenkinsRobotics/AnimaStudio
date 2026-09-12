import { describe, expect, it } from "vitest";
import { canonicalPlaneXDirection, principalFrame } from "./construction-planes";
import type { SketchPlane } from "./part-document";

// A sketch must land the same way up whether its plane is a datum, an offset
// plane, or a face on a solid. A kernel face carries its own arbitrary surface
// parameterization, so the in-plane X has to be derived from the normal alone.
describe("canonical in-plane X", () => {
  it("agrees with every principal plane, so datums and faces share one convention", () => {
    for (const plane of ["XY", "XZ", "YZ"] as const satisfies readonly SketchPlane[]) {
      const frame = principalFrame(plane);
      expect(canonicalPlaneXDirection(frame.normal), `${plane} disagrees`).toEqual(
        frame.xDirection,
      );
    }
  });

  it("returns a unit vector lying in the plane", () => {
    const normals: [number, number, number][] = [
      [0, 0, 1], [0, 0, -1], [0, 1, 0], [0, -1, 0], [1, 0, 0], [-1, 0, 0],
      [0, 0.7071067811865476, 0.7071067811865476], [0.3, -0.5, 0.81], [2, 0, 0],
    ];
    for (const n of normals) {
      const x = canonicalPlaneXDirection(n);
      expect(Math.hypot(...x), `not unit for ${n}`).toBeCloseTo(1, 12);
      const unit = Math.hypot(...n);
      const dot = x.reduce((sum, c, i) => sum + (c * n[i]) / unit, 0);
      expect(dot, `not perpendicular for ${n}`).toBeCloseTo(0, 12);
    }
  });

  it("depends only on the normal, so coplanar faces never disagree", () => {
    // Same plane, normal given at different magnitudes and sign conventions.
    expect(canonicalPlaneXDirection([0, 0, 1])).toEqual(canonicalPlaneXDirection([0, 0, 5]));
    // An anti-parallel normal is still the same plane and keeps the same X;
    // only the resulting Y (n x X) flips, which is the intended facing change.
    expect(canonicalPlaneXDirection([0, 0, -1])).toEqual(canonicalPlaneXDirection([0, 0, 1]));
  });

  it("never degenerates when the normal is parallel to the reference axis", () => {
    for (const n of [[1, 0, 0], [-1, 0, 0]] as [number, number, number][]) {
      const x = canonicalPlaneXDirection(n);
      expect(x).toEqual([0, 1, 0]);
      expect(Number.isNaN(x[0])).toBe(false);
    }
  });

  it("falls back to a usable axis for a degenerate normal", () => {
    expect(canonicalPlaneXDirection([0, 0, 0])).toEqual([1, 0, 0]);
  });
});
