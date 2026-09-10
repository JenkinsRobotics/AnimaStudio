import { expect, it } from "vitest";
import { importDxfSketch } from "./index";
import { ellipseFrame, ellipsePoint } from "../../curves/parameterization";
const file = (body: string) =>
  `0\nSECTION\n2\nENTITIES\n${body}\n0\nENDSEC\n0\nEOF`;
const ellipse = (start: number, end: number) =>
  `0\nELLIPSE\n10\n10\n20\n20\n11\n3\n21\n4\n40\n0.4\n41\n${start}\n42\n${end}`;
it("imports rotated elliptical arcs using ellipse parameters and source units", () => {
  const p = importDxfSketch(file(ellipse(0.2, 4.2)), 10).drawing.contours[0];
  if (p.type !== "path" || p.segments[0].type !== "ellipse") throw Error();
  const frame = ellipseFrame(p.start, p.segments[0]);
  expect(frame.center[0]).toBeCloseTo(100, 7);
  expect(frame.center[1]).toBeCloseTo(200, 7);
  expect(frame.radiusX).toBeCloseTo(50);
  expect(frame.radiusY).toBeCloseTo(20);
  expect(frame.sweep).toBeCloseTo(4);
  const middle = ellipsePoint(frame, 0.5),
    angle = 2.2;
  expect(middle[0]).toBeCloseTo(
    100 + 30 * Math.cos(angle) - 16 * Math.sin(angle),
    6,
  );
});
it("imports a full ellipse as two complementary native arcs", () => {
  const p = importDxfSketch(file(ellipse(0, 2 * Math.PI)), 1).drawing
    .contours[0];
  if (p.type !== "path") throw Error();
  expect(p.segments).toHaveLength(2);
  expect(p.segments[1].end).toEqual(p.start);
});
const poly =
  "0\nPOLYLINE\n66\n1\n70\n1\n0\nVERTEX\n10\n0\n20\n0\n42\n-1\n0\nVERTEX\n10\n10\n20\n0\n0\nSEQEND";
it("consumes legacy vertex sequences, preserves clockwise bulges, and resumes at the next entity", () => {
  const d = importDxfSketch(
    file(poly + "\n0\nCIRCLE\n10\n20\n20\n0\n40\n2"),
    1,
  ).drawing;
  expect(d.contours).toHaveLength(2);
  const p = d.contours[0];
  if (p.type !== "path") throw Error();
  expect(p.segments[0]).toEqual({ type: "arc", middle: [5, 5], end: [10, 0] });
  expect(p.segments[1].end).toEqual([0, 0]);
});
it("rejects fitted polylines, missing sequence ends and invalid ellipse ratios", () => {
  expect(() =>
    importDxfSketch(file(poly.replace("70\n1", "70\n8")), 1),
  ).toThrow("3D");
  expect(() =>
    importDxfSketch(file(poly.replace("\n0\nSEQEND", "")), 1),
  ).toThrow("SEQEND");
  expect(() =>
    importDxfSketch(file(ellipse(0, 1).replace("40\n0.4", "40\n2")), 1),
  ).toThrow("ratio");
});
it('skips complete paper-space polyline sequences without importing their vertices',()=>{
 const paper=poly.replace('66\n1','67\n1').replace('70\n1','70\n8');
 const d=importDxfSketch(file(paper+'\n0\nCIRCLE\n10\n0\n20\n0\n40\n1'),1).drawing;expect(d.contours).toHaveLength(1);expect(d.contours[0].type).toBe('circle');
});
