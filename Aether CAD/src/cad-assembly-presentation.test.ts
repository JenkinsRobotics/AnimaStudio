import { describe, expect, it } from "vitest";
import type {
  AssemblyProjectionV1,
  AssemblySolutionProjection,
  BOMProjectionV1,
} from "./cad-assembly-bridge";
import { buildCADAssemblyPresentation } from "./cad-assembly-presentation";

const transform = {
  position_m: [0, 0, 0],
  rotation_quaternion_xyzw: [0, 0, 0, 1],
} as const;

function fixture(): AssemblyProjectionV1 {
  return {
    schema_version: 1,
    workspace_id: "workspace-1",
    revision: "revision-4",
    assembly_id: "assembly-1",
    capabilities: {
      can_edit_instances: true,
      can_edit_connectors: false,
      supported_mate_type_ids: ["fastened", "revolute", "prismatic"],
      can_edit_relations: false,
      can_solve_tree: true,
      can_solve_loops: false,
      can_edit_nested_assemblies: true,
      can_project_bom: true,
      can_save_workspace: false,
      unavailable_reasons: [
        { capability_id: "can_edit_connectors", reason: "Workspace is read-only." },
        { capability_id: "can_edit_relations", reason: "Relations are not available." },
        { capability_id: "can_save_workspace", reason: "Workspace is linked read-only." },
      ],
    },
    assemblies: [{ id: "assembly-1", name: "Drive Assembly", description: null, root_instance_ids: ["instance-base"] }],
    part_definitions: [
      {
        id: "part-base",
        name: "Base",
        part_number: "BASE-01",
        description: null,
        material_id: null,
        mass_kg: 0.4,
        source: { kind: "linked", label: "Base.aether", asset_ref: "assets/base", status: "read_only" },
        custom_properties: [],
      },
      {
        id: "part-arm",
        name: "Arm",
        part_number: "ARM-01",
        description: null,
        material_id: null,
        mass_kg: 0.2,
        source: { kind: "authored", label: "Arm", asset_ref: null, status: "resolved" },
        custom_properties: [],
      },
    ],
    instances: [
      {
        id: "instance-base",
        parent_assembly_id: "assembly-1",
        definition_kind: "part",
        definition_id: "part-base",
        name: "Base:1",
        parent_instance_id: null,
        rest_transform: transform,
        solved_world_transform: transform,
        grounded: true,
        suppressed: false,
        visible: true,
        source_status: "read_only",
      },
      {
        id: "instance-arm",
        parent_assembly_id: "assembly-1",
        definition_kind: "part",
        definition_id: "part-arm",
        name: "Arm:1",
        parent_instance_id: "instance-base",
        rest_transform: transform,
        solved_world_transform: transform,
        grounded: false,
        suppressed: false,
        visible: true,
        source_status: "resolved",
      },
    ],
    connector_definitions: [
      {
        id: "connector-base",
        part_definition_id: "part-base",
        name: "Base pivot",
        frame_part_local: { origin_m: [0, 0, 0], primary_axis_xyz: [0, 0, 1], secondary_axis_xyz: [1, 0, 0] },
        provenance: { kind: "face", stable_feature_id: "face-1", label: "Pivot face" },
        suppressed: false,
      },
      {
        id: "connector-arm",
        part_definition_id: "part-arm",
        name: "Arm pivot",
        frame_part_local: { origin_m: [0, 0, 0], primary_axis_xyz: [0, 0, 1], secondary_axis_xyz: [1, 0, 0] },
        provenance: { kind: "face", stable_feature_id: "face-2", label: "Pivot face" },
        suppressed: false,
      },
    ],
    mates: [
      {
        id: "mate-pivot",
        name: "Pivot",
        type_id: "revolute",
        endpoint_a: { instance_id: "instance-base", connector_definition_id: "connector-base" },
        endpoint_b: { instance_id: "instance-arm", connector_definition_id: "connector-arm" },
        dofs: [
          {
            id: "dof-pivot",
            name: "Rotation",
            kind: "rotation",
            value_rad: 0,
            value_m: null,
            neutral_rad: 0,
            neutral_m: null,
            limit_min_rad: -1,
            limit_max_rad: 1,
            limit_min_m: null,
            limit_max_m: null,
            state: "free",
          },
        ],
        controls: [],
        suppressed: false,
        solve_state: "warning",
        diagnostic_ids: ["issue-unconverged"],
      },
    ],
    relations: [
      { id: "relation-1", kind: "gear", driver_dof_id: "dof-pivot", driven_dof_id: "dof-pivot", ratio: -2, offset_rad: 0, offset_m: null, reversed: true, suppressed: true },
    ],
    configurations: [{ id: "configuration-default", name: "Default", active: true, suppressed_instance_ids: [], overridden_dof_ids: [] }],
    issues: [
      { id: "issue-unconverged", severity: "warning", code: "solve_unconverged", message: "The mate preview did not converge.", entity_ids: ["mate-pivot"], field_path: null, recoverable: true },
      { id: "issue-source", severity: "error", code: "source_missing", message: "A linked component is missing.", entity_ids: ["instance-base"], field_path: "instances[0].source", recoverable: true },
    ],
  };
}

