import { describe, expect, it } from "vitest";
import type { ConnectorFrameData } from "../contracts/index";
import {
  connectorTransform,
  identityTransform,
  multiplyTransforms,
  rotationXTransform,
  solveFastenedMateTransform,
  transformsAlmostEqual,
} from "./transforms";

const frame = (
  origin: readonly [number, number, number],
  xAxis: readonly [number, number, number] = [1, 0, 0],
  zAxis: readonly [number, number, number] = [0, 0, 1],
): ConnectorFrameData => ({
  origin,
  xAxis,
  yAxis: [
    zAxis[1] * xAxis[2] - zAxis[2] * xAxis[1],
    zAxis[2] * xAxis[0] - zAxis[0] * xAxis[2],
    zAxis[0] * xAxis[1] - zAxis[1] * xAxis[0],
  ],
  zAxis,
});

describe("headless assembly transforms", () => {
  it("aligns a moving connector to the flipped target connector", () => {
    const moving = frame([7, -2, 5], [0, 1, 0], [0, 0, 1]);
    const target = frame([2, 3, 4], [0, 0, 1], [1, 0, 0]);
    const solved = solveFastenedMateTransform(moving, target);
    const movingWorld = multiplyTransforms(solved, connectorTransform(moving));
    const expected = multiplyTransforms(
      connectorTransform(target),
      rotationXTransform(Math.PI),
    );

    expect(transformsAlmostEqual(movingWorld, expected)).toBe(true);
  });

  it("keeps the identity transform renderer-independent", () => {
    const connector = frame([10, 20, 30]);
    expect(
      transformsAlmostEqual(
        multiplyTransforms(identityTransform, connectorTransform(connector)),
        connectorTransform(connector),
      ),
    ).toBe(true);
  });
});
