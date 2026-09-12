import { polynomialBSpline } from "../../curves/bspline";
import type { SketchContour, SketchPoint } from "../../drawing";
import { numberTag, type DxfTag } from "./tags";

/** DXF SPLINE controls are WCS coordinates. Fit points are authoring metadata
 * when a valid control net exists; fit-only entities need a separate fitter. */
export function dxfSpline(tags: DxfTag[], scale: number): SketchContour {
  const values = (code: number) =>
    tags.filter((t) => t.code === code).map((t) => numberTag([t], code));
  const flags = numberTag(tags, 70, 0),
    degree = numberTag(tags, 71);
  if (!Number.isInteger(flags) || flags < 0 || flags > 31)
    throw Error("Invalid DXF spline flags.");
  const xs = values(10),
    ys = values(20),
    zs = values(30),
    knots = values(40),
    weights = values(41);
  if (
    xs.length !== numberTag(tags, 73) ||
    ys.length !== xs.length ||
    (zs.length !== 0 && zs.length !== xs.length) ||
    knots.length !== numberTag(tags, 72)
  )
    throw Error("DXF spline knot/control counts do not match the data.");
  if (zs.some((z) => z !== 0))
    throw Error("Non-planar DXF splines are not supported yet.");
  if (
    weights.length &&
    (weights.length !== xs.length ||
      weights.some((w) => w <= 0 || w !== weights[0]))
  )
    throw Error(
      "Rational DXF splines with unequal weights need native rational-curve support.",
    );
  const controls: SketchPoint[] = xs.map((x, i) => [x * scale, ys[i] * scale]);
  const contour = polynomialBSpline(degree, knots, controls);
  if (contour.type !== "path") throw Error("Invalid spline conversion.");
  if (flags & 3) {
    const end = contour.segments.at(-1)!.end;
    if (Math.hypot(end[0] - contour.start[0], end[1] - contour.start[1]) > 1e-7)
      throw Error(
        "Closed/periodic DXF spline does not close within sketch tolerance.",
      );
    contour.segments.at(-1)!.end = [...contour.start];
  }
  return contour;
}
