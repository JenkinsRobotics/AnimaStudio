import {
  contourClosed,
  type SketchDrawing,
  type SketchPoint,
} from "../drawing";
import { sketchArcGeometry } from "../arc-geometry";
export interface DiagnosticCoordinate {
  get: () => number;
  set: (v: number) => void;
}
/** Independent geometric coordinates: arcs use one bulge, not an arbitrary through-point position. */
export function diagnosticCoordinates(
  d: SketchDrawing,
  skipContours: ReadonlySet<number> = new Set(),
): DiagnosticCoordinate[] {
  const coordinates: DiagnosticCoordinate[] = [],
    arcs: {
      start: SketchPoint;
      end: SketchPoint;
      middle: SketchPoint;
      bulge: number;
    }[] = [];
  const rebuild = () => {
    for (const a of arcs) {
      const dx = a.end[0] - a.start[0],
        dy = a.end[1] - a.start[1];
      a.middle[0] = (a.start[0] + a.end[0]) / 2 + (dy * a.bulge) / 2;
      a.middle[1] = (a.start[1] + a.end[1]) / 2 - (dx * a.bulge) / 2;
    }
  };
  const point = (p: SketchPoint, alias?: SketchPoint) => {
    for (let k = 0; k < 2; k++)
      coordinates.push({
        get: () => p[k],
        set: (v) => {
          p[k] = v;
          if (alias) alias[k] = v;
          rebuild();
        },
      });
  };
  for (const [index, c] of d.contours.entries()) {
    if (skipContours.has(index)) continue;
    if (c.type === "circle") {
      point(c.center);
      coordinates.push({
        get: () => c.radius,
        set: (v) => {
          c.radius = v;
        },
      });
      continue;
    }
    const closed = contourClosed(c);
    point(c.start, closed ? c.segments.at(-1)?.end : undefined);
    let start = c.start;
    for (const [i, s] of c.segments.entries()) {
      if (!(closed && i === c.segments.length - 1)) point(s.end);
      if (s.type === "bezier") s.controls.forEach((p) => point(p));
      if (s.type === "ellipse")
        for (const key of ["radiusX", "radiusY", "rotationDegrees"] as const)
          coordinates.push({
            get: () => s[key],
            set: (v) => {
              s[key] = v;
            },
          });
      if (s.type === "arc") {
        const arc = {
          start,
          end: s.end,
          middle: s.middle,
          bulge: Math.tan(sketchArcGeometry(start, s.middle, s.end).sweep / 4),
        };
        arcs.push(arc);
        coordinates.push({
          get: () => arc.bulge,
          set: (v) => {
            arc.bulge = v;
            rebuild();
          },
        });
      }
      start = s.end;
    }
  }
  rebuild();
  return coordinates;
}
