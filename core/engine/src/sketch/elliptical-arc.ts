import type { SketchContour, SketchPoint } from "./drawing";

/** Center, primary radius point, then a point on the ellipse fixing its second radius. */
function frame(
  points: SketchPoint[],
  secondaryRadiusMillimeters?: number,
  rememberedRadiusMillimeters?: number,
) {
  if (
    points.length < 3 ||
    !points.every((p) => p.length === 2 && p.every(Number.isFinite))
  )
    throw Error("Choose finite ellipse construction points.");
  const [center, primary, start] = points;
  const dx = primary[0] - center[0],
    dy = primary[1] - center[1],
    rx = Math.hypot(dx, dy);
  if (rx < 1e-8) throw Error("Choose a nonzero primary radius.");
  const ux = dx / rx,
    uy = dy / rx;
  const local = (p: SketchPoint): SketchPoint => [
    (p[0] - center[0]) * ux + (p[1] - center[1]) * uy,
    -(p[0] - center[0]) * uy + (p[1] - center[1]) * ux,
  ];
  const [x, y] = local(start),
    denominator = 1 - (x / rx) ** 2;
  const chosenRadius =
    secondaryRadiusMillimeters ??
    (Math.abs(y) < 1e-8 ? rememberedRadiusMillimeters : undefined);
  if (
    chosenRadius === undefined &&
    (denominator <= 1e-12 || Math.abs(y) < 1e-8)
  )
    throw Error(
      "Place the arc start off the primary axis and between its ends to set the second radius.",
    );
  const ry = chosenRadius ?? Math.abs(y) / Math.sqrt(denominator);
  if (!Number.isFinite(ry) || ry < 1e-8)
    throw Error("Secondary radius must be positive and finite.");
  if (Math.hypot(x, y) < 1e-8)
    throw Error("Choose an arc start away from the center.");
  const at = (a: number): SketchPoint => [
    center[0] + rx * Math.cos(a) * ux - ry * Math.sin(a) * uy,
    center[1] + rx * Math.cos(a) * uy + ry * Math.sin(a) * ux,
  ];
  const segment = {
    type: "ellipse" as const,
    radiusX: rx,
    radiusY: ry,
    rotationDegrees: (Math.atan2(dy, dx) * 180) / Math.PI,
  };
  return { local, at, segment, startAngle: Math.atan2(y / ry, x / rx) };
}
/** Temporary construction ellipse is presentation geometry, never persisted. */
export function ellipticalArcGuide(
  points: SketchPoint[],
  secondaryRadiusMillimeters?: number,
  rememberedRadiusMillimeters?: number,
): Extract<SketchContour, { type: "path" }> {
  const { at, segment } = frame(
    points,
    secondaryRadiusMillimeters,
    rememberedRadiusMillimeters,
  );
  return {
    type: "path",
    construction: true,
    start: at(0),
    segments: [
      { ...segment, largeArc: false, sweep: true, end: at(Math.PI) },
      { ...segment, largeArc: false, sweep: true, end: at(0) },
    ],
  };
}
export function ellipticalArcContour(
  points: SketchPoint[],
  clockwise = false,
  secondaryRadiusMillimeters?: number,
  rememberedRadiusMillimeters?: number,
): Extract<SketchContour, { type: "path" }> {
  if (points.length !== 4)
    throw Error("Choose center, primary radius, start, then end.");
  const { at, segment, local, startAngle } = frame(
    points,
    secondaryRadiusMillimeters,
    rememberedRadiusMillimeters,
  );
  const [x, y] = local(points[3]);
  if (Math.hypot(x, y) < 1e-8)
    throw Error("Choose an end direction away from the center.");
  const endAngle = Math.atan2(y / segment.radiusY, x / segment.radiusX),
    tau = 2 * Math.PI;
  const positive = (endAngle - startAngle + tau) % tau;
  if (positive < 1e-8 || tau - positive < 1e-8)
    throw Error("Arc endpoints must differ.");
  const sweep = clockwise ? positive - tau : positive;
  return {
    type: "path",
    start: at(startAngle),
    segments: [
      {
        ...segment,
        largeArc: Math.abs(sweep) > Math.PI,
        sweep: !clockwise,
        end: at(endAngle),
      },
    ],
  };
}
