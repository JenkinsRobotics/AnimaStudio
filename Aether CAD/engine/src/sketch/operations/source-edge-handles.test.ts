import { expect, it } from "vitest";
import type { SketchDrawing } from "../drawing";
import { offsetSketchEntities } from "./offset-entities";
import { slotSketchEntities } from "./slot";
import {
  offsetDistanceHandle,
  offsetDistanceFromHandle,
} from "./offset-handle";
import { slotWidthHandle, slotWidthFromHandle } from "./slot-handle";
import { editDrawingDimension } from "./edit-dimension";
import { constraintResiduals } from "../solver/residuals";

for (const kind of ["offset", "slot"] as const) {
  it(`keeps the ${kind} handle on its identified source while editing its saved dimension`, () => {
    const source: SketchDrawing = {
      type: "drawing",
      contours: [
        {
          type: "path",
          start: [0, 0],
          segments: [{ type: "line", id: "edge", end: [10, 0] }],
        },
      ],
    };
    const create =
      kind === "offset" ? offsetSketchEntities : slotSketchEntities;
    const d = create(source, [{ kind: "line", contour: 0, index: 0 }], 2);
    const path = d.contours[0];
    if (path.type !== "path") throw Error();
    path.start = [-5, 0];
    path.segments.unshift({ type: "line", id: "prefix", end: [0, 0] });
    const points = [path.start, ...path.segments.map((s) => s.end)];
    points.forEach((point, index) =>
      d.constraints!.push({
        id: `fixed-${index}`,
        kind: "fix",
        a: { kind: "point", contour: 0, index },
        point: [...point],
      }),
    );
    const reopened = JSON.parse(JSON.stringify(d));
    const id = `${kind}-1`;
    const handle =
      kind === "offset"
        ? offsetDistanceHandle(reopened, id)!
        : slotWidthHandle(reopened, id)!;
    expect(handle.origin).toEqual([5, 0]);
    expect(handle.position).toEqual([5, kind === "offset" ? 2 : 1]);
    const value =
      kind === "offset"
        ? offsetDistanceFromHandle(offsetDistanceHandle(reopened, id)!, [5, 3])
        : slotWidthFromHandle(slotWidthHandle(reopened, id)!, [5, 1.5]);
    const before = structuredClone(reopened);
    const resized = editDrawingDimension(reopened, id, value);
    expect(reopened).toEqual(before);
    for (const c of resized.constraints!)
      expect(
        Math.max(...constraintResiduals(resized, c).map(Math.abs)),
      ).toBeLessThan(1e-7);
    const next =
      kind === "offset"
        ? offsetDistanceHandle(resized, id)!
        : slotWidthHandle(resized, id)!;
    expect(next.origin[0]).toBeCloseTo(5, 6);
    expect(next.origin[1]).toBeCloseTo(0, 6);
    expect(next.position[0]).toBeCloseTo(5, 6);
    expect(next.position[1]).toBeCloseTo(kind === "offset" ? 3 : 1.5, 6);
  });
}
