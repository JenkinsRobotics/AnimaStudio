import { evaluateQuantityExpression } from "./quantity-expression";
export { evaluateQuantityExpression } from "./quantity-expression";
// The CAD unit catalog is genuinely shared: this engine and the server's
// animacore/cad_document.py both read it, so it stays in core/assets/ per the
// suite contract. ponytail: the only path out of this package — if a third
// consumer appears, give the catalog a typed module instead of a raw import.
import catalog from "../../../core/assets/cad/units.json";
export const unitCatalog = catalog;
export type UnitFamily = keyof typeof catalog;
export type UnitPreferences = Partial<
  Record<UnitFamily, { unit: string; decimals: number }>
>;
export function unitChoice(preferences: UnitPreferences, family: UnitFamily) {
  const definition = catalog[family];
  const value = preferences[family];
  const factors = definition.options as Record<string, number>;
  const unit =
    value && factors[value.unit] !== undefined
      ? value.unit
      : definition.default;
  return {
    unit,
    factor: factors[unit],
    decimals: Math.max(0, Math.min(8, value?.decimals ?? 3)),
  };
}
export function displayQuantity(
  si: number,
  preferences: UnitPreferences,
  family: UnitFamily,
): string {
  const choice = unitChoice(preferences, family);
  return (si / choice.factor).toFixed(choice.decimals);
}
export function parseQuantity(
  value: string,
  preferences: UnitPreferences,
  family: UnitFamily,
): number {
  const number = evaluateQuantityExpression(value);
  if (!value.trim() || !Number.isFinite(number))
    throw new Error("Enter a finite numeric quantity.");
  return number * unitChoice(preferences, family).factor;
}
