import { preserveRemovedDimensionDrivers } from "../solver/dimension-links";
import type { SketchDrawing } from "../drawing";
/** Deletion removes only constraints referencing removed geometry and remaps the rest. */
export function deleteSketchContour(
  source: SketchDrawing,
  index: number,
): SketchDrawing {
  if (!Number.isInteger(index) || !source.contours[index])
    throw new Error("Select an existing contour.");
  const drawing = structuredClone(source);
  drawing.contours.splice(index, 1);
  drawing.constraints = drawing.constraints
    ?.filter((c) => c.a.contour !== index && c.b?.contour !== index && c.axis?.contour !== index)
    .map((c) => ({
      ...c,
      ...(c.axis ? {axis:{...c.axis,contour:c.axis.contour > index ? c.axis.contour-1 : c.axis.contour}} : {}),
      a: {
        ...c.a,
        contour: c.a.contour > index ? c.a.contour - 1 : c.a.contour,
      },
      ...(c.b
        ? {
            b: {
              ...c.b,
              contour: c.b.contour > index ? c.b.contour - 1 : c.b.contour,
            },
          }
        : {}),
    }));
  preserveRemovedDimensionDrivers(source, drawing);
  return drawing;
}
