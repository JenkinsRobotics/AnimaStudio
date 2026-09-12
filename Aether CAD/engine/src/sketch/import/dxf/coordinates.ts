import { numberTag, type DxfTag } from "./tags";
import { transformContour } from "../../curves/similarity";
import type { SketchContour } from "../../drawing";

/** Planar subset of Autodesk's arbitrary-axis convention: -Z gives -X,+Y.
 * LINE/POINT/SPLINE positions are WCS; ellipse centers/major axes are also WCS,
 * but their minor-axis direction follows the extrusion normal. */
export function dxfCoordinates(type: string, tags: DxfTag[]) {
  const n = (code: number, fallback: number) => numberTag(tags, code, fallback);
  for (const code of [30, 31, 32, 33, 38, 39])
    if (n(code, 0) !== 0)
      throw Error(
        `${type}: non-planar/extruded DXF geometry is not supported yet.`,
      );
  const nx = n(210, 0),
    ny = n(220, 0),
    nz = n(230, 1);
  if (Math.hypot(nx, ny, nz) === 0)
    throw Error(`${type}: DXF normal must be nonzero.`);
  const world = ["LINE", "POINT", "SPLINE"].includes(type);
  if (!world && (nx !== 0 || ny !== 0))
    throw Error(
      `${type}: tilted DXF object coordinates are not supported yet.`,
    );
  const normalSign = nz < 0 ? -1 : 1;
  return {
    normalSign,
    toWorld(contour: SketchContour): SketchContour {
      if (world || type === "ELLIPSE" || normalSign > 0) return contour;
      return transformContour(contour, {
        a: -1,
        b: 0,
        c: 0,
        d: 1,
        tx: 0,
        ty: 0,
      });
    },
  };
}
