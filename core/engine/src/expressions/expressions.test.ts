import { it, expect } from "vitest";
import { evaluateExpression as evaluate } from "./evaluate";
import { quantity, scalar } from "./values";
it.each([
  ["25.4mm / in", 1],
  ["1m / mm", 1000],
  ["2 cm + 5mm", 0.025],
  ["sin(90deg)", 1],
  ["cos(pi)", -1],
  ["asin(1)/deg", 90],
  ["sqrt((3mm)^2 + (4mm)^2)/mm", 5],
  ["atan2(1mm,1mm)/deg", 45],
  ["min(2cm,15mm)/mm", 15],
  ["roundToPrecision(1/3,3)", 0.333],
])("evaluates typed expression %s", (expression, value) => {
  const result = evaluate(expression);
  expect(typeof result).not.toBe("string");
  if (typeof result === "string") throw Error();
  expect(result.magnitudeSI).toBeCloseTo(value);
});
it("combines quantity variables, unit conversion and text without erasing dimensions", () => {
  const variables = new Map([
    ["Length", quantity(127, 1)],
    ["count", quantity(4)],
  ]);
  const context = {
    resolveVariable: (name: string) => {
      const v = variables.get(name);
      if (!v) throw Error("missing");
      return v;
    },
  };
  expect(
    evaluate(
      'roundToPrecision(#Length/in, 3) ~ " in / " ~ #count ~ " pieces"',
      context,
    ),
  ).toBe("5000 in / 4 pieces");
  expect(() => evaluate('#Length ~ " mm"', context)).toThrow(/dimensionless/);
  expect(scalar(evaluate("#Length/(1m)", context))).toBe(127);
});
it.each([
  "1mm+1deg",
  "sin(2mm)",
  "sqrt(-1)",
  "1/0",
  "min(1mm,2)",
  "roundToPrecision(1,100)",
  "#missing",
  "globalThis.alert(1)",
  "constructor(1)",
  "Math.PI",
  "2 3",
  "2**3",
  '"a" + "b"',
])("rejects invalid or incompatible expression %s", (source) =>
  expect(() => evaluate(source)).toThrow(),
);
it("bounds input and nesting without evaluating source code", () => {
  expect(() => evaluate("1".repeat(4097))).toThrow();
  expect(() => evaluate("(".repeat(80) + "1" + ")".repeat(80))).toThrow(
    /deeply/,
  );
  expect(evaluate('"quoted: \\"hello\\""')).toBe('quoted: "hello"');
});
