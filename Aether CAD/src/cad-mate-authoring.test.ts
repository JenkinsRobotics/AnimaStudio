import { describe, expect, it } from "vitest";
import {
  assemblyMateDraftIssues,
  assemblyMateDOFEditorDraft,
  assemblyMateDOFEditorIssues,
  assemblyMateDOFLimitsPayload,
  assemblyMateDOFValuePayload,
  assemblyMatePayload,
  assemblyMateUpdatePayload,
  canApplyAssemblyMate,
  defaultAssemblyMateDraft,
} from "./cad-mate-authoring";

describe("Assembly mate authoring draft", () => {
  it("builds one Core command payload from stable endpoint IDs", () => {
    expect(assemblyMatePayload({
      ...defaultAssemblyMateDraft,
      name: " Pivot ",
      typeID: "revolute",
      endpointA: { instanceID: "base-1", connectorDefinitionID: "base-axis" },
      endpointB: { instanceID: "arm-1", connectorDefinitionID: "arm-axis" },
    })).toEqual({
      name: "Pivot",
      type_id: "revolute",
      endpoint_a: { instance_id: "base-1", connector_definition_id: "base-axis" },
      endpoint_b: { instance_id: "arm-1", connector_definition_id: "arm-axis" },
      dofs: [],
      controls: [],
    });

    expect(assemblyMateUpdatePayload({
      id: "mate-1",
      name: "Pivot",
      type_id: "revolute",
      endpoint_a: { instance_id: "base-1", connector_definition_id: "base-axis" },
      endpoint_b: { instance_id: "arm-1", connector_definition_id: "arm-axis" },
      dofs: [{
        id: "dof-1",
        name: "rotation",
        kind: "rotation",
        value_rad: 0.25,
        value_m: null,
        neutral_rad: 0,
        neutral_m: null,
        limit_min_rad: -1,
        limit_max_rad: 1,
        limit_min_m: null,
        limit_max_m: null,
        state: "free",
      }],
      controls: [{ key: "flip", value: true }],
      suppressed: false,
      solve_state: "satisfied",
      diagnostic_ids: [],
    }, { suppressed: true })).toEqual({
      id: "mate-1",
      name: "Pivot",
      type_id: "revolute",
      endpoint_a: { instance_id: "base-1", connector_definition_id: "base-axis" },
      endpoint_b: { instance_id: "arm-1", connector_definition_id: "arm-axis" },
      dofs: [{
        name: "rotation",
        value_rad: 0.25,
        neutral_rad: 0,
        limit_min_rad: -1,
        limit_max_rad: 1,
      }],
      controls: [{ key: "flip", value: true }],
      suppressed: true,
    });
  });

  it("requires identity and two different instance endpoints", () => {
    expect(assemblyMateDraftIssues({
      ...defaultAssemblyMateDraft,
      name: " ",
      endpointA: { instanceID: "same", connectorDefinitionID: "connector-a" },
      endpointB: { instanceID: "same", connectorDefinitionID: "connector-b" },
    })).toEqual([
      "Mate name is required.",
      "Mate endpoints must use different component instances.",
    ]);
    expect(assemblyMateDraftIssues(defaultAssemblyMateDraft)).toEqual([
      "Moving endpoint is required.",
      "Target endpoint is required.",
    ]);

    const validDraft = {
      ...defaultAssemblyMateDraft,
      endpointA: { instanceID: "base-1", connectorDefinitionID: "base-axis" },
      endpointB: { instanceID: "arm-1", connectorDefinitionID: "arm-axis" },
    };
    expect(canApplyAssemblyMate(validDraft, "revision-12", {
      state: "ready",
      revision: "revision-12",
      solveStatus: "solved",
    })).toBe(true);
    expect(canApplyAssemblyMate(validDraft, "revision-12", {
      state: "ready",
      revision: "revision-11",
      solveStatus: "solved",
    })).toBe(false);
  });

  it("projects degree/meter editor values into unit-correct Core payloads", () => {
    const mate = {
      id: "mate-1",
      name: "Pivot",
      type_id: "revolute",
      endpoint_a: { instance_id: "base-1", connector_definition_id: "base-axis" },
      endpoint_b: { instance_id: "arm-1", connector_definition_id: "arm-axis" },
      dofs: [{
        id: "dof-1", name: "rotation", kind: "rotation" as const,
        value_rad: Math.PI / 4, value_m: null,
        neutral_rad: 0, neutral_m: null,
        limit_min_rad: -Math.PI / 2, limit_max_rad: Math.PI / 2,
        limit_min_m: null, limit_max_m: null, state: "free" as const,
      }],
      controls: [], suppressed: false, solve_state: "satisfied" as const, diagnostic_ids: [],
    };
    const draft = assemblyMateDOFEditorDraft(mate.dofs[0]);
    expect(draft).toMatchObject({ value: 45, minimum: -90, maximum: 90, limitsEnabled: true });
    expect(assemblyMateDOFValuePayload({ ...draft, value: 30 })).toEqual({
      dof_id: "dof-1",
      value_rad: Math.PI / 6,
    });
    expect(assemblyMateDOFLimitsPayload(mate, {
      ...draft,
      minimum: -60,
      maximum: 120,
    })).toEqual(expect.objectContaining({
      id: "mate-1",
      dofs: [expect.objectContaining({
        value_rad: Math.PI / 4,
        limit_min_rad: -Math.PI / 3,
        limit_max_rad: 2 * Math.PI / 3,
      })],
    }));
    expect(assemblyMateDOFEditorIssues({ ...draft, minimum: 90, maximum: -90 }, "limits"))
      .toEqual(["Minimum must be less than maximum."]);
    expect(assemblyMateDOFLimitsPayload(mate, { ...draft, limitsEnabled: false }))
      .toEqual(expect.objectContaining({
        dofs: [expect.objectContaining({ limit_min_rad: null, limit_max_rad: null })],
      }));

    const translation = {
      ...draft,
      dofID: "dof-2",
      kind: "translation" as const,
      value: 0.025,
      limitsEnabled: false,
      minimum: null,
      maximum: null,
    };
    expect(assemblyMateDOFValuePayload(translation)).toEqual({ dof_id: "dof-2", value_m: 0.025 });
  });
});
