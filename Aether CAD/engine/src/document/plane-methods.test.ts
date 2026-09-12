import { describe, expect, it } from "vitest";
import { resolvePlaneFrame, validatePlaneDefinition } from "./construction-planes";

const plane = (definition: any) => ({
  id: "p1", type: "plane" as const, name: "Plane 1", plane: "XY" as const,
  offsetMillimeters: 0, suppressed: false, definition,
});
const point = (id: string, positionMillimeters: [number, number, number]) => ({
  kind: "point" as const, partId: "part", candidateId: id, positionMillimeters,
});
const close = (a: readonly number[], b: readonly number[]) =>
  a.forEach((v, i) => expect(v).toBeCloseTo(b[i], 9));

describe("three point plane", () => {
  it("spans the plane through three points", () => {
    const frame = resolvePlaneFrame(
      plane({
        method: "three-point",
        points: [point("a", [0, 0, 0]), point("b", [10, 0, 0]), point("c", [0, 10, 0])],
      }),
      [],
    );
    expect(frame.originMillimeters).toEqual([0, 0, 0]);
    close(frame.normal, [0, 0, 1]);
    // Canonical X, so it aligns like every other plane in the document.
    close(frame.xDirection, [1, 0, 0]);
  });

  it("handles a plane that is not axis aligned", () => {
    const frame = resolvePlaneFrame(
      plane({
        method: "three-point",
        points: [point("a", [0, 0, 0]), point("b", [1, 0, 1]), point("c", [0, 1, 0])],
      }),
      [],
    );
    // Normal is perpendicular to both spanning vectors.
    const u = [1, 0, 1];
    const v = [0, 1, 0];
    expect(u.reduce((s, c, i) => s + c * frame.normal[i], 0)).toBeCloseTo(0, 9);
    expect(v.reduce((s, c, i) => s + c * frame.normal[i], 0)).toBeCloseTo(0, 9);
    expect(Math.hypot(...frame.normal)).toBeCloseTo(1, 9);
  });

  it("refuses three collinear points", () => {
    expect(() =>
      resolvePlaneFrame(
        plane({
          method: "three-point",
          points: [point("a", [0, 0, 0]), point("b", [1, 1, 1]), point("c", [2, 2, 2])],
        }),
        [],
      ),
    ).toThrow(/non-collinear/);
  });

  it("rejects a malformed definition before it resolves", () => {
    expect(() =>
      validatePlaneDefinition(
        plane({ method: "three-point", points: [point("a", [0, 0, 0])] }),
        new Set(),
      ),
    ).toThrow(/exactly three points/);
  });
});

describe("angled plane", () => {
  const axis = {
    kind: "axis" as const, partId: "part", candidateId: "e1",
    originMillimeters: [0, 0, 0] as [number, number, number],
    directionMillimeters: [1, 0, 0] as [number, number, number],
  };
  const fromTop = (angleDegrees: number) =>
    resolvePlaneFrame(
      plane({
        method: "angle",
        axis,
        reference: { kind: "principal", plane: "XY" },
        angleDegrees,
      }),
      [],
    );

  it("is parallel to the reference plane at zero degrees", () => {
    close(fromTop(0).normal, [0, 0, 1]);
  });

  it("stands perpendicular at ninety degrees", () => {
    // Right-hand rule: rotating +Z about +X by 90 deg gives -Y, matching the
    // y = n x x convention every other frame in the document uses.
    close(fromTop(90).normal, [0, -1, 0]);
    // The opposite sense is the negative angle, not a different rule.
    close(fromTop(-90).normal, [0, 1, 0]);
  });

  it("rotates continuously and stays on the axis", () => {
    const frame = fromTop(45);
    close(frame.normal, [0, -Math.SQRT1_2, Math.SQRT1_2]);
    // The plane passes through the edge it was built on.
    expect(frame.originMillimeters).toEqual([0, 0, 0]);
    // The axis lies in the plane: axis . normal === 0.
    expect(
      axis.directionMillimeters.reduce((s, c, i) => s + c * frame.normal[i], 0),
    ).toBeCloseTo(0, 9);
  });

  it("normalises an unnormalised edge direction", () => {
    const frame = resolvePlaneFrame(
      plane({
        method: "angle",
        axis: { ...axis, directionMillimeters: [7, 0, 0] },
        reference: { kind: "principal", plane: "XY" },
        angleDegrees: 90,
      }),
      [],
    );
    close(frame.normal, [0, -1, 0]);
  });

  it("refuses a degenerate axis and a non-finite angle", () => {
    expect(() =>
      resolvePlaneFrame(
        plane({
          method: "angle",
          axis: { ...axis, directionMillimeters: [0, 0, 0] },
          reference: { kind: "principal", plane: "XY" },
          angleDegrees: 30,
        }),
        [],
      ),
    ).toThrow(/no direction/);
    expect(() =>
      validatePlaneDefinition(
        plane({ method: "angle", axis, reference: { kind: "principal", plane: "XY" }, angleDegrees: NaN }),
        new Set(),
      ),
    ).toThrow(/finite angle/);
  });
});
