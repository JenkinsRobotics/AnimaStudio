import { expect, it } from "vitest";
import { importDxfSketch, dxfLayers } from "./index";
const file = (blocks: string, entities: string) =>
  `0\nSECTION\n2\nBLOCKS\n${blocks ? blocks + "\n" : ""}0\nENDSEC\n0\nSECTION\n2\nENTITIES\n${entities}\n0\nENDSEC\n0\nEOF`;
const block = (name: string, geometry: string, base = "10\n0\n20\n0") =>
  `0\nBLOCK\n2\n${name}\n${base}\n${geometry}\n0\nENDBLK`;
const line = "0\nLINE\n10\n1\n20\n2\n11\n2\n21\n2";
it("expands nested blocks with base points, rotation, scale and inherited layers", () => {
  const text = file(
    block("inner", line, "10\n1\n20\n2") +
      "\n" +
      block("outer", "0\nINSERT\n2\ninner\n10\n3\n20\n4\n41\n2\n42\n2\n50\n90"),
    "0\nINSERT\n2\nouter\n8\nparts\n10\n10\n20\n20",
  );
  expect(dxfLayers(text)).toEqual([{ name: "parts", entityCount: 1 }]);
  const p = importDxfSketch(text, 1).drawing.contours[0];
  if (p.type !== "path") throw Error();
  expect(p.start).toEqual([13, 24]);
  expect(p.segments[0].end[0]).toBeCloseTo(13);
  expect(p.segments[0].end[1]).toBeCloseTo(26);
});
it("imports nonuniform circle scaling as exact ellipse geometry and repeats arrays", () => {
  const text = file(
    block("ring", "0\nCIRCLE\n10\n0\n20\n0\n40\n2"),
    "0\nINSERT\n2\nring\n10\n10\n20\n5\n41\n3\n42\n2\n70\n2\n44\n20",
  );
  const result = importDxfSketch(text, 1, {
    joinConnected: false,
    classifyHoles: false,
  });
  expect(result.entityCount).toBe(2);
  const p = result.drawing.contours[0];
  if (p.type !== "path") throw Error();
  expect(p.segments.every((s) => s.type === "ellipse")).toBe(true);
  expect(p.segments[0]).toMatchObject({ radiusX: 6, radiusY: 4 });
  const second = result.drawing.contours[1];
  if (second.type !== "path") throw Error();
  expect(second.start[0] - p.start[0]).toBeCloseTo(20);
});
it("rejects missing/cyclic definitions and preserves effective layer selection", () => {
  expect(() => importDxfSketch(file("", "0\nINSERT\n2\nmissing"), 1)).toThrow(
    /Missing DXF block/,
  );
  expect(() =>
    importDxfSketch(
      file(block("loop", "0\nINSERT\n2\nloop"), "0\nINSERT\n2\nloop"),
      1,
    ),
  ).toThrow(/Cyclic/);
  const text = file(
    block("part", line + "\n0\nTEXT\n8\nnotes\n1\nUnsupported"),
    "0\nINSERT\n2\npart\n8\nshape",
  );
  expect(
    importDxfSketch(text, 1, { includedLayers: ["shape"] }).entityCount,
  ).toBe(1);
  expect(() => importDxfSketch(text, 1)).toThrow(/TEXT/);
});

it("applies planar reflection and unit conversion, and limits invalid arrays", () => {
  const geometry = block("line", line, "10\n1\n20\n2");
  const text = file(
    geometry,
    "0\nINSERT\n2\nline\n10\n10\n20\n20\n41\n2\n42\n2\n230\n-1",
  );
  const p = importDxfSketch(text, 10).drawing.contours[0];
  if (p.type !== "path") throw Error();
  expect(p.start).toEqual([-100, 200]);
  expect(p.segments[0].end).toEqual([-120, 200]);
  expect(() =>
    importDxfSketch(file(geometry, "0\nINSERT\n2\nline\n70\n10001"), 1),
  ).toThrow(/array size/);
});

it("preserves a valid circle under very small uniform block scale", () => {
  const text = file(
    block("large", "0\nCIRCLE\n10\n0\n20\n0\n40\n100000000"),
    "0\nINSERT\n2\nlarge\n41\n0.00000001\n42\n0.00000001",
  );
  const circle = importDxfSketch(text, 1).drawing.contours[0];
  expect(circle.type).toBe("circle");
  if (circle.type !== "circle") throw Error();
  expect(circle.radius).toBeCloseTo(1);
});
