import { beforeAll, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import init from "replicad-opencascadejs";
import { setOC, makeBaseBox, makeCylinder } from "replicad";
import { projectHiddenLineView, type ViewPolyline } from "./hidden-line";

beforeAll(async () => {
  setOC(
    await (init as any)({
      wasmBinary: readFileSync(
        new URL(
          "../../node_modules/replicad-opencascadejs/src/replicad_single.wasm",
          import.meta.url,
        ),
      ),
    }),
  );
}, 30000);

const extent = (polylines: readonly ViewPolyline[]) => {
  const points = polylines.flat();
  const xs = points.map((p) => p[0]), ys = points.map((p) => p[1]);
  return {
    width: Math.max(...xs) - Math.min(...xs),
    height: Math.max(...ys) - Math.min(...ys),
  };
};

it("classifies a box's far edges as hidden and projects the near face true-size", () => {
  // 40 x 20 x 10 box viewed along -Y: the projection is 40 wide and 10 tall.
  const box = makeBaseBox(40, 20, 10);
  const view = projectHiddenLineView(box, { viewNormal: [0, -1, 0] });

  expect(view.visible.length).toBeGreaterThan(0);
  // The point of HLR: the back of the solid is reported separately, not drawn
  // as if it were in front.
  expect(view.hidden.length).toBeGreaterThan(0);

  const near = extent(view.visible);
  expect(near.width).toBeCloseTo(40, 6);
  expect(near.height).toBeCloseTo(10, 6);
  // Every projected point lies in the view plane.
  for (const polyline of [...view.visible, ...view.hidden])
    for (const point of polyline) expect(point).toHaveLength(2);
});

it("finds a cylinder's silhouette, which has no edge to find", () => {
  // Viewed along its own axis a cylinder is a circle; viewed across it, the
  // sides are smooth surface with no B-Rep edge — only HLR's outline set has
  // them, which is why a drawing needs both sets.
  const cylinder = makeCylinder(5, 30, [0, 0, 0], [0, 0, 1]);
  const across = projectHiddenLineView(cylinder, { viewNormal: [0, -1, 0] });

  expect(across.visibleOutline.length).toBeGreaterThan(0);
  const silhouette = extent(across.visibleOutline);
  expect(silhouette.width).toBeCloseTo(10, 3); // diameter
  expect(silhouette.height).toBeCloseTo(30, 3); // length
});

it("hides what a nearer solid occludes, and reveals it from the other side", () => {
  // A small box parked behind a large one: fully occluded from the front,
  // fully visible from behind. Same geometry, opposite classification.
  const front = makeBaseBox(40, 10, 40).translate([0, 0, 0]);
  const behind = makeBaseBox(10, 10, 10).translate([0, 20, 0]);
  const pair = front.fuse(behind);

  const fromFront = projectHiddenLineView(pair, { viewNormal: [0, -1, 0] });
  const fromBehind = projectHiddenLineView(pair, { viewNormal: [0, 1, 0] });

  const hiddenLength = (view: { hidden: readonly ViewPolyline[] }) =>
    view.hidden.reduce(
      (total, polyline) =>
        total +
        polyline.reduce(
          (length, point, index) =>
            index === 0 ? 0 : length + Math.hypot(
              point[0] - polyline[index - 1][0],
              point[1] - polyline[index - 1][1],
            ),
          0,
        ),
      0,
    );

  // The occluded box contributes hidden length from the front and none of it
  // is hidden from behind.
  expect(hiddenLength(fromFront)).toBeGreaterThan(hiddenLength(fromBehind));
});

it("refuses a degenerate view direction instead of projecting nonsense", () => {
  expect(() =>
    projectHiddenLineView(makeBaseBox(10, 10, 10), { viewNormal: [0, 0, 0] }),
  ).toThrow(/non-zero view direction/);
});
