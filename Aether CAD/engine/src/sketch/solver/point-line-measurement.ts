import type { SketchPoint } from "../drawing";
/** Perpendicular distance to the supporting infinite line, not its endpoints. */
export function pointLineMeasurement(
  point: SketchPoint,
  line: [SketchPoint, SketchPoint],
) {
  const dx = line[1][0] - line[0][0],
    dy = line[1][1] - line[0][1],
    length = Math.hypot(dx, dy);
  if (length < 1e-10) throw Error("Select a nonzero-length line for distance.");
  const ux = dx / length,
    uy = dy / length,
    along = (point[0] - line[0][0]) * ux + (point[1] - line[0][1]) * uy;
  const foot: SketchPoint = [line[0][0] + along * ux, line[0][1] + along * uy];
  return {
    foot,
    distance: Math.abs(
      (point[0] - line[0][0]) * uy - (point[1] - line[0][1]) * ux,
    ),
  };
}
