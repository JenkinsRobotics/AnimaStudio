import {
  ellipseSnapPoints,
  centerSnapPoints,
  midpointSnapPoints,
  projectedSnapPoints,
  projectedCurveSnap,
} from "@aether/core/sketch";
import type { SketchDrawing, SketchPoint } from "@aether/core/sketch";
export function snapSketchPoint(
  raw: SketchPoint,
  d: SketchDrawing,
  anchor: SketchPoint | undefined,
  tolerance: number,
  grid = true,
): { point: SketchPoint; label: string } {
  const candidates: { point: SketchPoint; label: string }[] = [
    { point: [0, 0], label: "Origin" },
  ];
  for (const c of d.contours) {
    if (c.type === "path") {
      candidates.push({ point: c.start, label: "Endpoint" });
      for (const s of c.segments)
        candidates.push({ point: s.end, label: "Endpoint" });
    }
  }
  for (const snap of midpointSnapPoints(d))
    candidates.push({ point: snap.point, label: "Midpoint" });
  for (const snap of centerSnapPoints(d))
    candidates.push({
      point: snap.point,
      label: snap.ref.kind === "arc" ? "Arc center" : "Center",
    });
  for (const snap of ellipseSnapPoints(d))
    candidates.push({ point: snap.point, label: "Quadrant" });
  for (const snap of projectedSnapPoints(d))
    candidates.push({ point: snap.point, label: snap.label });
  const distance = (p: SketchPoint) => Math.hypot(p[0] - raw[0], p[1] - raw[1]);
  const nearest = candidates
    .filter((c) => distance(c.point) <= tolerance)
    .sort(
      (a, b) =>
        distance(a.point) - distance(b.point) ||
        Number(b.label === "Quadrant") - Number(a.label === "Quadrant"),
    )[0];
  if (nearest) return { point: [...nearest.point], label: nearest.label };
  const curve = projectedCurveSnap(d, raw, tolerance);
  if (curve) return { point: curve.point, label: curve.label };
  const p: SketchPoint = grid
    ? [Math.round(raw[0]), Math.round(raw[1])]
    : [...raw];
  if (anchor) {
    if (Math.abs(raw[0] - anchor[0]) <= tolerance)
      return { point: [anchor[0], p[1]], label: "Vertical" };
    if (Math.abs(raw[1] - anchor[1]) <= tolerance)
      return { point: [p[0], anchor[1]], label: "Horizontal" };
  }
  return { point: p, label: grid ? "Grid · 1 mm" : "" };
}
