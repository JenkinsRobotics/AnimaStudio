import { contourClosed, type SketchContour } from "../drawing";
import { transformContour, type SketchTransform } from "../curves/similarity";
import { diagnosticCoordinates } from "./diagnostic-coordinates";
/** Independent contour coordinates avoid redundant closure and arc through-point equations. */
export function patternResiduals(
  source: SketchContour | undefined,
  target: SketchContour | undefined,
  transform: SketchTransform | undefined,
): number[] {
  if (!source || !target || !transform)
    throw Error(
      "Pattern relation needs source and instance contours and a transform.",
    );
  const expected = transformContour(source, transform);
  if (
    expected.type !== target.type ||
    contourClosed(expected) !== contourClosed(target)
  )
    throw Error(
      "Pattern topology changed; detach the instance before changing its topology.",
    );
  if (expected.type === "path" && target.type === "path") {
    if (
      expected.segments.length !== target.segments.length ||
      expected.segments.some((s, i) => s.type !== target.segments[i].type)
    )
      throw Error(
        "Pattern topology changed; detach the instance before changing its topology.",
      );
    expected.segments.forEach((s, i) => {
      const t = target.segments[i];
      if (s.type === "ellipse" && t.type === "ellipse") {
        if (s.sweep !== t.sweep || s.largeArc !== t.largeArc)
          throw Error("Pattern ellipse branch changed.");
        s.rotationDegrees =
          t.rotationDegrees +
          ((((s.rotationDegrees - t.rotationDegrees + 180) % 360) + 360) %
            360) -
          180;
      }
    });
  }
  const coordinates = (c: SketchContour) =>
    diagnosticCoordinates({
      type: "drawing",
      contours: [structuredClone(c)],
    }).map((v) => v.get());
  const a = coordinates(expected),
    b = coordinates(target);
  return b.map((value, i) => value - a[i]);
}
