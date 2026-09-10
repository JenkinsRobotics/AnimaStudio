import type { ConnectorFrameData, Vec3 } from "../contracts/index";

/** Column-major homogeneous 4x4 transform, matching OpenGL/WebGPU conventions. */
export type TransformMatrix = readonly number[];

export const identityTransform: TransformMatrix = [
  1, 0, 0, 0,
  0, 1, 0, 0,
  0, 0, 1, 0,
  0, 0, 0, 1,
];

function assertMatrix(matrix: TransformMatrix): void {
  if (matrix.length !== 16 || matrix.some((value) => !Number.isFinite(value))) {
    throw new Error("Aether transforms require 16 finite column-major values.");
  }
}

function cross(a: Vec3, b: Vec3): Vec3 {
  return [
    a[1] * b[2] - a[2] * b[1],
    a[2] * b[0] - a[0] * b[2],
    a[0] * b[1] - a[1] * b[0],
  ];
}

function normalize(value: Vec3, label: string): Vec3 {
  const length = Math.hypot(value[0], value[1], value[2]);
  if (length < 1e-12) throw new Error(`${label} axis has zero length.`);
  return [value[0] / length, value[1] / length, value[2] / length];
}

export function connectorTransform(frame: ConnectorFrameData): TransformMatrix {
  const xInput = normalize(frame.xAxis, "Connector X");
  const zAxis = normalize(frame.zAxis, "Connector Z");
  const yAxis = normalize(cross(zAxis, xInput), "Connector Y");
  const xAxis = normalize(cross(yAxis, zAxis), "Connector X");
  const [x, y, z] = frame.origin;
  if (![x, y, z].every(Number.isFinite)) {
    throw new Error("Connector origin must be finite.");
  }
  return [
    xAxis[0], xAxis[1], xAxis[2], 0,
    yAxis[0], yAxis[1], yAxis[2], 0,
    zAxis[0], zAxis[1], zAxis[2], 0,
    x, y, z, 1,
  ];
}

export function multiplyTransforms(
  left: TransformMatrix,
  right: TransformMatrix,
): TransformMatrix {
  assertMatrix(left);
  assertMatrix(right);
  const result = new Array<number>(16).fill(0);
  for (let column = 0; column < 4; column += 1) {
    for (let row = 0; row < 4; row += 1) {
      let value = 0;
      for (let index = 0; index < 4; index += 1) {
        value += left[index * 4 + row] * right[column * 4 + index];
      }
      result[column * 4 + row] = value;
    }
  }
  return result;
}

/** Inverts a rigid transform. Scale and shear are intentionally unsupported. */
export function invertRigidTransform(matrix: TransformMatrix): TransformMatrix {
  assertMatrix(matrix);
  const tx = matrix[12];
  const ty = matrix[13];
  const tz = matrix[14];
  return [
    matrix[0], matrix[4], matrix[8], 0,
    matrix[1], matrix[5], matrix[9], 0,
    matrix[2], matrix[6], matrix[10], 0,
    -(matrix[0] * tx + matrix[1] * ty + matrix[2] * tz),
    -(matrix[4] * tx + matrix[5] * ty + matrix[6] * tz),
    -(matrix[8] * tx + matrix[9] * ty + matrix[10] * tz),
    1,
  ];
}

export function rotationXTransform(angleRadians: number): TransformMatrix {
  if (!Number.isFinite(angleRadians)) {
    throw new Error("Rotation angle must be finite.");
  }
  const cosine = Math.cos(angleRadians);
  const sine = Math.sin(angleRadians);
  return [
    1, 0, 0, 0,
    0, cosine, sine, 0,
    0, -sine, cosine, 0,
    0, 0, 0, 1,
  ];
}

/**
 * Places the moving Part so connector origins and X axes coincide while their
 * primary Z axes oppose: W1new = W2 · T2 · RflipX · inverse(T1).
 */
export function solveFastenedMateTransform(
  movingConnector: ConnectorFrameData,
  targetConnector: ConnectorFrameData,
  targetWorld: TransformMatrix = identityTransform,
): TransformMatrix {
  return multiplyTransforms(
    multiplyTransforms(
      multiplyTransforms(targetWorld, connectorTransform(targetConnector)),
      rotationXTransform(Math.PI),
    ),
    invertRigidTransform(connectorTransform(movingConnector)),
  );
}

export function transformsAlmostEqual(
  left: TransformMatrix,
  right: TransformMatrix,
  epsilon = 1e-8,
): boolean {
  assertMatrix(left);
  assertMatrix(right);
  return left.every(
    (value, index) => Math.abs(value - right[index]) <= epsilon,
  );
}
