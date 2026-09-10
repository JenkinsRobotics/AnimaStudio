import {
  contourClosed,
  type SketchContour,
  type SketchPoint,
} from "../drawing";
import {
  offsetCarrier,
  joinOffsetCarriers,
  offsetCarrierSegment,
} from "./offset-carriers";
import { curveIntersections } from "./pairs";
/** Exact line/circular-arc chain offset, rejecting joins needing topology repair. */
export function offsetMixedPath(
  source: Extract<SketchContour, { type: "path" }>,
  distance: number,
): SketchContour {
  const closed = contourClosed(source),
    points = [source.start, ...source.segments.map((s) => s.end)];
  const carriers = source.segments.map((s, i) =>
    offsetCarrier(points[i], s, distance),
  );
  const joins: SketchPoint[] = [
    closed
      ? joinOffsetCarriers(carriers.at(-1)!, carriers[0], source.start)
      : carriers[0].start,
  ];
  for (let i = 1; i < carriers.length; i++)
    joins.push(joinOffsetCarriers(carriers[i - 1], carriers[i], points[i]));
  joins.push(closed ? [...joins[0]] : carriers.at(-1)!.end);
  const segments = carriers.map((c, i) =>
    offsetCarrierSegment(c, joins[i], joins[i + 1]),
  );
  for (let i = 0; i < segments.length; i++)
    for (let j = i + 1; j < segments.length; j++) {
      const adjacent =
        j === i + 1 || (closed && i === 0 && j === segments.length - 1);
      const hits = curveIntersections(
        { start: joins[i], segment: segments[i] },
        { start: joins[j], segment: segments[j] },
      );
      const shared = j === i + 1 ? joins[i + 1] : joins[0];
      if (
        hits.some(
          (h) =>
            !adjacent ||
            (Math.hypot(h.point[0] - shared[0], h.point[1] - shared[1]) > 1e-6 &&
              !(closed && segments.length === 2 && Math.hypot(h.point[0]-joins[0][0],h.point[1]-joins[0][1]) <= 1e-6)),
        )
      )
        throw Error("Offset would self-intersect.");
    }
  return { ...structuredClone(source), start: joins[0], segments };
}
