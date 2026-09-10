import type { resolve } from "./entities";
type Entity = ReturnType<typeof resolve>;
/** A line normal to a circle passes through its center. For a finite curve
 * contact, require incidence on the line and perpendicular tangent directions.
 * Line extents are intentionally not constrained, as with other sketch loci.
 */
export function normalResiduals(a: Entity, b?: Entity): number[] {
  const line = a.line ?? b?.line;
  const curve = a.line ? b : a;
  if (!line || (!curve?.circle && !curve?.curve))
    throw new Error(
      "Normal requires a line and a circle/arc or finite curve contact.",
    );
  const dx = line[1][0] - line[0][0],
    dy = line[1][1] - line[0][1];
  const length = Math.hypot(dx, dy);
  if (length < 1e-10)
    throw new Error("A zero-length line has no normal direction.");
  const x = dx / length,
    y = dy / length;
  const point = curve.circle?.center ?? curve.curve!.point;
  const incidence = (point[0] - line[0][0]) * y - (point[1] - line[0][1]) * x;
  if (curve.circle) return [incidence];
  const jet = curve.curve!,
    speed = Math.hypot(...jet.first);
  if (speed < 1e-10)
    throw new Error("A stationary curve point has no normal direction.");
  return [incidence, (x * jet.first[0] + y * jet.first[1]) / speed];
}
