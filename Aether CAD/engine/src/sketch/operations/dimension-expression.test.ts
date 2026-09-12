import { expect, it } from "vitest";
import {
  setDimensionExpression,
  regenerateDimensionExpressions,
} from "./dimension-expression";
import { evaluateDocumentVariables } from "../../document/variables";
import { createEmptyPartDocument } from "../../document/part-document";
import {
  parsePartDocument,
  serializePartDocument,
} from "../../document/part-serialization";
import { updatePartDocumentVariables } from "../../document/update-variables";
import { editDrawingDimension } from "./edit-dimension";
import { setDimensionReference } from "./dimension-reference";
import { linkSketchDimension } from "./link-dimension";
import { validateSketchDrawing, type SketchDrawing } from "../drawing";
const definitions = (expression = "20 mm") => [
  { name: "diameter", kind: "length" as const, expression },
];
const values = (expression = "20 mm") =>
  evaluateDocumentVariables(definitions(expression));
const drawing = (): SketchDrawing => ({
  type: "drawing",
  contours: [
    { type: "circle", center: [0, 0], radius: 5 },
    { type: "circle", center: [20, 0], radius: 10 },
  ],
  constraints: [
    {
      id: "radius",
      kind: "radius",
      a: { kind: "circle", contour: 0 },
      value: 5,
    },
    {
      id: "follower",
      kind: "radius",
      a: { kind: "circle", contour: 1 },
      valueFrom: "radius",
      valueScale: 2,
    },
  ],
});

it("binds typed length formulas and resizes linked followers atomically", () => {
  const source = drawing();
  const bound = setDimensionExpression(
    source,
    "radius",
    "#diameter/2",
    values(),
  );
  expect(bound.contours[0]).toMatchObject({ radius: expect.closeTo(10) });
  expect(bound.contours[1]).toMatchObject({ radius: expect.closeTo(20) });
  const updated = regenerateDimensionExpressions(bound, values("30 mm"));
  expect(updated.contours[0]).toMatchObject({ radius: expect.closeTo(15) });
  expect(updated.contours[1]).toMatchObject({ radius: expect.closeTo(30) });
  expect(source.constraints![0].valueExpression).toBeUndefined();
  expect(() => editDrawingDimension(bound, "follower", 30)).toThrow(/formula/);
});

it("requires compatible explicit units and rejects invalid updates without changing geometry", () => {
  const source = drawing(),
    before = structuredClone(source);
  for (const expression of [
    "2",
    "10 deg",
    "#missing",
    '"hello"',
    "-2 mm",
    "#diameter +",
  ]) {
    expect(() =>
      setDimensionExpression(source, "radius", expression, values()),
    ).toThrow();
  }
  expect(source).toEqual(before);
  const bound = setDimensionExpression(
    source,
    "radius",
    "#diameter/2",
    values(),
  );
  expect(() =>
    regenerateDimensionExpressions(bound, values("-20 mm")),
  ).toThrow();
  expect(bound.constraints![0].value).toBe(10);
});

it("supports explicit removal and conversion to links or reference measurements", () => {
  const bound = setDimensionExpression(
    drawing(),
    "radius",
    "#diameter/2",
    values(),
  );
  const literal = setDimensionExpression(bound, "radius", null, new Map());
  expect(literal.constraints![0].valueExpression).toBeUndefined();
  expect(editDrawingDimension(literal, "radius", 7).contours[1]).toMatchObject({
    radius: expect.closeTo(14),
  });
  expect(
    setDimensionReference(bound, "radius", true).constraints![0]
      .valueExpression,
  ).toBeUndefined();
  const independent = setDimensionExpression(
    bound,
    "follower",
    "40 mm",
    values(),
  );
  expect(
    linkSketchDimension(independent, "radius", "follower").constraints![0]
      .valueExpression,
  ).toBeUndefined();
  const invalid = structuredClone(bound);
  invalid.constraints![0].reference = true;
  expect(() => validateSketchDrawing(invalid)).toThrow(/independent driving/);
});

it("persists formulas and rejects stale caches until the document transaction regenerates them", async () => {
  const doc = createEmptyPartDocument("Formula radius");
  doc.variables = definitions();
  doc.features.push({
    id: "s",
    type: "profile",
    name: "Circles",
    plane: "XY",
    offsetMillimeters: 0,
    suppressed: false,
    profile: setDimensionExpression(
      drawing(),
      "radius",
      "#diameter/2",
      values(),
    ),
  });
  const reopened = parsePartDocument(serializePartDocument(doc));
  const stale = structuredClone(reopened);
  stale.variables = definitions("30 mm");
  expect(() => serializePartDocument(stale)).toThrow(/Stale dimension/);
  const updated = await updatePartDocumentVariables(
    reopened,
    definitions("30 mm"),
  );
  const profile = updated.features[0];
  if (profile.type !== "profile" || profile.profile.type !== "drawing")
    throw Error();
  expect(profile.profile.contours[1]).toMatchObject({
    radius: expect.closeTo(30),
  });
  expect(parsePartDocument(serializePartDocument(updated))).toEqual(updated);
});

it("converts angular SI expressions to saved degrees", () => {
  const source: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [0, 0],
        segments: [
          { type: "line", end: [10, 0] },
          { type: "line", end: [10, 10] },
        ],
      },
    ],
    constraints: [
      {
        id: "angle",
        kind: "angle",
        a: { kind: "line", contour: 0, index: 0 },
        b: { kind: "line", contour: 0, index: 1 },
        value: 90,
      },
    ],
  };
  const bound = setDimensionExpression(
    source,
    "angle",
    "pi/2 * rad",
    new Map(),
  );
  expect(bound.constraints![0].value).toBe(90);
  expect(() =>
    setDimensionExpression(source, "angle", "2 mm", new Map()),
  ).toThrow(/angle/);
});
