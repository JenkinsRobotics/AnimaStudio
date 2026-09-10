import { describe, expect, it } from "vitest";
import {
  assemblyComponentDraftIssues,
  defaultAssemblyComponentDraft,
  normalizeAssemblyComponentDraft,
} from "./cad-assembly-authoring";

describe("Assembly component authoring draft", () => {
  it("normalizes display text while preserving explicit SI values", () => {
    expect(normalizeAssemblyComponentDraft({
      ...defaultAssemblyComponentDraft,
      partName: "  Bracket  ",
      partNumber: " BR-100 ",
      sourceLabel: " bracket.cadpart ",
      instanceName: " Bracket:1 ",
      massKg: 0.25,
      positionM: [0.1, -0.2, 0.3],
      grounded: true,
    })).toEqual({
      partName: "Bracket",
      partNumber: "BR-100",
      sourceLabel: "bracket.cadpart",
      instanceName: "Bracket:1",
      massKg: 0.25,
      positionM: [0.1, -0.2, 0.3],
      grounded: true,
    });
  });

  it("permits unknown mass and rejects missing identity or invalid SI values", () => {
    expect(assemblyComponentDraftIssues({
      ...defaultAssemblyComponentDraft,
      massKg: null,
    })).toEqual([]);
    expect(assemblyComponentDraftIssues({
      ...defaultAssemblyComponentDraft,
      partName: " ",
      sourceLabel: "",
      massKg: -1,
      positionM: [0, Number.NaN, 0],
    })).toEqual([
      "Part name is required.",
      "Source label is required.",
      "Mass must be a non-negative value in kilograms.",
      "Position must contain finite values in meters.",
    ]);
  });
});
