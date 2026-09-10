import { expect, it } from "vitest";
import { extendSketchCurve } from "./extend-curves";
import { dragSketchEntity } from "./drag-entity";
import { constraintResiduals } from "../solver/residuals";
import { validateSketchDrawing, type SketchDrawing } from "../drawing";
it("keeps an extended line on its boundary after the boundary moves", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [0, 0],
        segments: [{ type: "line", end: [5, 0] }],
      },
      {
        type: "path",
        start: [8, -3],
        segments: [{ type: "line", end: [8, 3] }],
      },
    ],
    constraints: [
      {
        id: "h",
        kind: "horizontal",
        a: { kind: "line", contour: 0, index: 0 },
      },
    ],
  };
  const next = extendSketchCurve(d, [5, 0], 0.1);
  expect(next.constraints!.at(-1)).toMatchObject({
    kind: "coincident",
    b: { kind: "line", contour: 1, index: 0 },
  });
  const moved = dragSketchEntity(
    JSON.parse(JSON.stringify(next)),
    { kind: "line", contour: 1, index: 0 },
    [2, 0],
  );
  const path = moved.contours[0];
  if (path.type !== "path") throw Error();
  expect(path.segments[0].end[0]).toBeCloseTo(10);
  validateSketchDrawing(moved);
});
it("retains circle and cubic boundary references including finite cubic parameter", () => {
  const line = {
    type: "path" as const,
    start: [0, 0] as [number, number],
    segments: [{ type: "line" as const, end: [5, 0] as [number, number] }],
  };
  const circle = extendSketchCurve(
    {
      type: "drawing",
      contours: [line, { type: "circle", center: [10, 0], radius: 2 }],
    },
    [5, 0],
    0.1,
  );
  expect(circle.constraints!.at(-1)).toMatchObject({
    b: { kind: "circle", contour: 1 },
  });
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      line,
      {
        type: "path",
        start: [8, -3],
        segments: [
          {
            type: "bezier",
            controls: [
              [8, -1],
              [8, 1],
            ],
            end: [8, 3],
          },
        ],
      },
    ],
  };
  const next = extendSketchCurve(d, [5, 0], 0.1);
  expect(next.constraints!.at(-1)).toMatchObject({
    b: { kind: "curve", contour: 1, index: 0, parameter: expect.closeTo(0.5) },
  });
  const moved = dragSketchEntity(
    JSON.parse(JSON.stringify(next)),
    { kind: "point", contour: 1, index: 0, control: 0 },
    [1, 0],
  );
  for (const c of moved.constraints!)
    expect(constraintResiduals(moved, c).every((r) => Math.abs(r) < 1e-6)).toBe(
      true,
    );
  validateSketchDrawing(moved);
});

it("attaches at a stationary cubic endpoint while direction constraints remain invalid",()=>{
 const d:SketchDrawing={type:"drawing",contours:[{type:"path",start:[0,0],segments:[{type:"line",end:[5,0]}]},{type:"path",start:[8,0],segments:[{type:"bezier",controls:[[8,0],[8,1]],end:[8,3]}]}]};
 const next=extendSketchCurve(d,[5,0],.1);validateSketchDrawing(next);const c=next.constraints!.at(-1)!;expect(c.b).toMatchObject({kind:"curve",contour:1,parameter:expect.closeTo(0)});expect(()=>constraintResiduals(next,{...c,kind:"tangent",a:{kind:"curve",contour:0,index:0,parameter:1}})).toThrow(/stationary/);
});
