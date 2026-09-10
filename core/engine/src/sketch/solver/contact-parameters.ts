import type { SketchDrawing } from "../drawing";
/** Each relation owns its contact parameters; they are solver variables, not geometry. */
export function contactParameterCoordinates(d: SketchDrawing) {
  const coordinates: {
    get: () => number;
    set: (v: number) => void;
    differenceStep?: () => number;
  }[] = [];
  for (const c of d.constraints ?? [])
    for (const ref of [c.a, c.b]) {
      if (ref?.sliding === undefined) continue;
      if (
        typeof ref.sliding !== "boolean" ||
        ref.kind !== "curve" ||
        !["coincident", "tangent", "curvature", "normal"].includes(c.kind)
      )
        throw Error("Sliding parameters require a curve contact constraint.");
      if (!ref.sliding) continue;
      if (
        ref.parameter === undefined ||
        !Number.isFinite(ref.parameter) ||
        ref.parameter < 0 ||
        ref.parameter > 1
      )
        throw Error("Curve contact parameter must be between zero and one.");
      coordinates.push({
        get: () => ref.parameter!,
        set: (v) => {
          ref.parameter = Math.max(0, Math.min(1, v));
        },
        differenceStep: () => (ref.parameter! > 0.5 ? -1e-5 : 1e-5),
      });
    }
  return coordinates;
}
