import { Matrix4 } from "three";
import {
  connectorTransform,
  solveFastenedMateTransform,
  transformsAlmostEqual,
} from "@aether/core/assembly";
import type { ConnectorFrameData } from "./domain";

export function connectorMatrix(frame: ConnectorFrameData): Matrix4 {
  return new Matrix4().fromArray(connectorTransform(frame));
}

/**
 * Places the moving Part so its connector origin and X axis coincide with the
 * target connector while its Z axis opposes the target Z axis.
 *
 * W1new = W2 · T2 · RflipX · inverse(T1)
 */
export function solveFastenedMate(
  movingConnector: ConnectorFrameData,
  targetConnector: ConnectorFrameData,
  targetWorld: Matrix4,
): Matrix4 {
  return new Matrix4().fromArray(
    solveFastenedMateTransform(
      movingConnector,
      targetConnector,
      targetWorld.elements,
    ),
  );
}

export function matrixAlmostEqual(
  left: Matrix4,
  right: Matrix4,
  epsilon = 1e-8,
): boolean {
  return transformsAlmostEqual(left.elements, right.elements, epsilon);
}
