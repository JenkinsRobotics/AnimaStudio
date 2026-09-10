import type { UnitPreferences } from "@aether/core/units";
let units: UnitPreferences = {};
const listeners = new Set<() => void>();
export function documentUnits() {
  return units;
}
export function subscribeDocumentUnits(listener: () => void) {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
}
export function applyDocumentUnits(value: UnitPreferences) {
  units = value;
  listeners.forEach((listener) => listener());
}
