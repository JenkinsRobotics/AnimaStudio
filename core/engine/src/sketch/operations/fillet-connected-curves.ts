import {
  contourClosed,
  validateSketchDrawing,
  type SketchDrawing,
} from "../drawing";
import type { SketchEntityRef } from "../drawing-constraints";
import { filletCurvePieces } from "../curves/fillet-pieces";
import type { FilletLine } from "./fillet-lines";
import { addFilletConstraints } from "./fillet-constraints";
import { assertConstraintsSatisfied } from "./preserve-constraints";
/** Round an adjacent curved corner without replacing the surrounding path. */
export function filletConnectedCurves(
  source: SketchDrawing,
  a: FilletLine,
  b: FilletLine,
  radius: number,
): SketchDrawing {
  const path = source.contours[a.contour];
  if (a.contour !== b.contour || path?.type !== "path")
    throw new Error("Select adjacent curves in one path.");
  const count = path.segments.length,
    lo = Math.min(a.segment, b.segment),
    hi = Math.max(a.segment, b.segment);
  if (
    !Number.isInteger(lo) ||
    !Number.isInteger(hi) ||
    lo < 0 ||
    hi >= count ||
    lo === hi
  )
    throw new Error("Select two different path segments.");
  const lowPick = (a.segment === lo ? a.parameter : b.parameter) ?? 0.5,
    highPick = (a.segment === hi ? a.parameter : b.parameter) ?? 0.5;
  // A two-segment loop has two shared corners; retained-side picks disambiguate them.
  const seam =
    lo === 0 &&
    hi === count - 1 &&
    contourClosed(path) &&
    (count > 2 || lowPick > highPick);
  if (!seam && hi !== lo + 1)
    throw new Error("Select adjacent curves sharing a corner.");
  const incoming = seam ? hi : lo,
    outgoing = seam ? 0 : hi;
  const firstStart =
    incoming === 0 ? path.start : path.segments[incoming - 1].end;
  const secondStart =
    outgoing === 0 ? path.start : path.segments[outgoing - 1].end;
  // Connected corners keep the outer ends, regardless of selection order.
  const pieces = filletCurvePieces(
    { start: firstStart, segment: path.segments[incoming] },
    { start: secondStart, segment: path.segments[outgoing] },
    radius,
    0,
    1,
  );
  const next = structuredClone(source),
    result = next.contours[a.contour];
  if (result.type !== "path") throw Error("Expected path.");
  const arc = seam ? count : outgoing;
  if (seam) {
    result.start = pieces.segments[1].end;
    result.segments[incoming] = pieces.segments[0];
    result.segments[0] = pieces.segments[2];
    result.segments.push(pieces.segments[1]);
  } else result.segments.splice(incoming, 2, ...pieces.segments);
  const map = (ref: SketchEntityRef): SketchEntityRef => {
    if (ref.contour !== a.contour) return { ...ref };
    const i = ref.index;
    if (i === undefined) return { ...ref };
    if (ref.kind === "point" && ref.control === undefined) {
      if (i === outgoing || (seam && i === count))
        throw new Error(
          "The corner has a point constraint that requires virtual-sharp remapping. Its geometry was not changed.",
        );
      return { ...ref, index: !seam && i > outgoing ? i + 1 : i };
    }
    if ((i === incoming || i === outgoing) && ref.kind === "curve") {
      const lo = i === incoming ? 0 : pieces.secondParameter,
        hi = i === incoming ? pieces.firstParameter : 1,
        t = ref.parameter;
      if (t === undefined || t < lo - 1e-9 || t > hi + 1e-9)
        throw new Error("The fillet would remove a referenced curve contact.");
      return {
        ...ref,
        index: !seam && i >= outgoing ? i + 1 : i,
        parameter: Math.max(0, Math.min(1, (t - lo) / (hi - lo))),
      };
    }
    if ((i === incoming || i === outgoing) && ref.kind !== "arc")
      throw new Error(
        "A trimmed curve reference requires fillet remapping. Its geometry was not changed.",
      );
    return { ...ref, index: !seam && i >= outgoing ? i + 1 : i };
  };
  next.constraints = (source.constraints ?? []).map((c) => ({
    ...c,
    a: map(c.a),
    ...(c.b ? { b: map(c.b) } : {}),
    ...(c.axis ? { axis: map(c.axis) } : {}),
  }));
  addFilletConstraints(
    next,
    a.contour,
    incoming,
    arc,
    seam ? 0 : outgoing + 1,
    radius,
  );
  assertConstraintsSatisfied(next);
  validateSketchDrawing(next);
  return next;
}
