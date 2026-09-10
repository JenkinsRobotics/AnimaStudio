import {
  filletRadiusHandle,
  filletRadiusFromHandle,
} from "@aether/core/sketch";
import { mountDimensionManipulator } from "./dimension-manipulator";
export function mountFilletManipulator(
  svg: SVGSVGElement,
  setRadius: (value: number) => void,
  report: (message: string) => void,
) {
  return mountDimensionManipulator(
    svg,
    setRadius,
    report,
    filletRadiusHandle,
    "sketch-fillet-handle",
    "Fillet radius handle",
    {
      value: (h) => h.radius,
      project: filletRadiusFromHandle,
      step: (value, direction) => value * (direction > 0 ? 1.1 : 1 / 1.1),
      minimum: 0,
    },
  );
}
