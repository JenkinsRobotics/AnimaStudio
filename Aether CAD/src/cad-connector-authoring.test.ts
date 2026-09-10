import { describe, expect, it } from "vitest";
import {
  assemblyConnectorDraftIssues,
  defaultAssemblyConnectorDraft,
  normalizeAssemblyConnectorDraft,
} from "./cad-connector-authoring";

describe("Assembly connector authoring draft", () => {
  it("normalizes one explicit Part-local frame", () => {
    expect(normalizeAssemblyConnectorDraft({
      ...defaultAssemblyConnectorDraft,
      name: "  Shaft axis  ",
      provenanceLabel: "  Datum A  ",
      originM: [0.1, -0.2, 0.3],
      primaryAxis: "negative-y",
      secondaryAxis: "positive-z",
    })).toEqual({
      name: "Shaft axis",
      provenanceLabel: "Datum A",
      originM: [0.1, -0.2, 0.3],
      primaryAxisXYZ: [0, -1, 0],
      secondaryAxisXYZ: [0, 0, 1],
    });
  });

  it("rejects missing identity, invalid meter values, and parallel axes", () => {
    expect(assemblyConnectorDraftIssues({
      ...defaultAssemblyConnectorDraft,
      name: " ",
      originM: [Number.NaN, 0, 0],
      primaryAxis: "positive-x",
      secondaryAxis: "negative-x",
    })).toEqual([
      "Connector name is required.",
      "Origin must contain finite values in meters.",
      "Primary and secondary axes must not be parallel.",
    ]);
  });
});
