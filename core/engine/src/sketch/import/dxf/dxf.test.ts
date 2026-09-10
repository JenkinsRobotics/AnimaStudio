import { expect, it } from "vitest";
import { importDxfSketch } from "./index";
import { sketchArcGeometry } from "../../arc-geometry";
const file = (entities: string, units = 4) =>
  `0\nSECTION\n2\nHEADER\n9\n$INSUNITS\n70\n${units}\n0\nENDSEC\n0\nSECTION\n2\nENTITIES\n${entities}\n0\nENDSEC\n0\nEOF\n`;
it("imports unit-scaled circles and counterclockwise arcs crossing zero", () => {
  const result = importDxfSketch(
    file(
      "0\nCIRCLE\n10\n1\n20\n2\n40\n3\n0\nARC\n10\n0\n20\n0\n40\n1\n50\n350\n51\n10",
      1,
    ),
  );
  expect(result.drawing.contours[0]).toMatchObject({
    radius: 76.19999999999999,
    center: [25.4, 50.8],
  });
  const arc = result.drawing.contours[1];
  if (arc.type !== "path" || arc.segments[0].type !== "arc") throw Error();
  const s = arc.segments[0];
  expect(sketchArcGeometry(arc.start, s.middle, s.end).sweep).toBeCloseTo(
    Math.PI / 9,
    8,
  );
});
it("preserves bulged polyline segments and closing edges as exact native arcs", () => {
  const d = importDxfSketch(
    file("0\nLWPOLYLINE\n90\n2\n70\n1\n10\n0\n20\n0\n42\n1\n10\n10\n20\n0"),
  ).drawing;
  const p = d.contours[0];
  if (p.type !== "path") throw Error();
  expect(p.segments[0]).toEqual({ type: "arc", middle: [5, -5], end: [10, 0] });
  expect(p.segments[1].end).toEqual([0, 0]);
});
it("requires explicit missing units and rejects unsupported or malformed geometry", () => {
  const line = "0\nLINE\n10\n0\n20\n0\n11\n1\n21\n0";
  expect(() => importDxfSketch(file(line, 0))).toThrow("units");
  expect(importDxfSketch(file(line, 0), 10).millimetersPerUnit).toBe(10);
  expect(() => importDxfSketch(file(line + "\n0\nHATCH"))).toThrow("HATCH");
  expect(() => importDxfSketch(file(line + "\n30\n1"))).toThrow("non-planar");
  expect(() => importDxfSketch("0\nSECTION")).toThrow("EOF");
});
