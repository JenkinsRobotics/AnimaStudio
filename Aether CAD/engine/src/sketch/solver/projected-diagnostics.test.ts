import { expect, it } from "vitest";
import type { SketchDrawing } from "../drawing";
import { sketchConstraintState, sketchConstraintStates } from "./diagnostics";
import { entityObservables } from "./entity-observables";
const drawing = (): SketchDrawing => ({
  type: "drawing",
  contours: [{ type: "circle", center: [20, 20], radius: 2 }],
  projectionContext: [
    {
      type: "path",
      id: "source",
      start: [5, 0],
      segments: [
        {
          type: "ellipse",
          id: "ellipse",
          radiusX: 5,
          radiusY: 3,
          rotationDegrees: 0,
          largeArc: false,
          sweep: true,
          end: [0, 3],
        },
        { type: "arc", id: "arc", middle: [-1, 4], end: [-2, 3] },
      ],
    },
  ],
});
it("reports projected arcs and ellipses as fixed locally while authored geometry remains free", () => {
  const d = drawing(),
    before = structuredClone(d);
  const refs = [
    undefined,
    {
      kind: "ellipse" as const,
      contour: -1,
      projectedContourId: "source",
      index: 0,
      segmentId: "ellipse",
    },
    {
      kind: "arc" as const,
      contour: -1,
      projectedContourId: "source",
      index: 0,
      segmentId: "arc",
    },
  ];
  const states = sketchConstraintStates(d, refs);
  expect(states.map((s) => s.degreesOfFreedom)).toEqual([3, 0, 0]);
  expect(states.map((s) => s.state)).toEqual([
    "under-constrained",
    "fully-constrained",
    "fully-constrained",
  ]);
  expect(entityObservables(d, refs[2]!)).toEqual([0, 3, -2, 3, -1, 3, 1]);
  expect(d).toEqual(before);
});
it("validates projected-only selections and still rejects broken source identities", () => {
  const d = drawing();
  d.contours = [];
  const ref = {
    kind: "ellipse" as const,
    contour: -1,
    projectedContourId: "source",
    index: 0,
    segmentId: "ellipse",
  };
  expect(sketchConstraintState(d, ref)).toMatchObject({
    state: "fully-constrained",
    degreesOfFreedom: 0,
  });
  expect(sketchConstraintState(d)).toMatchObject({
    state: "empty",
    degreesOfFreedom: 0,
  });
  expect(sketchConstraintState(d, { ...ref, segmentId: "deleted" }).state).toBe(
    "invalid",
  );
});

it("uses stable edge identity for authored curve endpoint observables", () => {
  const d = drawing();
  d.contours = d.projectionContext!;
  delete d.projectionContext;
  const ref = { kind: "arc" as const, contour: 0, index: 0, segmentId: "arc" };
  expect(entityObservables(d, ref)).toEqual([0, 3, -2, 3, -1, 3, 1]);
  expect(sketchConstraintState(d, ref)).toMatchObject({
    state: "under-constrained",
    degreesOfFreedom: 5,
  });
});
