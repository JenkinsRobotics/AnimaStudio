import { describe, expect, it } from "vitest";
import { Matrix4, Vector3 } from "three";
import type { ConnectorFrameData } from "./domain";
import { connectorMatrix, matrixAlmostEqual, solveFastenedMate } from "./math";

const frame = (
  origin: readonly [number, number, number],
  xAxis: readonly [number, number, number] = [1, 0, 0],
  zAxis: readonly [number, number, number] = [0, 0, 1],
): ConnectorFrameData => ({
  origin,
  xAxis,
  yAxis: new Vector3(...zAxis).cross(new Vector3(...xAxis)).toArray() as [
    number,
    number,
    number,
  ],
  zAxis,
});

describe("fastened mate matrix", () => {
  it("implements W2 · T2 · RflipX · inverse(T1)", () => {
    const moving = frame([7, -2, 5], [0, 1, 0], [0, 0, 1]);
    const target = frame([2, 3, 4], [0, 0, 1], [1, 0, 0]);
    const targetWorld = new Matrix4()
      .makeRotationY(0.47)
      .setPosition(new Vector3(11, 13, 17));

    const solved = solveFastenedMate(moving, target, targetWorld);
    const movingConnectorWorld = solved.clone().multiply(connectorMatrix(moving));
    const expectedConnectorWorld = targetWorld
      .clone()
      .multiply(connectorMatrix(target))
      .multiply(new Matrix4().makeRotationX(Math.PI));

    expect(matrixAlmostEqual(movingConnectorWorld, expectedConnectorWorld)).toBe(true);
  });

  it("coincides origins and anti-aligns primary Z axes", () => {
    const moving = frame([10, 0, 0]);
    const target = frame([0, 20, 0]);
    const solved = solveFastenedMate(moving, target, new Matrix4());
    const connectorWorld = solved.clone().multiply(connectorMatrix(moving));
    const position = new Vector3().setFromMatrixPosition(connectorWorld);
    const basisZ = new Vector3().setFromMatrixColumn(connectorWorld, 2).normalize();

    expect(position.distanceTo(new Vector3(0, 20, 0))).toBeLessThan(1e-8);
    expect(basisZ.distanceTo(new Vector3(0, 0, -1))).toBeLessThan(1e-8);
  });
});
