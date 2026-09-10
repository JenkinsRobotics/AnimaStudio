export type ExpressionValue = string | Quantity;
export interface Quantity {
  magnitudeSI: number;
  lengthPower: number;
  anglePower: number;
}
export function quantity(
  magnitudeSI: number,
  lengthPower = 0,
  anglePower = 0,
): Quantity {
  if (![magnitudeSI, lengthPower, anglePower].every(Number.isFinite))
    throw Error("Calculation must produce finite values.");
  return { magnitudeSI, lengthPower, anglePower };
}
export function numeric(value: ExpressionValue): Quantity {
  if (typeof value === "string")
    throw Error("This operation requires a quantity, not text.");
  return value;
}
export const sameUnits = (a: Quantity, b: Quantity) =>
  Math.abs(a.lengthPower - b.lengthPower) < 1e-12 &&
  Math.abs(a.anglePower - b.anglePower) < 1e-12;
export function scalar(value: ExpressionValue): number {
  const q = numeric(value);
  if (!sameUnits(q, quantity(0)))
    throw Error("This operation requires a dimensionless number.");
  return q.magnitudeSI;
}
export function expressionText(value: ExpressionValue): string {
  return typeof value === "string" ? value : String(scalar(value));
}
export const expressionUnits: Readonly<Record<string, Quantity>> =
  Object.freeze({
    mm: quantity(0.001, 1),
    cm: quantity(0.01, 1),
    m: quantity(1, 1),
    in: quantity(0.0254, 1),
    ft: quantity(0.3048, 1),
    deg: quantity(Math.PI / 180, 0, 1),
    rad: quantity(1, 0, 1),
  });
