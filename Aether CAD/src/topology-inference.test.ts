import { describe, expect, it } from "vitest";
import {
  connectorKindPreference,
  cylinderAxisStations,
  sameOrigin,
} from "./topology-inference";

describe("cylinder connector inference", () => {
  it("returns both trimmed ends and the exact axis center", () => {
    expect(cylinderAxisStations(-12, 28)).toEqual([
      { role: "start", parameter: -12 },
      { role: "center", parameter: 8 },
      { role: "end", parameter: 28 },
    ]);
  });

  it("preserves the OCCT parameter direction", () => {
    expect(cylinderAxisStations(10, -2)).toEqual([
      { role: "start", parameter: 10 },
      { role: "center", parameter: 4 },
      { role: "end", parameter: -2 },
    ]);
  });

  it("does not invent endpoints for unbounded cylinders", () => {
    expect(cylinderAxisStations(Number.NEGATIVE_INFINITY, 15)).toEqual([
      { role: "center", parameter: 0 },
    ]);
  });

  it("collapses a degenerate axial trim to one center", () => {
    expect(cylinderAxisStations(3, 3 + 1e-10)).toHaveLength(1);
  });

  it("recognizes spatially coincident feature anchors", () => {
    expect(sameOrigin([1, 2, 3], [1 + 1e-9, 2, 3])).toBe(true);
    expect(sameOrigin([1, 2, 3], [1.01, 2, 3])).toBe(false);
  });

  it("prefers analytic feature centers over generic face centers", () => {
    expect(connectorKindPreference("circle-center")).toBeLessThan(
      connectorKindPreference("face-center"),
    );
    expect(connectorKindPreference("cylinder-axis")).toBeLessThan(
      connectorKindPreference("circle-center"),
    );
  });
});
