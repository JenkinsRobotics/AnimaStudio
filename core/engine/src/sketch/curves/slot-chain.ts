import {
  contourClosed,
  type SketchContour,
  type SketchPoint,
  type SketchSegment,
} from "../drawing";
import { curveJet } from "./derivatives";
import {
  offsetCarrier,
  joinOffsetCarriers,
  offsetCarrierSegment,
} from "./offset-carriers";
import { curveIntersections } from "./pairs";
type Path = Extract<SketchContour, { type: "path" }>;
/** Constant-width open-chain envelope: round convex joins, intersect concave joins. */
export function slotChainContour(source: Path, width: number): Path {
  if (!Number.isFinite(width) || width <= 1e-8)
    throw Error("Slot width must be positive and finite.");
  if (contourClosed(source) || !source.segments.length)
    throw Error("Select a nonempty open slot chain.");
  const radius = width / 2,
    points = [source.start, ...source.segments.map((s) => s.end)];
  const jets = source.segments.map((segment, i) =>
    curveJet({ start: points[i], segment }),
  );
  function boundary(distance: number): Path {
    const carriers = source.segments.map((s, i) =>
      offsetCarrier(points[i], s, distance),
    );
    const starts = carriers.map((c) => c.start),
      ends = carriers.map((c) => c.end),
      joins = new Map<number, SketchSegment>();
    for (let i = 0; i < carriers.length - 1; i++) {
      const a = jets[i](1).first,
        b = jets[i + 1](0).first,
        turn = Math.atan2(a[0] * b[1] - a[1] * b[0], a[0] * b[0] + a[1] * b[1]);
      if (Math.abs(turn) > Math.PI - 1e-8)
        throw Error("Slot chain reverses direction.");
      if (turn * distance < -1e-8) {
        const center = points[i + 1],
          angle = Math.atan2(ends[i][1] - center[1], ends[i][0] - center[0]);
        joins.set(i, {
          type: "arc",
          middle: [
            center[0] + radius * Math.cos(angle + turn / 2),
            center[1] + radius * Math.sin(angle + turn / 2),
          ],
          end: starts[i + 1],
        });
      } else {
        const join = joinOffsetCarriers(
          carriers[i],
          carriers[i + 1],
          points[i + 1],
        );
        ends[i] = join;
        starts[i + 1] = join;
      }
    }
    const segments: SketchSegment[] = [];
    carriers.forEach((c, i) => {
      segments.push(offsetCarrierSegment(c, starts[i], ends[i]));
      const join = joins.get(i);
      if (join) segments.push(join);
    });
    return { type: "path", start: starts[0], segments };
  }
  const left = boundary(radius),
    right = boundary(-radius),
    rp = [right.start, ...right.segments.map((s) => s.end)];
  const cap = (p: SketchPoint, v: SketchPoint, sign: number): SketchPoint => {
    const n = Math.hypot(...v);
    return [
      p[0] + (sign * radius * v[0]) / n,
      p[1] + (sign * radius * v[1]) / n,
    ];
  };
  const segments: SketchSegment[] = [
    ...left.segments,
    {
      type: "arc",
      middle: cap(points.at(-1)!, jets.at(-1)!(1).first, 1),
      end: rp.at(-1)!,
    },
  ];
  for (let i = right.segments.length - 1; i >= 0; i--)
    segments.push({ ...right.segments[i], end: rp[i] });
  segments.push({
    type: "arc",
    middle: cap(points[0], jets[0](0).first, -1),
    end: left.start,
  });
  const p = [left.start, ...segments.map((s) => s.end)];
  for (let i = 0; i < segments.length; i++)
    for (let j = i + 1; j < segments.length; j++) {
      const adjacent = j === i + 1 || (i === 0 && j === segments.length - 1),
        shared = j === i + 1 ? p[i + 1] : p[0];
      if (
        curveIntersections(
          { start: p[i], segment: segments[i] },
          { start: p[j], segment: segments[j] },
        ).some(
          (hit) =>
            !adjacent ||
            Math.hypot(hit.point[0] - shared[0], hit.point[1] - shared[1]) >
              1e-6,
        )
      )
        throw Error(
          "Slot chain overlaps itself; reduce width or change its shape.",
        );
    }
  return { type: "path", start: left.start, segments };
}
