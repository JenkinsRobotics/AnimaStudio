import type { ConnectorKind, Vec3 } from "../contracts/index";

export type AxisStationRole = "start" | "center" | "end";

export interface AxisStation {
  role: AxisStationRole;
  parameter: number;
}

/** Returns the useful axial stations of a trimmed analytic cylinder. */
export function cylinderAxisStations(
  firstV: number,
  lastV: number,
  tolerance = 1e-9,
): AxisStation[] {
  if (!Number.isFinite(firstV) || !Number.isFinite(lastV)) {
    return [{ role: "center", parameter: 0 }];
  }

  const center = (firstV + lastV) / 2;
  if (Math.abs(lastV - firstV) <= tolerance) {
    return [{ role: "center", parameter: center }];
  }

  return [
    { role: "start", parameter: firstV },
    { role: "center", parameter: center },
    { role: "end", parameter: lastV },
  ];
}

export function sameOrigin(a: Vec3, b: Vec3, tolerance = 1e-7): boolean {
  return Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2]) < tolerance;
}

/** Lower values win when two feature descriptions occupy one exact point. */
export function connectorKindPreference(kind: ConnectorKind): number {
  switch (kind) {
    case "cylinder-axis":
    case "cone-axis":
    case "sphere-center":
    case "torus-center":
      return 0;
    case "circle-center":
    case "ellipse-center":
      return 1;
    case "vertex":
      return 2;
    case "edge-midpoint":
      return 3;
    case "face-center":
      return 4;
  }
}
