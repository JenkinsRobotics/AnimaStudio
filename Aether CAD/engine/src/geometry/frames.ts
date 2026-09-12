import type { ConnectorCandidate, Vec3 } from "../contracts/index";

export type ConnectorAxes = Pick<
  ConnectorCandidate,
  "xAxis" | "yAxis" | "zAxis"
>;

export function pointTuple(point: {
  X(): number;
  Y(): number;
  Z(): number;
}): Vec3 {
  return [point.X(), point.Y(), point.Z()];
}

export function deleteAfterPointTuple(point: {
  X(): number;
  Y(): number;
  Z(): number;
  delete(): void;
}): Vec3 {
  try {
    return pointTuple(point);
  } finally {
    point.delete();
  }
}

export function deleteAfterVectorTuple(vector: {
  toTuple(): Vec3;
  delete(): void;
}): Vec3 {
  try {
    return vector.toTuple();
  } finally {
    vector.delete();
  }
}

export function pointAlongAxis(
  origin: Vec3,
  direction: Vec3,
  distance: number,
): Vec3 {
  return [
    origin[0] + direction[0] * distance,
    origin[1] + direction[1] * distance,
    origin[2] + direction[2] * distance,
  ];
}

function cross(a: Vec3, b: Vec3): Vec3 {
  return [
    a[1] * b[2] - a[2] * b[1],
    a[2] * b[0] - a[0] * b[2],
    a[0] * b[1] - a[1] * b[0],
  ];
}

function dot(a: Vec3, b: Vec3): number {
  return a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
}

function normalize(value: Vec3): Vec3 {
  const length = Math.hypot(value[0], value[1], value[2]);
  if (length < 1e-12) return [1, 0, 0];
  return [value[0] / length, value[1] / length, value[2] / length];
}

/** Builds a right-handed connector frame with the requested primary Z axis. */
export function connectorAxes(
  zInput: Vec3,
  preferredX: Vec3,
): ConnectorAxes {
  const zAxis = normalize(zInput);
  const projected: Vec3 = [
    preferredX[0] - zAxis[0] * dot(preferredX, zAxis),
    preferredX[1] - zAxis[1] * dot(preferredX, zAxis),
    preferredX[2] - zAxis[2] * dot(preferredX, zAxis),
  ];
  const fallback: Vec3 = Math.abs(zAxis[0]) < 0.8 ? [1, 0, 0] : [0, 1, 0];
  const xAxis = normalize(
    Math.hypot(...projected) > 1e-8 ? projected : fallback,
  );
  const yAxis = normalize(cross(zAxis, xAxis));
  return { xAxis: normalize(cross(yAxis, zAxis)), yAxis, zAxis };
}
