/** Editor metadata only. The kernel and constraint solver must ignore it. */
export interface SketchPresentation {
  dimensionLabelPositionsMillimeters: Record<string, [number, number]>;
}
export function validateSketchPresentation(value: unknown): void {
  if (value === undefined) return;
  if (!value || typeof value !== "object" || Array.isArray(value))
    throw Error("Invalid sketch presentation metadata.");
  for (const item of Object.values(value)) {
    const positions = item?.dimensionLabelPositionsMillimeters;
    if (!positions || typeof positions !== "object" || Array.isArray(positions))
      throw Error("Invalid dimension label positions.");
    for (const point of Object.values(positions))
      if (
        !Array.isArray(point) ||
        point.length !== 2 ||
        !point.every((n) => typeof n === "number" && Number.isFinite(n))
      )
        throw Error("Dimension label coordinates must be finite millimeters.");
  }
}
