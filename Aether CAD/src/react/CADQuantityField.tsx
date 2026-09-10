import { useSyncExternalStore } from "react";
import { NumberField, type NumberFieldProps } from "@aether/ui";
import { unitChoice, type UnitFamily } from "@aether/core/units";
import { documentUnits, subscribeDocumentUnits } from "../document-preferences";
/** Editor units are preferences; its callers always keep their canonical contract units. */
export function CADQuantityField({
  family,
  canonicalFactor = 1,
  value,
  defaultValue,
  min,
  max,
  step,
  onValueChange,
  onCommit,
  onCancel,
  ...props
}: Omit<NumberFieldProps, "unit"> & {
  family: UnitFamily;
  canonicalFactor?: number;
}) {
  const preferences = useSyncExternalStore(
    subscribeDocumentUnits,
    documentUnits,
    documentUnits,
  );
  const choice = unitChoice(preferences, family),
    factor = choice.factor / canonicalFactor;
  return (
    <NumberField
      {...props}
      unit={choice.unit}
      precision={choice.decimals}
      value={
        value === null ? null : value === undefined ? undefined : value / factor
      }
      defaultValue={
        defaultValue === undefined ? undefined : defaultValue / factor
      }
      min={min === undefined ? undefined : min / factor}
      max={max === undefined ? undefined : max / factor}
      step={step === undefined ? undefined : step / factor}
      onValueChange={(v) => onValueChange?.(v === null ? null : v * factor)}
      onCommit={(v) => onCommit?.(v * factor)}
      onCancel={(v) => onCancel?.(v === null ? null : v * factor)}
    />
  );
}
