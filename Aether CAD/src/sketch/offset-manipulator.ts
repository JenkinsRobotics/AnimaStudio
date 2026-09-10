import {
  offsetDistanceHandle,
  offsetDistanceFromHandle,
} from "@aether/core/sketch";
import { mountDimensionManipulator } from "./dimension-manipulator";
export function mountOffsetManipulator(
  svg: SVGSVGElement,
  setDistance: (value: number) => void,
  report: (message: string) => void,
) {
  return mountDimensionManipulator(
    svg,
    setDistance,
    report,
    offsetDistanceHandle,
    "sketch-offset-handle",
    "Offset distance handle",
    {
      value: (h) => h.distance,
      project: offsetDistanceFromHandle,
      step: (value, direction) =>
        value + direction * Math.max(0.1, Math.abs(value) * 0.1),
    },
  );
}
