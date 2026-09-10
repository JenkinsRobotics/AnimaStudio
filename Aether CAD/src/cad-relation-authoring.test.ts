import { describe, expect, it } from "vitest";
import {
  assemblyRelationDraftIssues,
  assemblyRelationPayload,
  defaultAssemblyRelationDraft,
} from "./cad-relation-authoring";

const options = [
  { id: "rotation-a", label: "Pivot A", kind: "rotation" as const },
  { id: "rotation-b", label: "Pivot B", kind: "rotation" as const },
  { id: "translation-a", label: "Slide A", kind: "translation" as const },
];

describe("Assembly relation authoring", () => {
  it("creates unit-correct gear and mixed relation payloads", () => {
    expect(assemblyRelationPayload({
      ...defaultAssemblyRelationDraft,
      driverDOFID: "rotation-a",
      drivenDOFID: "rotation-b",
      ratio: 2,
      offset: 15,
      reversed: true,
    }, options)).toEqual({
      kind: "gear",
      driver_dof_id: "rotation-a",
      driven_dof_id: "rotation-b",
      ratio: -2,
      offset_rad: Math.PI / 12,
      offset_m: null,
      reversed: true,
      suppressed: false,
    });
    expect(assemblyRelationPayload({
      ...defaultAssemblyRelationDraft,
      kind: "rack_pinion",
      driverDOFID: "rotation-a",
      drivenDOFID: "translation-a",
      ratio: 0.01,
      offset: 0.02,
    }, options)).toEqual(expect.objectContaining({ ratio: 0.01, offset_rad: null, offset_m: 0.02 }));
  });

  it("rejects incompatible, duplicate, and zero-ratio endpoints", () => {
    expect(assemblyRelationDraftIssues({
      ...defaultAssemblyRelationDraft,
      driverDOFID: "rotation-a",
      drivenDOFID: "rotation-a",
      ratio: 0,
    }, options)).toEqual([
      "A relation cannot drive the same DOF.",
      "A positive finite ratio is required.",
    ]);
  });
});
