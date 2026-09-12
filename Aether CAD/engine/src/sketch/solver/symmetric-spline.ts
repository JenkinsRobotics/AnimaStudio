import {
  contourClosed,
  type SketchContour,
  type SketchPoint,
} from "../drawing";
/** Bézier control-polygon reflection is exact curve reflection, not sampled fitting. */
export function symmetricSplineResiduals(
  a: SketchContour,
  b: SketchContour,
  reflect: (p: SketchPoint) => SketchPoint,
  reversed = false,
): number[] {
  if (
    a.type !== "path" ||
    b.type !== "path" ||
    !a.segments.length ||
    a.segments.length !== b.segments.length ||
    [...a.segments, ...b.segments].some((s) => s.type !== "bezier") ||
    contourClosed(a) !== contourClosed(b)
  )
    throw Error(
      "Spline symmetry requires two Bezier contours with matching segment counts and closure.",
    );
  const points = (path: typeof a) => [
    path.start,
    ...path.segments.flatMap((s) =>
      s.type === "bezier" ? [...s.controls, s.end] : [],
    ),
  ];
  const source = points(a),
    target = points(b);
  if (reversed) target.reverse();
  if (contourClosed(a)) {
    source.pop();
    target.pop();
  }
  return source.flatMap((point, i) => {
    const expected = reflect(point);
    return [target[i][0] - expected[0], target[i][1] - expected[1]];
  });
}
