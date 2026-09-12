import { expect, it } from "vitest";
import { splitSketchSegment } from "./split";
import { segmentPoint } from "../curves/parameterization";
import { constraintResiduals } from "../solver/residuals";
import {
  validateSketchDrawing,
  type SketchDrawing,
  type SketchSegment,
} from "../drawing";
const segments: SketchSegment[] = [
  { type: "line", end: [4, 0] },
  {
    type: "bezier",
    controls: [
      [1, 2],
      [3, 2],
    ],
    end: [4, 0],
  },
  { type: "arc", middle: [2, 2], end: [4, 0] },
  {
    type: "ellipse",
    radiusX: 2,
    radiusY: 1,
    rotationDegrees: 0,
    largeArc: false,
    sweep: true,
    end: [4, 0],
  },
];
it("preserves contacts on both split pieces for lines, arcs, ellipses and cubics", () => {
  for (const segment of segments) {
    const d: SketchDrawing = {
      type: "drawing",
      contours: [{ type: "path", start: [0, 0], segments: [segment] }],
      constraints: [],
    };
    for (const t of [0.25, 0.5, 0.75]) {
      const contour = d.contours.length;
      d.contours.push({
        type: "path",
        start: segmentPoint([0, 0], segment, t),
        segments: [],
      });
      d.constraints!.push({
        id: `contact-${t}`,
        kind: "coincident",
        a: { kind: "point", contour, index: 0 },
        b: {
          kind: "curve",
          contour: 0,
          index: 0,
          parameter: t,
          sliding: t !== 0.25,
        },
      });
    }
    const next = splitSketchSegment(
      d,
      segmentPoint([0, 0], segment, 0.5),
      0.01,
    );
    for (const [i, t] of [0.25, 0.5, 0.75].entries()) {
      const c = next.constraints![i];
      expect(c.id).toBe(`contact-${t}`);
      expect(c.b!.parameter).toBeCloseTo(t <= 0.5 ? t * 2 : (t - 0.5) * 2, 5);
      expect(c.b!.index).toBe(t <= 0.5 ? 0 : 1);
      expect(c.b!.sliding).toBe(t !== 0.25);
      expect(
        constraintResiduals(next, c).every((r) => Math.abs(r) < 1e-6),
      ).toBe(true);
    }
    validateSketchDrawing(JSON.parse(JSON.stringify(next)));
    expect(d.contours[0]).toMatchObject({ segments: [segment] });
  }
});
it("preserves endpoint tangent contacts and fixed control references", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [0, 0],
        segments: [
          {
            type: "bezier",
            controls: [
              [1, 0],
              [2, 1],
            ],
            end: [3, 1],
          },
        ],
      },
      {
        type: "path",
        start: [-2, 0],
        segments: [{ type: "line", end: [0, 0] }],
      },
    ],
    constraints: [
      {
        id: "t",
        kind: "tangent",
        a: { kind: "curve", contour: 0, index: 0, parameter: 0 },
        b: { kind: "curve", contour: 1, index: 0, parameter: 1 },
      },
    ],
  };
  const path = d.contours[0];
  if (path.type !== "path") throw Error();
  const p = segmentPoint(path.start, path.segments[0], 0.5);
  const next = splitSketchSegment(d, p, 0.01);
  expect(
    constraintResiduals(next, next.constraints![0]).every(
      (r) => Math.abs(r) < 1e-6,
    ),
  ).toBe(true);
  d.constraints!.push({
    id: "control",
    kind: "fix",
    a: { kind: "point", contour: 0, index: 0, control: 0 },
    point: [1, 0],
  });
  const before = structuredClone(d);
  const fixed = splitSketchSegment(d, p, 0.01);
  expect(fixed.constraints!.find(c=>c.id==="control")!.a.controlScale).toBeCloseTo(2);
  for(const c of fixed.constraints!)expect(constraintResiduals(fixed,c).every(r=>Math.abs(r)<1e-6)).toBe(true);
  expect(d).toEqual(before);
});
