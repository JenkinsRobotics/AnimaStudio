import { expect, it } from "vitest";
import { displayQuantity, parseQuantity, unitCatalog } from "./units";
it("converts inch, pound and angle inputs into canonical SI without changing stored geometry", () => {
  expect(
    parseQuantity("1", { length: { unit: "in", decimals: 3 } }, "length"),
  ).toBeCloseTo(0.0254, 12);
  expect(
    displayQuantity(0.0254, { length: { unit: "in", decimals: 4 } }, "length"),
  ).toBe("1.0000");
  expect(
    parseQuantity("1", { mass: { unit: "lb", decimals: 3 } }, "mass"),
  ).toBe(0.45359237);
  expect(
    parseQuantity("180", { angle: { unit: "deg", decimals: 3 } }, "angle"),
  ).toBeCloseTo(Math.PI, 12);
  expect(() => parseQuantity("NaN", {}, "mass")).toThrow();
});
it("roundtrips every supported engineering unit through its SI factor", () => {
  for (const family of Object.keys(unitCatalog) as (keyof typeof unitCatalog)[])
    for (const unit of Object.keys(unitCatalog[family].options)) {
      const preferences = { [family]: { unit, decimals: 6 } };
      expect(
        Number(
          displayQuantity(
            parseQuantity("12.5", preferences, family),
            preferences,
            family,
          ),
        ),
      ).toBeCloseTo(12.5, 6);
    }
});
it("evaluates arithmetic before applying the selected unit", () => {
  expect(
    parseQuantity("1/8", { length: { unit: "in", decimals: 3 } }, "length"),
  ).toBeCloseTo(0.003175, 12);
  expect(
    parseQuantity("pi / 2", { angle: { unit: "rad", decimals: 3 } }, "angle"),
  ).toBeCloseTo(Math.PI / 2, 12);
});
