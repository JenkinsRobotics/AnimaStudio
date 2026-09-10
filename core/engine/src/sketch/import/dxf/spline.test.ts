import { expect, it } from "vitest";
import { importDxfSketch } from "./index";
const file = (body: string) =>
  `0\nSECTION\n2\nENTITIES\n${body}\n0\nENDSEC\n0\nEOF`;
const spline =
  "0\nSPLINE\n70\n8\n71\n3\n72\n8\n73\n4\n40\n0\n40\n0\n40\n0\n40\n0\n40\n1\n40\n1\n40\n1\n40\n1\n10\n0\n20\n0\n30\n0\n10\n0\n20\n2\n30\n0\n10\n3\n20\n2\n30\n0\n10\n3\n20\n0\n30\n0";
it("imports a cubic spline as editable native controls with unit conversion", () => {
  const c = importDxfSketch(file(spline), 10).drawing.contours[0];
  if (c.type !== "path" || c.segments[0].type !== "bezier") throw Error();
  expect(c.start).toEqual([0, 0]);
  expect(c.segments[0].end).toEqual([30, 0]);
  expect(c.segments[0].controls[0][0]).toBeCloseTo(0, 10);
  expect(c.segments[0].controls[0][1]).toBeCloseTo(20, 10);
  expect(c.segments[0].controls[1][0]).toBeCloseTo(30, 10);
  expect(c.segments[0].controls[1][1]).toBeCloseTo(20, 10);
});
it("joins spline endpoints to other DXF edges to form a closed profile", () => {
  const d = importDxfSketch(
    file(spline + "\n0\nLINE\n10\n3\n20\n0\n11\n0\n21\n0"),
    1,
  ).drawing;
  expect(d.contours).toHaveLength(1);
  const c = d.contours[0];
  if (c.type !== "path") throw Error();
  expect(c.segments).toHaveLength(2);
  expect(c.segments.at(-1)?.end).toEqual(c.start);
  expect(c.hole).toBe(false);
});
it("rejects unequal rational weights, mismatched counts, unclosed flags, and later nonplanar controls", () => {
  expect(() =>
    importDxfSketch(file(spline + "\n41\n1\n41\n2\n41\n1\n41\n1"), 1),
  ).toThrow("Rational");
  expect(() =>
    importDxfSketch(file(spline.replace("73\n4", "73\n5")), 1),
  ).toThrow("counts");
  expect(() =>
    importDxfSketch(file(spline.replace("70\n8", "70\n9")), 1),
  ).toThrow("does not close");
  expect(() => importDxfSketch(file(spline.slice(0, -1) + "1"), 1)).toThrow(
    "Non-planar",
  );
});
