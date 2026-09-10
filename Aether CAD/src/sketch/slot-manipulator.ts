import { slotWidthHandle, slotWidthFromHandle } from "@aether/core/sketch";
import { mountDimensionManipulator } from "./dimension-manipulator";
export function mountSlotManipulator(
  svg: SVGSVGElement,
  setWidth: (value: number) => void,
  report: (message: string) => void,
) {
  return mountDimensionManipulator(
    svg,
    setWidth,
    report,
    slotWidthHandle,
    "sketch-slot-handle",
    "Slot width handle",
    {
      value: (h) => h.width,
      project: slotWidthFromHandle,
      minimum: 0,
      step: (value, direction) => value * (direction > 0 ? 1.1 : 1 / 1.1),
    },
  );
}
