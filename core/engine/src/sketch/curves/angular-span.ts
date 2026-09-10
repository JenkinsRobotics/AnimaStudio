/** Angular distance outside a directed circular span; zero on the visible arc. */
export function angularSpanDistance(
  start: number,
  sweep: number,
  angle: number,
): number {
  const tau = 2 * Math.PI,
    wrap = (x: number) => ((x % tau) + tau) % tau;
  const travel = wrap(sweep >= 0 ? angle - start : start - angle);
  if (
    Math.abs(sweep) >= tau - 1e-10 ||
    travel <= Math.abs(sweep) + 1e-10 ||
    tau - travel < 1e-10
  )
    return 0;
  const distance = (a: number, b: number) =>
    Math.abs(Math.atan2(Math.sin(a - b), Math.cos(a - b)));
  return Math.min(distance(angle, start), distance(angle, start + sweep));
}
