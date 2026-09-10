import { it, expect } from "vitest";
import { evaluateDocumentVariables, type DocumentVariable } from "./variables";
import { createEmptyPartDocument } from "./part-document";
import { parsePartDocument, serializePartDocument } from "./part-serialization";
it("resolves typed dependencies independent of row order and persists only definitions", () => {
  const variables: DocumentVariable[] = [
    {
      name: "label",
      kind: "string",
      expression:
        '"Wheel " ~ #count ~ " / " ~ roundToPrecision(#diameter/mm, 2) ~ " mm"',
    },
    { name: "diameter", kind: "length", expression: "2 * #radius" },
    { name: "count", kind: "number", expression: "3+1" },
    { name: "radius", kind: "length", expression: "1in" },
    { name: "angle", kind: "angle", expression: "atan2(1,1)" },
  ];
  const doc = createEmptyPartDocument("Variables");
  doc.variables = variables;
  const saved = parsePartDocument(serializePartDocument(doc));
  expect(saved.variables).toEqual(variables);
  const result = evaluateDocumentVariables(saved.variables);
  expect(result.get("label")).toBe("Wheel 4 / 50.8 mm");
  expect(result.get("diameter")).toEqual({
    magnitudeSI: 0.0508,
    lengthPower: 1,
    anglePower: 0,
  });
  expect(saved).not.toHaveProperty("resolvedVariables");
});
it.each([
  {
    variables: [{ name: "a", kind: "number", expression: "#a" }],
    error: /Circular/,
  },
  {
    variables: [
      { name: "a", kind: "number", expression: "#b" },
      { name: "b", kind: "number", expression: "#a" },
    ],
    error: /Circular/,
  },
  {
    variables: [{ name: "a", kind: "number", expression: "#missing" }],
    error: /Unknown variable/,
  },
  {
    variables: [{ name: "a", kind: "length", expression: "2deg" }],
    error: /incompatible units/,
  },
  {
    variables: [{ name: "a", kind: "string", expression: "2" }],
    error: /must resolve to text/,
  },
  {
    variables: [
      { name: "a", kind: "number", expression: "1" },
      { name: "a", kind: "number", expression: "2" },
    ],
    error: /unique identifiers/,
  },
])(
  "rejects invalid variable definitions $variables",
  ({ variables, error }) => {
    const doc = createEmptyPartDocument("Invalid");
    doc.variables = variables as DocumentVariable[];
    expect(() => serializePartDocument(doc)).toThrow(error);
  },
);
it("handles names through a map, not prototype properties", () => {
  const result = evaluateDocumentVariables([
    { name: "__proto__", kind: "number", expression: "7" },
    { name: "constructor", kind: "number", expression: "#__proto__+1" },
  ]);
  expect(result.get("constructor")).toEqual({
    magnitudeSI: 8,
    lengthPower: 0,
    anglePower: 0,
  });
});
