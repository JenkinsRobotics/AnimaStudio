import { expect, it } from "vitest";
import { importDxfSketch } from "./index";
const file = (body: string) =>
  `0\nSECTION\n2\nENTITIES\n${body}\n0\nENDSEC\n0\nEOF`;
const read = (body: string) =>
  importDxfSketch(file(body), 1, { joinConnected: false, classifyHoles: false })
    .drawing.contours[0];
const negative = "210\n0\n220\n0\n230\n-1";
it("converts negative-Z circle and arc OCS without reversing world-coordinate lines", () => {
  expect(read(`0\nCIRCLE\n10\n3\n20\n2\n40\n1\n${negative}`)).toEqual({
    type: "circle",
    sourceLayer: "0",
    center: [-3, 2],
    radius: 1,
  });
  const arc = read(`0\nARC\n10\n3\n20\n2\n40\n1\n50\n0\n51\n90\n${negative}`);
  expect(arc).toMatchObject({
    type: "path",
    start: [-4, 2],
    segments: [{ type: "arc", end: [-3, 3] }],
  });
  if (arc.type !== "path" || arc.segments[0].type !== "arc") throw Error();
  expect(arc.segments[0].middle[0]).toBeCloseTo(-3 - Math.SQRT1_2, 8);
  expect(arc.segments[0].middle[1]).toBeCloseTo(2 + Math.SQRT1_2, 8);
  expect(
    read(`0\nLINE\n10\n1\n20\n2\n11\n3\n21\n4\n${negative}`),
  ).toMatchObject({ start: [1, 2], segments: [{ end: [3, 4] }] });
});
it("keeps ellipse center and major axis in WCS while reversing the minor axis", () => {
  const e = read(
    `0\nELLIPSE\n10\n3\n20\n2\n11\n2\n21\n0\n40\n0.5\n41\n0\n42\n${Math.PI / 2}\n${negative}`,
  );
  expect(e).toMatchObject({
    type: "path",
    start: [5, 2],
    segments: [{ type: "ellipse", sweep: false, radiusX: 2, radiusY: 1 }],
  });
  if (e.type !== "path") throw Error();
  expect(e.segments[0].end[0]).toBeCloseTo(3);
  expect(e.segments[0].end[1]).toBeCloseTo(1);
});
it("transforms signed bulges in lightweight and legacy 2D polylines", () => {
  const lw = `0\nLWPOLYLINE\n90\n2\n${negative}\n10\n1\n20\n0\n42\n1\n10\n3\n20\n0`;
  const legacy = `0\nPOLYLINE\n70\n0\n${negative}\n0\nVERTEX\n10\n1\n20\n0\n42\n1\n0\nVERTEX\n10\n3\n20\n0\n0\nSEQEND`;
  for (const body of [lw, legacy])
    expect(read(body)).toMatchObject({
      type: "path",
      start: [-1, 0],
      segments: [{ type: "arc", middle: [-2, -1], end: [-3, 0] }],
    });
});
it("rejects invalid normals, tilted OCS and elevation without silently flattening", () => {
  const body = "0\nCIRCLE\n10\n3\n20\n2\n40\n1";
  expect(() => read(body + "\n230\n0")).toThrow(/nonzero/);
  expect(() => read(body + "\n210\n1\n230\n0")).toThrow(/tilted/);
  expect(() => read(body + "\n30\n2")).toThrow(/non-planar/);
});
