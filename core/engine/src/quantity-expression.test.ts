import { expect, it } from "vitest";
import { evaluateQuantityExpression as calculate } from "./quantity-expression";
it.each([
  ["(12 + 4) / 2", 8],
  ["1/8", 0.125],
  ["2+3*4", 14],
  ["2^3^2", 512],
  ["-2^2", -4],
  ["(-2)^2", 4],
  ["2^-3", 0.125],
  ["2*pi", 2 * Math.PI],
  ["π / 2", Math.PI / 2],
  ["1e-3 + .25", 0.251],
  ["3 − 2", 1],
])("evaluates %s", (source, value) =>
  expect(calculate(source)).toBeCloseTo(value, 12),
);
it.each([
  "",
  "1/0",
  "0/0",
  "1e309",
  "(-1)^.5",
  "2+",
  "(2+3",
  "2 3",
  "2mm",
  "width*2",
  "Math.PI",
  "globalThis.alert(1)",
  "2**3",
  "0x10",
  "()",
  "pi2",
])("rejects invalid or unsupported input %s", (source) =>
  expect(() => calculate(source)).toThrow(),
);
it("bounds expression length and recursive nesting", () => {
  expect(() => calculate("1".repeat(513))).toThrow();
  expect(() => calculate("(".repeat(80) + "1" + ")".repeat(80))).toThrow(
    "nested too deeply",
  );
});
it.each([
  ["sqrt(3^2+4^2)", 5],
  ["sin(pi/2)", 1],
  ["roundToPrecision(1/3,2)", 0.33],
  ["max(4,8,2)", 8],
])("supports shared numeric function %s", (source, value) =>
  expect(calculate(source)).toBeCloseTo(value),
);
