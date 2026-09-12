import { readFileSync } from "node:fs";
import { expect, it } from "vitest";
import { createEmptyPartDocument, validatePartDocument } from "./part-document";
import { parsePartDocument, serializePartDocument } from "./part-serialization";
import { updatePartDocumentVariables } from "./update-variables";
import { evaluateDocumentVariables, type DocumentVariable } from "./variables";
import { authoredTextDrawing } from "./text-expressions";
import { putSketchText } from "../sketch/text/edit";

const definitions = (text: string): DocumentVariable[] => [
  { name: "label", kind: "string", expression: JSON.stringify(text) },
];
async function document() {
  const doc = createEmptyPartDocument("Variable text");
  doc.variables = definitions("O");
  const font = readFileSync(
    new URL(
      "../../../assets/fonts/noto-sans/NotoSans-Regular.ttf",
      import.meta.url,
    ),
  );
  const profile = await putSketchText(
    { type: "drawing", contours: [] },
    {
      text: "O",
      expression: "#label",
      expressionVariables: evaluateDocumentVariables(doc.variables),
      fontBytes: Uint8Array.from(font).buffer,
      emSizeMillimeters: 10,
      originMillimeters: [0, 0],
      frameWidthMillimeters: 30,
    },
  );
  doc.features.push({
    id: "text",
    type: "profile",
    name: "Text",
    plane: "XY",
    offsetMillimeters: 0,
    suppressed: false,
    profile,
  });
  return doc;
}

it("rejects stale or unresolved native text even in suppressed history", async () => {
  const doc = await document();
  doc.features[0].suppressed = true;
  doc.rollbackIndex = 0;
  doc.variables = definitions("OO");
  expect(() => validatePartDocument(doc)).toThrow(/Stale text expression/);
  expect(() => parsePartDocument(JSON.stringify(doc))).toThrow(
    /Stale text expression/,
  );
  delete doc.variables;
  expect(() => validatePartDocument(doc)).toThrow(/Unknown variable/);
});

it("updates and reopens a whole document including suppressed and projected authored text", async () => {
  const doc = await document();
  const authored = structuredClone(authoredTextDrawing(doc.features[0])!);
  // Distinct authored identities, independent of projected source identities.
  const renamed = JSON.parse(
    JSON.stringify(authored).replaceAll("text-", "other-"),
  );
  doc.features.push({
    id: "projected",
    type: "profile",
    name: "Projected text",
    plane: "XY",
    offsetMillimeters: 0,
    suppressed: true,
    profile: { type: "projection", sourceFeatureId: "text", authored: renamed },
  });
  doc.rollbackIndex = 0;
  const before = structuredClone(doc);
  const next = await updatePartDocumentVariables(doc, definitions("OO"));
  expect(doc).toEqual(before);
  const reopened = parsePartDocument(serializePartDocument(next));
  for (const feature of reopened.features) {
    const drawing = authoredTextDrawing(feature)!;
    expect(drawing.textItems![0].text).toBe("OO");
    expect(drawing.textItems![0].expression).toBe("#label");
    expect(drawing.projectionContext).toBeUndefined();
  }
  expect(reopened.rollbackIndex).toBe(0);
  expect(reopened.features[1].suppressed).toBe(true);
});

it("rejects invalid variable edits atomically and does not replace unchanged text edges", async () => {
  const doc = await document(),
    before = structuredClone(doc);
  const next = await updatePartDocumentVariables(doc, [
    ...definitions("O"),
    { name: "extra", kind: "number", expression: "2+3" },
  ]);
  expect(next.features).toEqual(doc.features);
  await expect(updatePartDocumentVariables(doc, undefined)).rejects.toThrow(
    /Unknown variable/,
  );
  await expect(
    updatePartDocumentVariables(doc, definitions("\u{10ffff}")),
  ).rejects.toThrow();
  await expect(
    updatePartDocumentVariables(doc, [
      { name: "label", kind: "string", expression: "#label" },
    ]),
  ).rejects.toThrow(/Circular/);
  expect(doc).toEqual(before);
});

it("snapshots caller inputs before asynchronous font regeneration", async () => {
  const doc = await document(),
    vars = definitions("OO");
  const pending = updatePartDocumentVariables(doc, vars);
  vars[0].expression = '"O"';
  doc.name = "Changed by caller";
  const result = await pending;
  expect(result.name).toBe("Variable text");
  expect(result.variables).toEqual(definitions("OO"));
  expect(authoredTextDrawing(result.features[0])!.textItems![0].text).toBe(
    "OO",
  );
});

it("allows clearing unused variables without adding persisted caches", async () => {
  const doc = createEmptyPartDocument("Empty");
  doc.variables = definitions("O");
  const next = await updatePartDocumentVariables(doc, undefined);
  expect(next.variables).toBeUndefined();
  expect(parsePartDocument(serializePartDocument(next))).toEqual(next);
});

it("rejects updates that orphan a downstream selected-glyph projection", async () => {
  const doc = await document();
  const id = authoredTextDrawing(doc.features[0])!.textItems![0].contourIds[0];
  doc.features.push({
    id: "dependent",
    type: "profile",
    name: "Selected letter",
    plane: "XY",
    offsetMillimeters: 0,
    suppressed: true,
    profile: {
      type: "projection",
      sourceFeatureId: "text",
      sourceContourId: id,
    },
  });
  const before = structuredClone(doc);
  await expect(
    updatePartDocumentVariables(doc, definitions("OO")),
  ).rejects.toThrow(/Broken projection contour reference/);
  expect(doc).toEqual(before);
  expect(
    (await updatePartDocumentVariables(doc, definitions("O"))).features,
  ).toEqual(doc.features);
});

it("commits an edited sketch and removed variable together without validating the discarded binding", async () => {
  const doc = await document();
  const draft = structuredClone(doc.features[0]);
  if (draft.type !== "profile" || draft.profile.type !== "drawing")
    throw Error();
  delete draft.profile.textItems![0].expression;
  const next = await updatePartDocumentVariables(doc, undefined, draft);
  expect(next.variables).toBeUndefined();
  expect(
    authoredTextDrawing(next.features[0])!.textItems![0].expression,
  ).toBeUndefined();
  expect(authoredTextDrawing(doc.features[0])!.textItems![0].expression).toBe(
    "#label",
  );
});

it("inserts a draft at rollback with newly defined variables in one transaction", async () => {
  const template = await document(),
    draft = template.features[0];
  if (draft.type !== "profile") throw Error();
  const source = createEmptyPartDocument("New draft");
  source.rollbackIndex = 0;
  const next = await updatePartDocumentVariables(
    source,
    definitions("OO"),
    draft,
  );
  expect(next.rollbackIndex).toBe(1);
  expect(authoredTextDrawing(next.features[0])!.textItems![0].text).toBe("OO");
  expect(source.features).toHaveLength(0);
});
