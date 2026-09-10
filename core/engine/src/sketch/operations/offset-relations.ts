import {
  identifySegmentReference,
  resolveSegmentReference,
} from "../solver/segment-reference";
import type { SketchEntityRef } from "../solver/types";
import type { SketchDrawing } from "../drawing";

/** Append canonical relations to a draft whose offset contours follow source contours. */
export function appendOffsetRelations(
  source: SketchDrawing,
  next: SketchDrawing,
  unique: number[],
  distance: number,
): void {
  // Ordinary saved constraints keep supported simple offsets associative.
  // Complex chains retain geometry until their corner correspondence is modeled.
  let driver: string | undefined;
  unique.forEach((index, position) => {
    const contour = source.contours[index];
    const kind =
      contour.type === "circle"
        ? "circle"
        : contour.segments.length === 1 &&
            (contour.segments[0].type === "line" ||
              contour.segments[0].type === "arc")
          ? contour.segments[0].type
          : contour.segments.length > 1 &&
              contour.segments.every(
                (s) => s.type === "line" || s.type === "arc",
              )
            ? "contour"
            : undefined;
    if (!kind) return;
    const id = appendOffsetRelation(
      next,
      {
        contour: index,
        kind,
        ...(kind !== "circle" && kind !== "contour" ? { index: 0 } : {}),
      },
      {
        contour: source.contours.length + position,
        kind,
        ...(kind !== "circle" && kind !== "contour" ? { index: 0 } : {}),
      },
      distance,
      driver,
    );
    driver ??= id;
  });
}

/** Shared relation constructor for whole contours and individual source edges. */
export function appendOffsetRelation(
  next: SketchDrawing,
  a: SketchEntityRef,
  b: SketchEntityRef,
  distance: number,
  driver?: string,
): string {
  for (const key of ["a", "b"] as const) {
    const ref = key === "a" ? a : b,
      contour = next.contours[ref.contour];
    if (!contour) continue;
    const captured = identifySegmentReference(
      contour,
      resolveSegmentReference(contour, ref),
    );
    if (key === "a") a = captured;
    else b = captured;
  }
  const used = new Set(next.constraints?.map((c) => c.id));
  let n = 1;
  while (used.has(`offset-${n}`)) n++;
  const id = `offset-${n}`;
  (next.constraints ??= []).push({
    id,
    kind: "offset",
    a,
    b,
    ...(driver ? { valueFrom: driver } : { value: distance }),
  });
  return id;
}
