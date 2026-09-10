import { describe, expect, it } from "vitest";
import { connectorAxes, pointAlongAxis } from "./cad-frame-math";

describe("connectorAxes", () => {
  it("creates the expected right-handed frame", () => {
    expect(connectorAxes([0, 0, 1], [1, 0, 0])).toEqual({
      xAxis: [1, 0, 0],
      yAxis: [0, 1, 0],
      zAxis: [0, 0, 1],
    });
  });

  it("uses a stable perpendicular axis when preferred X is parallel to Z", () => {
    const frame = connectorAxes([1, 0, 0], [1, 0, 0]);
    const dot = (a: readonly number[], b: readonly number[]) =>
      a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
    expect(dot(frame.xAxis, frame.zAxis)).toBeCloseTo(0);
    expect(dot(frame.yAxis, frame.zAxis)).toBeCloseTo(0);
    expect(dot(frame.xAxis, frame.yAxis)).toBeCloseTo(0);
  });
});

describe("pointAlongAxis", () => {
  it("places finite feature stations along their exact axis", () => {
    expect(pointAlongAxis([1, 2, 3], [0, 0, 1], 4.5)).toEqual([1, 2, 7.5]);
  });
});
