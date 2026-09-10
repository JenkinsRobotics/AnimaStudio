import { describe, expect, it } from "vitest";
import {
  ProjectionDecodeError,
  array,
  boolean,
  nullableNumber,
  nullableString,
  number,
  oneOf,
  record,
  string,
  stringArray,
  text,
  tuple,
} from "./cad-bridge-decode";

describe("shared bridge decoder primitives", () => {
  it("accepts the shared structural vocabulary", () => {
    expect(record({ id: "one" }, "root")).toEqual({ id: "one" });
    expect(array([1], "items")).toEqual([1]);
    expect(string("one", "id")).toBe("one");
    expect(text("", "description")).toBe("");
    expect(nullableString(null, "label")).toBeNull();
    expect(boolean(false, "enabled")).toBe(false);
    expect(number(1.5, "value_mm")).toBe(1.5);
    expect(nullableNumber(null, "value_rad")).toBeNull();
    expect(oneOf("ready", ["ready", "error"], "state")).toBe("ready");
    expect(tuple([0, 1], 2, "point_sheet_mm")).toEqual([0, 1]);
    expect(() => stringArray(["one", "two"], "ids")).not.toThrow();
  });

  it("reports exact paths and rejects empty, non-finite, and malformed values", () => {
    expect(() => string("", "root.id")).toThrowError(
      new ProjectionDecodeError("root.id", "expected non-empty string"),
    );
    expect(() => number(Number.NaN, "root.width_mm")).toThrow(
      "root.width_mm: expected finite number",
    );
    expect(() => tuple([0, 1, 2], 2, "root.point_sheet_mm")).toThrow(
      "root.point_sheet_mm: expected 2 numbers",
    );
    expect(() => oneOf("other", ["ready", "error"], "root.state")).toThrow(
      "root.state: expected one of ready, error",
    );
  });
});
