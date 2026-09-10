import { expect, it } from "vitest";
import { Font, Glyph, Path } from "opentype.js";
import { putSketchText } from "./edit";
import { attachSketchTextFrame } from "./frame";
import { validateSketchDrawing } from "../drawing";
import { sketchConstraintState } from "../solver/diagnostics";
import { editDrawingDimension } from "../operations/edit-dimension";
import { createEmptyPartDocument } from "../../document/part-document";
import {
  parsePartDocument,
  serializePartDocument,
} from "../../document/part-serialization";
function fontBytes() {
  const path = new Path();
  path.moveTo(0, 0);
  path.lineTo(600, 0);
  path.lineTo(600, 800);
  path.lineTo(0, 800);
  path.close();
  path.moveTo(100, 100);
  path.lineTo(100, 700);
  path.lineTo(500, 700);
  path.lineTo(500, 100);
  path.close();
  return new Font({
    familyName: "Test",
    styleName: "Regular",
    unitsPerEm: 1000,
    ascender: 800,
    descender: -200,
    glyphs: [
      new Glyph({ name: ".notdef", advanceWidth: 700, path: new Path() }),
      new Glyph({ name: "O", unicode: 79, advanceWidth: 700, path }),
    ],
  }).toArrayBuffer();
}

const create = async () => {
  const drawing = await putSketchText(
    { type: "drawing", contours: [] },
    {
      text: "O",
      fontBytes: fontBytes(),
      emSizeMillimeters: 10,
      originMillimeters: [0, 0],
    },
  );
  return attachSketchTextFrame(drawing, drawing.textItems![0].id, 8);
};
function constrain(drawing: Awaited<ReturnType<typeof create>>) {
  const contour = drawing.contours.findIndex(
    (c) => c.id === drawing.textItems![0].frameContourId,
  );
  drawing.constraints = [
    {
      id: "anchor",
      kind: "fix",
      a: { contour, kind: "point", index: 0 },
      point: [0, 0],
    },
    {
      id: "baseline",
      kind: "horizontal",
      a: { contour, kind: "line", index: 0 },
    },
    {
      id: "width",
      kind: "length",
      a: { contour, kind: "line", index: 0 },
      value: 8,
    },
    {
      id: "height",
      kind: "length",
      a: { contour, kind: "line", index: 1 },
      value: 10,
    },
  ];
  return drawing;
}
it("adds a construction frame with four remaining DOF and independently drives width and em height", async () => {
  const source = await create();
  expect(source.contours[2].construction).toBe(true);
  expect(sketchConstraintState(source).degreesOfFreedom).toBe(4);
  const drawing = constrain(source);
  expect(sketchConstraintState(drawing)).toMatchObject({
    state: "fully-constrained",
    degreesOfFreedom: 0,
  });
  const wide = editDrawingDimension(drawing, "width", 20);
  expect(wide.textItems![0].frameWidthMillimeters).toBeCloseTo(20);
  expect(wide.textItems![0].emSizeMillimeters).toBeCloseTo(10);
  const glyph = wide.contours[0];
  if (glyph.type !== "path") throw Error();
  expect(glyph.segments[0].end[0]).toBeCloseTo(6);
  const tall = editDrawingDimension(wide, "height", 20);
  expect(tall.textItems![0].emSizeMillimeters).toBeCloseTo(20);
  expect(tall.textItems![0].frameWidthMillimeters).toBeCloseTo(20);
  const largeGlyph = tall.contours[0];
  if (largeGlyph.type !== "path") throw Error();
  expect(largeGlyph.segments[0].end[0]).toBeCloseTo(12);
  expect(source.textItems![0].emSizeMillimeters).toBe(10);
});
it("retains frame identities and constraints while rewording after native reopening", async () => {
  const drawing = constrain(await create());
  const frameId = drawing.textItems![0].frameContourId;
  const frame = drawing.contours[2];
  if (frame.type !== "path") throw Error();
  frame.startVertexId = "baseline-origin";
  frame.segments[0].id = "baseline-edge";
  const doc = createEmptyPartDocument("Framed text");
  doc.features.push({
    id: "s",
    name: "Text",
    type: "profile",
    plane: "XY",
    offsetMillimeters: 0,
    suppressed: false,
    profile: drawing,
  });
  const saved = parsePartDocument(serializePartDocument(doc)).features[0];
  if (saved.type !== "profile" || saved.profile.type !== "drawing")
    throw Error();
  const next = await putSketchText(saved.profile, {
    id: drawing.textItems![0].id,
    text: "OO",
    emSizeMillimeters: 15,
    originMillimeters: [2, 3],
    rotationDegrees: 10,
  });
  expect(next.textItems![0].frameContourId).toBe(frameId);
  expect(next.textItems![0].emSizeMillimeters).toBeCloseTo(10);
  expect(next.textItems![0].originMillimeters[0]).toBeCloseTo(0);
  expect(next.textItems![0].originMillimeters[1]).toBeCloseTo(0);
  expect(next.contours).toHaveLength(5);
  expect(next.constraints).toHaveLength(4);
  expect(
    next.constraints!.every((c) => next.contours[c.a.contour].id === frameId),
  ).toBe(true);
  const retained = next.contours.find((c) => c.id === frameId);
  expect(retained).toMatchObject({
    construction: true,
    startVertexId: "baseline-origin",
    segments: [{ id: "baseline-edge" }, {}, {}, {}],
  });
  expect(sketchConstraintState(next)).toMatchObject({
    state: "fully-constrained",
    degreesOfFreedom: 0,
  });
});
it("rejects manually altered frames and letter constraints before regeneration", async () => {
  const drawing = await create(),
    id = drawing.textItems![0].id;
  drawing.constraints = [
    {
      id: "letter",
      kind: "horizontal",
      a: { contour: 0, kind: "line", index: 0 },
    },
  ];
  await expect(
    putSketchText(drawing, {
      id,
      text: "OO",
      emSizeMillimeters: 10,
      originMillimeters: [0, 0],
    }),
  ).rejects.toThrow(/constraints/);
  drawing.constraints = [];
  const frame = drawing.contours[2];
  if (frame.type !== "path") throw Error();
  frame.start[0] = 1;
  await expect(
    putSketchText(drawing, {
      id,
      text: "OO",
      emSizeMillimeters: 10,
      originMillimeters: [0, 0],
    }),
  ).rejects.toThrow(/edited/);
});
it("validates frame metadata and makes attachment idempotent", async () => {
  const drawing = await create();
  expect(attachSketchTextFrame(drawing, drawing.textItems![0].id)).toEqual(
    drawing,
  );
  drawing.textItems![0].frameWidthMillimeters = 0;
  expect(() => validateSketchDrawing(drawing)).toThrow(/positive width/);
});

it("creates a frame atomically with retained text and permits independent width updates", async () => {
  const source = { type: "drawing" as const, contours: [] };
  const options = {
    text: "O",
    fontBytes: fontBytes(),
    emSizeMillimeters: 10,
    originMillimeters: [0, 0] as [number, number],
    frameWidthMillimeters: 15,
  };
  const created = await putSketchText(source, options);
  expect(created.textItems![0].frameWidthMillimeters).toBe(15);
  expect(created.contours).toHaveLength(3);
  const edited = await putSketchText(created, {
    ...options,
    id: created.textItems![0].id,
    frameWidthMillimeters: 25,
  });
  expect(edited.textItems![0].frameContourId).toBe(
    created.textItems![0].frameContourId,
  );
  expect(edited.textItems![0].frameWidthMillimeters).toBe(25);
  expect(edited.textItems![0].emSizeMillimeters).toBe(10);
  expect(source.contours).toEqual([]);
  await expect(
    putSketchText(source, { ...options, frameWidthMillimeters: -1 }),
  ).rejects.toThrow(/positive/);
});
