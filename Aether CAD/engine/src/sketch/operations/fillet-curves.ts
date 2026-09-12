import { addFilletConstraints } from "./fillet-constraints";
import { filletConnectedCurves } from "./fillet-connected-curves";
import { validateSketchDrawing, type SketchDrawing } from "../drawing";
import type { SketchEntityRef } from "../drawing-constraints";
import { filletCurvePieces } from "../curves/fillet-pieces";
import { filletSketchLines, type FilletLine } from "./fillet-lines";
import { assertConstraintsSatisfied } from "./preserve-constraints";
/** Join two independently drawn finite curves. Existing references are never silently discarded. */
export function filletSketchCurves(
  source: SketchDrawing,
  a: FilletLine,
  b: FilletLine,
  radius: number,
): SketchDrawing {
  const first = source.contours[a.contour],
    second = source.contours[b.contour];
  if (first?.type !== "path" || second?.type !== "path")
    throw new Error("Select two finite sketch curves.");
  if (
    first.segments[a.segment]?.type === "line" &&
    second.segments[b.segment]?.type === "line"
  )
    return filletSketchLines(source, a, b, radius);
  if (a.contour === b.contour)
    return filletConnectedCurves(source, a, b, radius);
  if (
    first.segments.length !== 1 ||
    second.segments.length !== 1 ||
    a.segment !== 0 ||
    b.segment !== 0
  )
    throw new Error(
      "Curved fillets currently require two independently drawn single-segment curves.",
    );
  if (!!first.construction !== !!second.construction)
    throw new Error("Both curves must have the same construction mode.");
  const pa = a.parameter ?? 0.5,
    pb = b.parameter ?? 0.5;
  const pieces = filletCurvePieces(
    { start: first.start, segment: first.segments[0] },
    { start: second.start, segment: second.segments[0] },
    radius,
    pa,
    pb,
  );
  const lower = Math.min(a.contour, b.contour),
    upper = Math.max(a.contour, b.contour);
  const retainedA = pa < pieces.firstParameter ? 0 : 1,
    retainedB = pb < pieces.secondParameter ? 0 : 1;
  const map = (ref: SketchEntityRef): SketchEntityRef => {
    if (ref.contour !== a.contour && ref.contour !== b.contour)
      return {
        ...ref,
        contour: ref.contour > upper ? ref.contour - 1 : ref.contour,
      };
    const isA = ref.contour === a.contour;
    // Only unchanged outer endpoints and supporting circular loci survive subdivision unchanged.
    if (
      ref.kind === "point" &&
      ref.control === undefined &&
      ref.index === (isA ? retainedA : retainedB)
    )
      return { contour: lower, kind: "point", index: isA ? 0 : 3 };
    if (ref.kind === "arc" && ref.index === 0)
      return { ...ref, contour: lower, index: isA ? 0 : 2 };
    throw new Error(
      "A selected curve has a reference that requires fillet remapping. Its geometry was not changed.",
    );
  };
  const next = structuredClone(source);
  next.contours.splice(upper, 1);
  next.contours.splice(lower, 1, {
    type: "path",
    construction: first.construction,
    start: pieces.start,
    segments: pieces.segments,
  });
  next.constraints = (source.constraints ?? []).map((c) => ({
    ...c,
    a: map(c.a),
    ...(c.b ? { b: map(c.b) } : {}),
    ...(c.axis ? { axis: map(c.axis) } : {}),
  }));
  addFilletConstraints(next, lower, 0, 1, 2, radius);
  assertConstraintsSatisfied(next);
  validateSketchDrawing(next);
  return next;
}
