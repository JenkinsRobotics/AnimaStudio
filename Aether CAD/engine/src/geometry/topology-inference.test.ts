import { describe, expect, it } from "vitest";
import {
  connectorKindPreference,
  cylinderAxisStations,
  sameOrigin,
} from "./topology-inference";

describe("exact-topology connector policy", () => {
  it("retains trimmed cylinder ends and axis center", () => {
    expect(cylinderAxisStations(-12, 28)).toEqual([
      { role: "start", parameter: -12 },
      { role: "center", parameter: 8 },
      { role: "end", parameter: 28 },
    ]);
  });

  it("prefers analytic feature centers over generic candidates", () => {
    expect(connectorKindPreference("cylinder-axis")).toBeLessThan(
      connectorKindPreference("circle-center"),
    );
    expect(sameOrigin([1, 2, 3], [1 + 1e-9, 2, 3])).toBe(true);
  });
});
