import { expect, it } from "vitest";
import type { SketchDrawing } from "../drawing";
import { offsetSketchEntities } from "./offset-entities";
import { slotSketchEntities } from "./slot";
import { constraintResiduals } from "../solver/residuals";
import { solveDrawingConstraints } from "../solver/solve";
const fixture = (): SketchDrawing => ({
  type: "drawing",
  contours: [
    {
      type: "path",
      sourceLayer: "Wheel",
      start: [0, 0],
      segments: [{ type: "line", id: "edge", end: [10, 0] }],
    },
  ],
});
for (const [name, create] of [
  ["offset", offsetSketchEntities],
  ["slot", slotSketchEntities],
] as const) {
  it.each([true, false])(
    `${name} follows its stable source after insertion (preidentified: %s)`,
    (identified) => {
      const source = fixture();
      if (!identified && source.contours[0].type === "path")
        delete source.contours[0].segments[0].id;
      const original = structuredClone(source);
      expect(() =>
        create(
          source,
          [
            { kind: "line", contour: 0, index: 0 },
            { kind: "line", contour: 0, index: 99 },
          ],
          2,
        ),
      ).toThrow();
      expect(source).toEqual(original);
      const d = create(source, [{ kind: "line", contour: 0, index: 0 }], 2);
      expect(source).toEqual(original);
      const segmentId = identified ? "edge" : "source-edge-1";
      expect(d.constraints![0].a.segmentId).toBe(segmentId);
      const path = d.contours[0];
      if (path.type !== "path") throw Error();
      path.start = [-5, 0];
      path.segments.unshift({ type: "line", id: "prefix", end: [0, 0] });
      const reopened = JSON.parse(JSON.stringify(d));
      for (const c of reopened.constraints)
        expect(
          Math.max(...constraintResiduals(reopened, c).map(Math.abs)),
        ).toBeLessThan(1e-7);
      expect(solveDrawingConstraints(reopened)).toEqual(reopened);
      const stale = create(
        reopened,
        [{ kind: "line", contour: 0, index: 0, segmentId }],
        3,
      );
      for (const c of stale.constraints!)
        expect(
          Math.max(...constraintResiduals(stale, c).map(Math.abs)),
        ).toBeLessThan(1e-7);
      const before = structuredClone(reopened);
      expect(() =>
        create(
          reopened,
          [{ kind: "line", contour: 0, index: 0, segmentId: "deleted" }],
          3,
        ),
      ).toThrow(/Broken segment reference/);
      expect(reopened).toEqual(before);
    },
  );
}