const solution: AssemblySolutionProjection = {
  status: "unconverged",
  revision: "revision-4",
  instance_world_transforms: [],
  dof_values: [{ dof_id: "dof-pivot", value_rad: 0, value_m: null }],
  remaining_free_dof_count: 1,
  residual: 0.002,
  iterations: 24,
  limit_violations: [],
  diagnostic_ids: ["issue-unconverged"],
};

const bom: BOMProjectionV1 = {
  schema_version: 1,
  assembly_id: "assembly-1",
  revision: "revision-4",
  mode: "hierarchical",
  rows: [
    { row_id: "row-base", parent_row_id: null, part_definition_id: "part-base", quantity: 1, part_number: "BASE-01", name: "Base", description: null, material_name: null, unit_mass_kg: 0.4, extended_mass_kg: 0.4, source_label: "Base.aether", custom_properties: [] },
    { row_id: "row-arm", parent_row_id: null, part_definition_id: "part-arm", quantity: 1, part_number: "ARM-01", name: "Arm", description: null, material_name: null, unit_mass_kg: 0.2, extended_mass_kg: 0.2, source_label: "Arm", custom_properties: [] },
  ],
  total_mass_kg: 0.6,
  diagnostic_ids: [],
};

describe("buildCADAssemblyPresentation", () => {
  it("projects nested stable IDs into shared widget datasets without recomputing Core data", () => {
    const presentation = buildCADAssemblyPresentation(fixture(), solution, bom, "mate-pivot");
    const assemblyRoot = presentation.treeNodes[0];
    const components = assemblyRoot.children?.find((node) => node.id === "presentation/components");
    expect(components?.children?.[0]).toMatchObject({ id: "instance-base", label: "Base:1", badge: "read only" });
    expect(components?.children?.[0].children?.[0]).toMatchObject({ id: "instance-arm", label: "Arm:1" });
    expect(presentation.connectorItems.map((item) => item.id)).toEqual(["connector-base", "connector-arm"]);
    expect(presentation.mateItems[0]).toMatchObject({ id: "mate-pivot", badge: "revolute · warning" });
    expect(presentation.relationItems[0]).toMatchObject({ id: "relation-1", badge: "-2:1", dimmed: true });
    expect(presentation.problemItems.map((item) => item.badge)).toEqual(["Warning", "Error"]);
    expect(presentation.mateEndpointOptions).toEqual([
      {
        id: '["instance-base","connector-base"]',
        label: "Base:1 · Base pivot",
        description: "Pivot face",
        instanceID: "instance-base",
        connectorDefinitionID: "connector-base",
      },
      {
        id: '["instance-arm","connector-arm"]',
        label: "Arm:1 · Arm pivot",
        description: "Pivot face",
        instanceID: "instance-arm",
        connectorDefinitionID: "connector-arm",
      },
    ]);
    expect(presentation.inspectorSections[0]).toMatchObject({ id: "mate", badge: "warning" });
    expect(presentation.selectedMateDOF).toMatchObject({ id: "dof-pivot", kind: "rotation", state: "free" });
    expect(presentation.relationDOFOptions).toEqual([{ id: "dof-pivot", label: "Pivot · Rotation", kind: "rotation" }]);
    expect(presentation.inspectorSections[0].properties).toEqual(expect.arrayContaining([
      { id: "dof-value", label: "Angle", value: "0°" },
      { id: "dof-limits", label: "Limits", value: expect.stringContaining("° to ") },
    ]));
    expect(presentation.bomRows).toBe(bom.rows);
    expect(presentation.summary).toEqual({ instanceCount: 2, connectorCount: 2, mateCount: 1, remainingFreeDOFCount: 1, solveStatus: "unconverged", bomMode: "hierarchical" });

    const relationPresentation = buildCADAssemblyPresentation(fixture(), solution, bom, "relation-1");
    expect(relationPresentation.inspectorSections[0].properties).toEqual(expect.arrayContaining([
      { id: "driver", label: "Driver DOF", value: "Pivot · Rotation" },
      { id: "offset", label: "Offset", value: "0°" },
    ]));
  });

  it("uses Core capability reasons for disabled presentation commands", () => {
    const presentation = buildCADAssemblyPresentation(fixture(), solution, bom);
    expect(presentation.commandAvailability.find((item) => item.id === "add-connector")).toEqual({
      id: "add-connector",
      enabled: false,
      disabledReason: "Workspace is read-only.",
    });
    expect(presentation.commandAvailability.find((item) => item.id === "save-workspace")?.disabledReason).toBe("Workspace is linked read-only.");
    expect(presentation.commandAvailability.find((item) => item.id === "add-mate")?.enabled).toBe(true);
  });

  it("projects an empty assembly without inventing rows or a solve result", () => {
    const empty = fixture();
    const presentation = buildCADAssemblyPresentation({
      ...empty,
      instances: [],
      connector_definitions: [],
      mates: [],
      relations: [],
      issues: [],
      assemblies: [{ ...empty.assemblies[0], root_instance_ids: [] }],
    }, null, null);
    expect(presentation.treeNodes[0].children?.find((node) => node.id === "presentation/components")?.children).toEqual([]);
    expect(presentation.connectorItems).toEqual([]);
    expect(presentation.mateItems).toEqual([]);
    expect(presentation.mateEndpointOptions).toEqual([]);
    expect(presentation.problemItems).toEqual([]);
    expect(presentation.bomRows).toEqual([]);
    expect(presentation.summary.solveStatus).toBe("not_solved");
  });

  it("maps 1,200 instances in deterministic order for shared Tree virtualization", () => {
    const source = fixture();
    const instances = Array.from({ length: 1_200 }, (_, index) => ({
      ...source.instances[1],
      id: `instance-${index}`,
      name: `Component ${index + 1}`,
      parent_instance_id: null,
    }));
    const projection: AssemblyProjectionV1 = {
      ...source,
      instances,
      assemblies: [{ ...source.assemblies[0], root_instance_ids: instances.map((item) => item.id) }],
    };
    const presentation = buildCADAssemblyPresentation(projection, null, null);
    const componentNodes = presentation.treeNodes[0].children?.find((node) => node.id === "presentation/components")?.children ?? [];
    expect(componentNodes).toHaveLength(1_200);
    expect(componentNodes[0].id).toBe("instance-0");
    expect(componentNodes[1_199].id).toBe("instance-1199");
  });
});
