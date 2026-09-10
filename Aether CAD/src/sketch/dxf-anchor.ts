import {
  centerSnapPoints,
  midpointSnapPoints,
  ellipseSnapPoints,
  sketchEntities,
  sketchEntityPoint,
  type SketchDrawing,
  type SketchPoint,
} from "@aether/core/sketch";
/** Source geometry has already been converted to millimeters by the importer. */
export function dxfAnchorChoices(
  d: SketchDrawing,
): { label: string; point: SketchPoint }[] {
  const choices: { label: string; point: SketchPoint }[] = [
      { label: "File origin", point: [0, 0] },
    ],
    seen = new Set(["0,0"]);
  const add = (label: string, p: SketchPoint) => {
    const key = p.map((v) => Math.round(v * 1e8) / 1e8).join(",");
    if (seen.has(key)) return;
    seen.add(key);
    choices.push({ label, point: [...p] });
  };
  for (const { ref, label } of sketchEntities(d)) {
    if (ref.kind !== "point" || ref.control !== undefined) continue;
    const p = sketchEntityPoint(d, ref);
    if (p) add(label, p);
  }
  for (const s of centerSnapPoints(d))
    add(`${s.ref.contour + 1}: Center`, s.point);
  for (const s of midpointSnapPoints(d)) add("Edge midpoint", s.point);
  for (const s of ellipseSnapPoints(d)) add("Ellipse quadrant", s.point);
  return choices;
}
