import { expect, it } from "vitest";
import { readFileSync } from "node:fs";
import {
  createSketchClipboard,
  serializeSketchClipboard,
  parseSketchClipboard,
  pasteSketchClipboard,
} from "./sketch-clipboard";
import { evaluateDocumentVariables, type DocumentVariable } from "./variables";
import { setDimensionExpression } from "../sketch/operations/dimension-expression";
import { putSketchText } from "../sketch/text/edit";
import { similarityTransform } from "../sketch/operations/transform";
import { createEmptyPartDocument } from "./part-document";
import { parsePartDocument, serializePartDocument } from "./part-serialization";
import type { SketchDrawing } from "../sketch/drawing";
const empty = (): SketchDrawing => ({ type: "drawing", contours: [] });
const variables: DocumentVariable[] = [
  { name: "base", kind: "length", expression: "10 mm" },
  { name: "radius", kind: "length", expression: "#base/2" },
  { name: "unused", kind: "number", expression: "99" },
];
function source() {
  return setDimensionExpression(
    {
      type: "drawing",
      contours: [
        { type: "circle", center: [0, 0], radius: 5 },
        { type: "circle", center: [20, 0], radius: 5 },
      ],
      constraints: [
        {
          id: "r",
          kind: "radius",
          a: { kind: "circle", contour: 0 },
          value: 5,
        },
        {
          id: "external",
          kind: "equal",
          a: { kind: "circle", contour: 0 },
          b: { kind: "circle", contour: 1 },
        },
      ],
    },
    "r",
    "#radius",
    evaluateDocumentVariables(variables),
  );
}
it("copies a standalone constrained fragment with only transitive required variables", () => {
  const original = source(),
    before = structuredClone(original);
  const fragment = createSketchClipboard(original, [0], variables);
  expect(fragment.drawing.contours).toHaveLength(1);
  expect(fragment.drawing.constraints).toHaveLength(1);
  expect(fragment.variables.map((v) => v.name)).toEqual(["base", "radius"]);
  expect(parseSketchClipboard(serializeSketchClipboard(fragment))).toEqual(
    fragment,
  );
  expect(original).toEqual(before);
});
it("pastes repeatedly with independent IDs and merges definitions without duplication", () => {
  const text = serializeSketchClipboard(
    createSketchClipboard(source(), [0], variables),
  );
  const first = pasteSketchClipboard(
    empty(),
    undefined,
    text,
    similarityTransform([0, 0], [10, 20], 0),
  );
  const second = pasteSketchClipboard(
    first.drawing,
    first.variables,
    text,
    similarityTransform([0, 0], [30, 40], 0),
  );
  expect(second.variables).toHaveLength(2);
  expect(second.drawing.contours).toHaveLength(2);
  expect(new Set(second.drawing.contours.map((c) => c.id)).size).toBe(2);
  expect(new Set(second.drawing.constraints!.map((c) => c.id)).size).toBe(2);
  expect(second.drawing.contours[1]).toMatchObject({ center: [30, 40] });
  expect(first.drawing.contours).toHaveLength(1);
  const doc = createEmptyPartDocument("Pasted");
  doc.variables = second.variables;
  doc.features.push({
    id: "s",
    name: "Paste",
    type: "profile",
    plane: "XY",
    offsetMillimeters: 0,
    suppressed: false,
    profile: second.drawing,
  });
  expect(parsePartDocument(serializePartDocument(doc))).toEqual(doc);
});
it("rejects variable conflicts, stale caches and malformed payloads without touching the target", () => {
  const target = source(),
    before = structuredClone(target),
    fragment = createSketchClipboard(target, [0], variables),
    text = serializeSketchClipboard(fragment);
  const different = structuredClone(variables);
  different[0].expression = "20 mm";
  expect(() => pasteSketchClipboard(target, different, text)).toThrow(
    /different definition/,
  );
  fragment.variables[0].expression = "20 mm";
  expect(() => parseSketchClipboard(JSON.stringify(fragment))).toThrow(
    /Stale dimension/,
  );
  expect(() => parseSketchClipboard('{"format":"other"}')).toThrow(/supported/);
  const invalid = JSON.parse(text);
  invalid.drawing.projectionContext = [];
  expect(() => parseSketchClipboard(JSON.stringify(invalid))).toThrow(
    /projection context/,
  );
  expect(target).toEqual(before);
});
it("retains embedded editable text and frame constraints across documents", async () => {
  const bytes = readFileSync(
    new URL(
      "../../../../core/assets/fonts/noto-sans/NotoSans-Regular.ttf",
      import.meta.url,
    ),
  );
  const drawing = await putSketchText(empty(), {
    text: "O",
    fontBytes: Uint8Array.from(bytes).buffer,
    emSizeMillimeters: 10,
    originMillimeters: [0, 0],
    frameWidthMillimeters: 20,
  });
  const text = serializeSketchClipboard(
    createSketchClipboard(
      drawing,
      drawing.contours.map((_, i) => i),
    ),
  );
  const pasted = pasteSketchClipboard(
    empty(),
    undefined,
    text,
    similarityTransform([0, 0], [30, 0], 0),
  );
  const item = pasted.drawing.textItems![0];
  expect(item.originMillimeters).toEqual([30, 0]);
  const edited = await putSketchText(pasted.drawing, { ...item, text: "OO" });
  expect(edited.textItems![0].text).toBe("OO");
  expect(edited.constraints).toHaveLength(1);
  expect(drawing.textItems![0].text).toBe("O");
});
it("copies a full-capacity sketch without needing twice its contour budget", () => {
  const drawing: SketchDrawing = {
    type: "drawing",
    contours: Array.from({ length: 1000 }, (_, i) => ({
      type: "circle",
      center: [i * 3, 0],
      radius: 1,
    })),
  };
  const fragment = createSketchClipboard(
    drawing,
    drawing.contours.map((_, i) => i),
  );
  expect(fragment.drawing.contours).toHaveLength(1000);
  expect(() =>
    pasteSketchClipboard(
      drawing,
      undefined,
      serializeSketchClipboard(fragment),
    ),
  ).toThrow(/1000 contours/);
});
