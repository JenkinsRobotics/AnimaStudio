import { readFileSync } from "node:fs";
import { expect, it } from "vitest";
import { putSketchText } from "./edit";
import { regenerateSketchTextExpressions } from "./regenerate-expressions";
import { resolveSketchTextExpression } from "./expression";
import { evaluateDocumentVariables } from "../../document/variables";
import { createEmptyPartDocument } from "../../document/part-document";
import {
  parsePartDocument,
  serializePartDocument,
} from "../../document/part-serialization";
import { validateSketchDrawing } from "../drawing";
import { decodeTextFont } from "./records";

const variables = (expression: string) =>
  evaluateDocumentVariables([
    { name: "label", kind: "string", expression: JSON.stringify(expression) },
  ]);
const create = async () => {
  const font = readFileSync(
    new URL(
      "../../../../assets/fonts/noto-sans/NotoSans-Regular.ttf",
      import.meta.url,
    ),
  );
  return putSketchText(
    { type: "drawing", contours: [] },
    {
      text: "ignored literal",
      expression: "#label",
      expressionVariables: variables("O"),
      fontBytes: Uint8Array.from(font).buffer,
      emSizeMillimeters: 10,
      originMillimeters: [2, 3],
      frameWidthMillimeters: 20,
      textHeightMillimeters: 8,
      flipVertical: true,
    },
  );
};

it("evaluates typed quantities explicitly converted to text units", () => {
  const values = evaluateDocumentVariables([
    { name: "length", kind: "length", expression: "25.4 mm" },
  ]);
  expect(
    resolveSketchTextExpression(
      'roundToPrecision(#length/in, 3) ~ "in"',
      values,
    ),
  ).toBe("1in");
  expect(() => resolveSketchTextExpression("#length", values)).toThrow();
  expect(() => resolveSketchTextExpression("#missing", values)).toThrow(
    /Unknown variable/,
  );
});

it("retains expressions through native save and regenerates letters without replacing frame constraints", async () => {
  const drawing = await create();
  const doc = createEmptyPartDocument("Expression text");
  doc.variables = [{ name: "label", kind: "string", expression: '"O"' }];
  doc.features.push({
    id: "s",
    type: "profile",
    name: "Text",
    plane: "XY",
    offsetMillimeters: 0,
    suppressed: false,
    profile: drawing,
  });
  const feature = parsePartDocument(serializePartDocument(doc)).features[0];
  if (feature.type !== "profile" || feature.profile.type !== "drawing")
    throw Error();
  const before = feature.profile.textItems![0];
  const result = await regenerateSketchTextExpressions(
    feature.profile,
    variables("OO"),
  );
  const after = result.textItems![0];
  expect(after.text).toBe("OO");
  expect(after.expression).toBe("#label");
  expect(after.frameContourId).toBe(before.frameContourId);
  expect(after.fontAscenderRatio).toBe(before.fontAscenderRatio);
  expect(after.flipVertical).toBe(true);
  expect(after.originMillimeters).toEqual(before.originMillimeters);
  expect(result.constraints!.map((c) => c.id)).toEqual(
    drawing.constraints!.map((c) => c.id),
  );
  expect(after.contourIds.length).toBeGreaterThan(before.contourIds.length);
  expect(drawing.textItems![0].text).toBe("O");
  expect(JSON.stringify(result)).not.toContain("expressionVariables");
});

it("preserves a binding on edit and explicitly converts it to literal text", async () => {
  const drawing = await create(),
    item = drawing.textItems![0];
  const retained = await putSketchText(drawing, {
    ...item,
    text: "wrong",
    expression: undefined,
    expressionVariables: variables("OO"),
  });
  expect(retained.textItems![0].text).toBe("OO");
  const literal = await putSketchText(retained, {
    ...retained.textItems![0],
    expression: null,
    text: "O",
  });
  expect(literal.textItems![0].expression).toBeUndefined();
  expect(await regenerateSketchTextExpressions(literal, new Map())).toEqual(
    literal,
  );
});

it("rejects malformed formulas and failed regeneration without modifying the source", async () => {
  const drawing = await create(),
    saved = structuredClone(drawing);
  await expect(
    regenerateSketchTextExpressions(drawing, new Map()),
  ).rejects.toThrow(/Unknown variable/);
  await expect(
    regenerateSketchTextExpressions(drawing, variables("\u{10ffff}")),
  ).rejects.toThrow();
  expect(drawing).toEqual(saved);
  drawing.textItems![0].expression = "#label ~";
  expect(() => validateSketchDrawing(drawing)).toThrow();
});

it("leaves unchanged lettering identities alone but rejects changed wording after manual edits", async () => {
  const drawing = await create();
  const contour = drawing.contours[0];
  if (contour.type !== "path") throw Error();
  contour.start[0] += 1;
  expect(
    await regenerateSketchTextExpressions(drawing, variables("O")),
  ).toEqual(drawing);
  const saved = structuredClone(drawing);
  await expect(
    regenerateSketchTextExpressions(drawing, variables("OO")),
  ).rejects.toThrow(/edited/);
  expect(drawing).toEqual(saved);
});

it("rolls back the whole drawing when a later text item fails after an earlier regeneration", async () => {
  const first = await create(),
    item = first.textItems![0];
  const values = variables("O");
  values.set("other", "O");
  const drawing = await putSketchText(first, {
    ...item,
    id: undefined,
    expression: "#other",
    expressionVariables: values,
    fontBytes: decodeTextFont(item),
    originMillimeters: [40, 3],
  });
  const saved = structuredClone(drawing);
  values.set("label", "OO");
  values.set("other", "\u{10ffff}");
  await expect(
    regenerateSketchTextExpressions(drawing, values),
  ).rejects.toThrow();
  expect(drawing).toEqual(saved);
});
