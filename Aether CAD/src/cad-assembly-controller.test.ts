import { describe, expect, it, vi } from "vitest";
import type {
  AssemblyProjectionV1,
  AssemblySolutionProjection,
  AssemblyWorkspaceDescriptor,
  BOMProjectionV1,
  MateProjection,
} from "./cad-assembly-bridge";
import {
  CADAssemblyController,
  type AssemblyControllerClient,
} from "./cad-assembly-controller";
import { CADAssemblyWorkspaceStore } from "./cad-assembly-workspace-store";

const transform = {
  position_m: [0, 0, 0] as const,
  rotation_quaternion_xyzw: [0, 0, 0, 1] as const,
};

const descriptor: AssemblyWorkspaceDescriptor = {
  schema_version: 1,
  handle: "workspace-handle-1",
  workspace_id: "workspace-1",
  name: "Drive Module",
  revision: "1",
  graph_sha256: "abc",
  root_assembly_id: "assembly-1",
  assembly_ids: ["assembly-1"],
};

const assembly: AssemblyProjectionV1 = {
  schema_version: 1,
  workspace_id: "workspace-1",
  revision: "1",
  assembly_id: "assembly-1",
  capabilities: {
    can_edit_instances: true,
    can_edit_connectors: true,
    supported_mate_type_ids: ["fastened", "revolute", "prismatic"],
    can_edit_relations: true,
    can_solve_tree: true,
    can_solve_loops: false,
    can_edit_nested_assemblies: false,
    can_project_bom: true,
    can_save_workspace: true,
    unavailable_reasons: [],
  },
  assemblies: [{ id: "assembly-1", name: "Drive Module", description: null, root_instance_ids: ["instance-1"] }],
  part_definitions: [{
    id: "part-1", name: "Bracket", part_number: "BR-1", description: null,
    material_id: null, mass_kg: 0.2,
    source: { kind: "authored", label: "Bracket", asset_ref: null, status: "resolved" },
    custom_properties: [],
  }],
  instances: [{
    id: "instance-1", parent_assembly_id: "assembly-1", definition_kind: "part",
    definition_id: "part-1", name: "Bracket:1", parent_instance_id: null,
    rest_transform: transform, solved_world_transform: transform,
    grounded: true, suppressed: false, visible: true, source_status: "resolved",
  }],
  connector_definitions: [],
  mates: [],
  relations: [],
  configurations: [{ id: "config-1", name: "Default", active: true, suppressed_instance_ids: [], overridden_dof_ids: [] }],
  issues: [],
};

const solution: AssemblySolutionProjection = {
  status: "solved",
  revision: "1",
  instance_world_transforms: [{ instance_id: "instance-1", transform }],
  dof_values: [],
  remaining_free_dof_count: 0,
  residual: 0,
  iterations: 0,
  limit_violations: [],
  diagnostic_ids: [],
};

const bom: BOMProjectionV1 = {
  schema_version: 1,
  assembly_id: "assembly-1",
  revision: "1",
  mode: "hierarchical",
  rows: [{
    row_id: "row-1", parent_row_id: null, part_definition_id: "part-1",
    quantity: 1, part_number: "BR-1", name: "Bracket", description: null,
    material_name: null, unit_mass_kg: 0.2, extended_mass_kg: 0.2,
    source_label: "Bracket", custom_properties: [],
  }],
  total_mass_kg: 0.2,
  diagnostic_ids: [],
};

const lifecycleMate: MateProjection = {
  id: "mate-1",
  name: "Base fixed to arm",
  type_id: "fastened",
  endpoint_a: { instance_id: "instance-1", connector_definition_id: "connector-1" },
  endpoint_b: { instance_id: "instance-2", connector_definition_id: "connector-1" },
  dofs: [],
  controls: [],
  suppressed: false,
  solve_state: "satisfied",
  diagnostic_ids: [],
};

const assemblyWithLifecycleMate: AssemblyProjectionV1 = {
  ...assembly,
  assemblies: [{ ...assembly.assemblies[0], root_instance_ids: ["instance-1", "instance-2"] }],
  instances: [
    ...assembly.instances,
    { ...assembly.instances[0], id: "instance-2", name: "Arm:1", grounded: false },
  ],
  connector_definitions: [{
    id: "connector-1",
    part_definition_id: "part-1",
    name: "Axis",
    frame_part_local: {
      origin_m: [0, 0, 0],
      primary_axis_xyz: [0, 0, 1],
      secondary_axis_xyz: [1, 0, 0],
    },
    provenance: { kind: "manual", stable_feature_id: null, label: "Axis" },
    suppressed: false,
  }],
  mates: [lifecycleMate],
};

const revoluteMate: MateProjection = {
  ...lifecycleMate,
  id: "mate-pivot",
  name: "Arm pivot",
  type_id: "revolute",
  dofs: [{
    id: "dof-pivot",
    name: "rotation",
    kind: "rotation",
    value_rad: 0,
    value_m: null,
    neutral_rad: 0,
    neutral_m: null,
    limit_min_rad: null,
    limit_max_rad: null,
    limit_min_m: null,
    limit_max_m: null,
    state: "free",
  }],
};

const assemblyWithRevoluteMate: AssemblyProjectionV1 = {
  ...assemblyWithLifecycleMate,
  mates: [revoluteMate],
};

function client(overrides: Partial<AssemblyControllerClient> = {}): AssemblyControllerClient {
  return {
    newWorkspace: vi.fn(async () => descriptor),
    openWorkspace: vi.fn(async () => descriptor),
    saveWorkspace: vi.fn(async () => ({
      handle: descriptor.handle,
      revision: "1",
      graph_sha256: "abc",
      data_base64: btoa("canonical archive"),
    })),
    describeAssembly: vi.fn(async () => assembly),
    solveAssembly: vi.fn(async () => solution),
    projectBOM: vi.fn(async () => bom),
    previewMate: vi.fn(async () => ({ revision: "1", solution, diagnostics: [] })),
    mutate: vi.fn(async () => ({ handle: descriptor.handle, revision: "1", assembly, solution, bom })),
    release: vi.fn(async () => undefined),
    ...overrides,
  };
}

describe("CADAssemblyController", () => {
  it("reports an asynchronous server save failure instead of claiming success", async () => {
    const status = vi.fn();
    const controller = new CADAssemblyController({
      client: client(), store: new CADAssemblyWorkspaceStore(), onStatus: status,
      saveFile: async () => { throw new Error("This file changed on the server."); },
    });
    await controller.newWorkspace("Drive Module");
    status.mockClear();
    await expect(controller.save()).rejects.toThrow("This file changed on the server.");
    expect(status).toHaveBeenLastCalledWith("Assembly save failed: This file changed on the server.", "error");
    expect(status.mock.calls.some(([, tone]) => tone === "success")).toBe(false);
    controller.dispose();
  });
  it("opens one revision-coherent canonical projection and remaps selection", async () => {
    const store = new CADAssemblyWorkspaceStore();
    const bridge = client();
    const changed = vi.fn();
    const controller = new CADAssemblyController({ client: bridge, store, onDocumentChanged: changed });

    await controller.newWorkspace("Drive Module");
    expect(store.snapshot()).toMatchObject({ loadState: "ready", message: "Assembly revision 1" });
    expect(store.snapshot().data?.summary).toMatchObject({ instanceCount: 1, solveStatus: "solved" });
    expect(changed).toHaveBeenLastCalledWith(expect.objectContaining({ name: "Drive Module", revision: "1" }));

    store.dispatch({ type: "select-entities", ids: ["instance-1"], mode: "single" });
    expect(store.snapshot().data?.inspectorSections[0]).toMatchObject({ id: "instance", label: "Assembly instance" });
    controller.dispose();
  });

  it("passes selected file bytes through Core and downloads only Core-produced bytes", async () => {
    const store = new CADAssemblyWorkspaceStore();
    const bridge = client();
    const saveFile = vi.fn();
    const controller = new CADAssemblyController({ client: bridge, store, saveFile });
    const file = Object.assign(new Blob([Uint8Array.from([1, 2, 3])]), { name: "drive.aether" });

    await controller.openFile(file);
    expect(bridge.openWorkspace).toHaveBeenCalledWith("AQID", expect.any(AbortSignal));
    await controller.save();
    expect(saveFile).toHaveBeenCalledWith("Drive Module.acasm", new TextEncoder().encode("canonical archive"));
  });

  it("refuses mixed Core revisions without publishing partial data", async () => {
    const store = new CADAssemblyWorkspaceStore();
    const bridge = client({ solveAssembly: vi.fn(async () => ({ ...solution, revision: "2" })) });
    const controller = new CADAssemblyController({ client: bridge, store });

    await expect(controller.newWorkspace("Drive Module")).rejects.toThrow("mixed Assembly revisions");
    expect(store.snapshot()).toMatchObject({ loadState: "error", data: null });
  });

  it("routes selected-instance ground, suppress, and remove edits through revisioned Core mutations", async () => {
    const store = new CADAssemblyWorkspaceStore();
    let currentAssembly = assembly;
    let currentSolution = solution;
    let currentBOM = bom;
    const mutate = vi.fn(async (method: string, params: Readonly<Record<string, unknown>>) => {
      const revision = String(Number(currentAssembly.revision) + 1);
      const selectedID = params.instance_id as string;
      const instances = method === "remove_instance"
        ? currentAssembly.instances.filter(({ id }) => id !== selectedID)
        : currentAssembly.instances.map((instance) => instance.id === selectedID
          ? {
              ...instance,
              grounded: method === "set_instance_grounded" ? params.grounded as boolean : instance.grounded,
              suppressed: method === "set_instance_suppressed" ? params.suppressed as boolean : instance.suppressed,
            }
          : instance);
      currentAssembly = { ...currentAssembly, revision, instances };
      currentSolution = {
        ...currentSolution,
        revision,
        instance_world_transforms: currentSolution.instance_world_transforms
          .filter(({ instance_id }) => instances.some(({ id }) => id === instance_id)),
      };
      currentBOM = {
        ...currentBOM,
        revision,
        rows: method === "remove_instance" ? [] : currentBOM.rows,
      };
      return {
        handle: descriptor.handle,
        revision,
        assembly: currentAssembly,
        solution: currentSolution,
        bom: currentBOM,
      };
    });
    const statuses = vi.fn();
    const controller = new CADAssemblyController({ client: client({ mutate }), store, onStatus: statuses });
    await controller.newWorkspace("Drive Module");
    store.dispatch({ type: "select-entities", ids: ["instance-1"], mode: "single" });

    expect(controller.canEditSelectedInstance).toBe(true);
    await controller.toggleSelectedInstanceGrounded();
    expect(mutate).toHaveBeenNthCalledWith(1, "set_instance_grounded", expect.objectContaining({
      handle: descriptor.handle,
      expected_revision: "1",
      assembly_id: "assembly-1",
      instance_id: "instance-1",
      grounded: false,
    }));
    expect(controller.selectedInstance?.grounded).toBe(false);

    await controller.toggleSelectedInstanceSuppressed();
    expect(mutate).toHaveBeenNthCalledWith(2, "set_instance_suppressed", expect.objectContaining({
      expected_revision: "2",
      instance_id: "instance-1",
      suppressed: true,
    }));
    expect(controller.selectedInstance?.suppressed).toBe(true);

    await controller.removeSelectedInstance();
    expect(mutate).toHaveBeenNthCalledWith(3, "remove_instance", expect.objectContaining({
      expected_revision: "3",
      instance_id: "instance-1",
    }));
    expect(controller.selectedInstance).toBeNull();
    expect(store.snapshot().selectedEntityIDs.size).toBe(0);
    expect(statuses).toHaveBeenLastCalledWith(
      "Removed Bracket:1 from the canonical Assembly.",
      "success",
    );
  });

  it("publishes Core hierarchical and flattened BOM modes and preserves the mode after mutation", async () => {
    const store = new CADAssemblyWorkspaceStore();
    let revision = "1";
    const projectBOM = vi.fn(async (
      _handle: string,
      _assemblyID: string,
      mode: "hierarchical" | "flattened",
    ) => ({ ...bom, revision, mode }));
    const mutate = vi.fn(async () => {
      revision = "2";
      return {
        handle: descriptor.handle,
        revision,
        assembly: {
          ...assembly,
          revision,
          instances: assembly.instances.map((instance) => ({ ...instance, grounded: false })),
        },
        solution: { ...solution, revision },
        bom: { ...bom, revision, mode: "hierarchical" as const },
      };
    });
    const statuses = vi.fn();
    const controller = new CADAssemblyController({
      client: client({ projectBOM, mutate }),
      store,
      onStatus: statuses,
    });
    await controller.newWorkspace("Drive Module");

    store.dispatch({ type: "select-bom-mode", mode: "flattened" });
    await vi.waitFor(() => expect(store.snapshot().data?.summary.bomMode).toBe("flattened"));
    expect(projectBOM).toHaveBeenLastCalledWith(
      descriptor.handle,
      descriptor.root_assembly_id,
      "flattened",
    );
    store.dispatch({ type: "select-entities", ids: ["instance-1"], mode: "single" });
    await controller.toggleSelectedInstanceGrounded();

    expect(store.snapshot().data?.revision).toBe("2");
    expect(store.snapshot().data?.summary.bomMode).toBe("flattened");
    expect(projectBOM).toHaveBeenLastCalledWith(
      descriptor.handle,
      descriptor.root_assembly_id,
      "flattened",
    );
    expect(statuses).toHaveBeenLastCalledWith("Bracket:1 is now free.", "success");
  });

  it("inserts a component with the stable Part ID assigned by Core", async () => {
    const store = new CADAssemblyWorkspaceStore();
    const addedPart = {
      ...assembly.part_definitions[0],
      id: "part-2",
      name: "Bearing",
      part_number: "BRG-6202",
      mass_kg: 0.08,
      source: { ...assembly.part_definitions[0].source, label: "bearing.cadpart" },
    };
    const addedInstance = {
      ...assembly.instances[0],
      id: "instance-2",
      definition_id: "part-2",
      name: "Bearing:1",
      grounded: false,
      rest_transform: { ...transform, position_m: [0.1, 0.2, 0.3] as const },
      solved_world_transform: { ...transform, position_m: [0.1, 0.2, 0.3] as const },
    };
    const mutate = vi.fn()
      .mockResolvedValueOnce({
        handle: descriptor.handle,
        revision: "2",
        assembly: { ...assembly, revision: "2", part_definitions: [...assembly.part_definitions, addedPart] },
        solution: { ...solution, revision: "2" },
        bom: { ...bom, revision: "2" },
      })
      .mockResolvedValueOnce({
        handle: descriptor.handle,
        revision: "3",
        assembly: {
          ...assembly,
          revision: "3",
          part_definitions: [...assembly.part_definitions, addedPart],
          instances: [...assembly.instances, addedInstance],
        },
        solution: {
          ...solution,
          revision: "3",
          instance_world_transforms: [
            ...solution.instance_world_transforms,
            { instance_id: "instance-2", transform: addedInstance.solved_world_transform },
          ],
        },
        bom: {
          ...bom,
          revision: "3",
          rows: [...bom.rows, {
            ...bom.rows[0],
            row_id: "row-2",
            part_definition_id: "part-2",
            part_number: "BRG-6202",
            name: "Bearing",
            unit_mass_kg: 0.08,
            extended_mass_kg: 0.08,
            source_label: "bearing.cadpart",
          }],
          total_mass_kg: 0.28,
        },
      });
    const statuses = vi.fn();
    const controller = new CADAssemblyController({ client: client({ mutate }), store, onStatus: statuses });
    await controller.newWorkspace("Drive Module");

    expect(controller.canEditInstances).toBe(true);
    await controller.insertComponent({
      partName: " Bearing ",
      partNumber: " BRG-6202 ",
      sourceLabel: " bearing.cadpart ",
      instanceName: " Bearing:1 ",
      massKg: 0.08,
      positionM: [0.1, 0.2, 0.3],
      grounded: false,
    });

    expect(mutate).toHaveBeenNthCalledWith(1, "add_part_definition", expect.objectContaining({
      handle: descriptor.handle,
      expected_revision: "1",
      assembly_id: "assembly-1",
      part_definition: expect.objectContaining({ name: "Bearing", part_number: "BRG-6202", mass_kg: 0.08 }),
    }));
    expect(mutate).toHaveBeenNthCalledWith(2, "add_instance", expect.objectContaining({
      expected_revision: "2",
      instance: expect.objectContaining({
        definition_id: "part-2",
        name: "Bearing:1",
        rest_transform: { position_m: [0.1, 0.2, 0.3], rotation_quaternion_xyzw: [0, 0, 0, 1] },
      }),
    }));
    expect(store.snapshot().data?.summary).toMatchObject({ instanceCount: 2 });
    expect(store.snapshot().data?.bomRows.at(-1)).toMatchObject({ part_number: "BRG-6202", quantity: 1 });
    expect(statuses).toHaveBeenLastCalledWith(
      "Inserted Bearing:1 into the canonical Assembly.",
      "success",
    );
  });

  it("removes the unused definition when instance insertion fails", async () => {
    const store = new CADAssemblyWorkspaceStore();
    const addedPart = { ...assembly.part_definitions[0], id: "part-2", name: "Bearing" };
    const mutate = vi.fn()
      .mockResolvedValueOnce({
        handle: descriptor.handle,
        revision: "2",
        assembly: { ...assembly, revision: "2", part_definitions: [...assembly.part_definitions, addedPart] },
        solution: { ...solution, revision: "2" },
        bom: { ...bom, revision: "2" },
      })
      .mockRejectedValueOnce(new Error("instance name conflicts"))
      .mockResolvedValueOnce({
        handle: descriptor.handle,
        revision: "3",
        assembly: { ...assembly, revision: "3" },
        solution: { ...solution, revision: "3" },
        bom: { ...bom, revision: "3" },
      });
    const statuses = vi.fn();
    const controller = new CADAssemblyController({ client: client({ mutate }), store, onStatus: statuses });
    await controller.newWorkspace("Drive Module");

    await expect(controller.insertComponent({
      partName: "Bearing",
      partNumber: "",
      sourceLabel: "Local Part",
      instanceName: "Bearing:1",
      massKg: null,
      positionM: [0, 0, 0],
      grounded: true,
    })).rejects.toThrow("instance name conflicts");

    expect(mutate).toHaveBeenNthCalledWith(3, "remove_part_definition", expect.objectContaining({
      expected_revision: "2",
      assembly_id: "assembly-1",
      part_definition_id: "part-2",
    }));
    expect(store.snapshot().data?.revision).toBe("3");
    expect(store.snapshot().data?.summary.instanceCount).toBe(1);
    expect(statuses).toHaveBeenLastCalledWith(
      "Component insertion failed: instance name conflicts The unused Part definition was removed.",
      "error",
    );
  });

  it("adds a manual Part-local connector and selects the stable ID returned by Core", async () => {
    const store = new CADAssemblyWorkspaceStore();
    const connector = {
      id: "connector-2",
      part_definition_id: "part-1",
      name: "Shaft axis",
      frame_part_local: {
        origin_m: [0.1, 0.2, 0.3] as const,
        primary_axis_xyz: [0, 0, 1] as const,
        secondary_axis_xyz: [1, 0, 0] as const,
      },
      provenance: {
        kind: "manual" as const,
        stable_feature_id: null,
        label: "Datum A",
      },
      suppressed: false,
    };
    const mutate = vi.fn(async () => ({
      handle: descriptor.handle,
      revision: "2",
      assembly: { ...assembly, revision: "2", connector_definitions: [connector] },
      solution: { ...solution, revision: "2" },
      bom: { ...bom, revision: "2" },
    }));
    const statuses = vi.fn();
    const controller = new CADAssemblyController({ client: client({ mutate }), store, onStatus: statuses });
    await controller.newWorkspace("Drive Module");
    store.dispatch({ type: "select-entities", ids: ["instance-1"], mode: "single" });

    expect(controller.canAddConnector).toBe(true);
    await controller.addConnector({
      name: " Shaft axis ",
      provenanceLabel: " Datum A ",
      originM: [0.1, 0.2, 0.3],
      primaryAxis: "positive-z",
      secondaryAxis: "positive-x",
    });

    expect(mutate).toHaveBeenCalledWith("add_connector", expect.objectContaining({
      expected_revision: "1",
      assembly_id: "assembly-1",
      connector: {
        part_definition_id: "part-1",
        name: "Shaft axis",
        frame_part_local: {
          origin_m: [0.1, 0.2, 0.3],
          primary_axis_xyz: [0, 0, 1],
          secondary_axis_xyz: [1, 0, 0],
        },
        provenance: { kind: "manual", stable_feature_id: null, label: "Datum A" },
      },
    }));
    expect(store.snapshot().selectedEntityIDs).toEqual(new Set(["connector-2"]));
    expect(store.snapshot().data?.inspectorSections[0]).toMatchObject({ id: "connector", label: "Mate connector" });
    expect(statuses).toHaveBeenLastCalledWith("Added Shaft axis to Bracket:1.", "success");
  });

  it("previews without mutation, then commits and selects a Core-owned mate", async () => {
    const store = new CADAssemblyWorkspaceStore();
    const secondPart = { ...assembly.part_definitions[0], id: "part-2", name: "Arm", part_number: "ARM-1" };
    const secondInstance = {
      ...assembly.instances[0],
      id: "instance-2",
      definition_id: "part-2",
      name: "Arm:1",
      grounded: false,
    };
    const baseConnector = {
      id: "connector-1",
      part_definition_id: "part-1",
      name: "Base axis",
      frame_part_local: { origin_m: [0, 0, 0] as const, primary_axis_xyz: [0, 0, 1] as const, secondary_axis_xyz: [1, 0, 0] as const },
      provenance: { kind: "manual" as const, stable_feature_id: null, label: "Base datum" },
      suppressed: false,
    };
    const armConnector = { ...baseConnector, id: "connector-2", part_definition_id: "part-2", name: "Arm axis" };
    const readyAssembly = {
      ...assembly,
      part_definitions: [...assembly.part_definitions, secondPart],
      instances: [...assembly.instances, secondInstance],
      connector_definitions: [baseConnector, armConnector],
      assemblies: [{ ...assembly.assemblies[0], root_instance_ids: ["instance-1", "instance-2"] }],
    };
    const previewMate = vi.fn(async () => ({
      revision: "1",
      solution: { ...solution, remaining_free_dof_count: 0 },
      diagnostics: [],
    }));
    const committedMate = {
      id: "mate-2",
      name: "Base fixed to arm",
      type_id: "fastened",
      endpoint_a: { instance_id: "instance-1", connector_definition_id: "connector-1" },
      endpoint_b: { instance_id: "instance-2", connector_definition_id: "connector-2" },
      dofs: [],
      controls: [],
      suppressed: false,
      solve_state: "satisfied" as const,
      diagnostic_ids: [],
    };
    const mutate = vi.fn(async () => ({
      handle: descriptor.handle,
      revision: "2",
      assembly: { ...readyAssembly, revision: "2", mates: [committedMate] },
      solution: { ...solution, revision: "2", remaining_free_dof_count: 0 },
      bom: { ...bom, revision: "2" },
    }));
    const statuses = vi.fn();
    const controller = new CADAssemblyController({
      client: client({
        describeAssembly: vi.fn(async () => readyAssembly),
        previewMate,
        mutate,
      }),
      store,
      onStatus: statuses,
    });
    await controller.newWorkspace("Drive Module");
    const draft = {
      name: "Base fixed to arm",
      typeID: "fastened" as const,
      endpointA: { instanceID: "instance-1", connectorDefinitionID: "connector-1" },
      endpointB: { instanceID: "instance-2", connectorDefinitionID: "connector-2" },
    };

    expect(controller.canAddMate).toBe(true);
    await expect(controller.previewMate(draft)).resolves.toMatchObject({ revision: "1", solution: { status: "solved" } });
    expect(controller.document?.revision).toBe("1");
    expect(previewMate).toHaveBeenCalledWith(descriptor.handle, "assembly-1", {
      name: "Base fixed to arm",
      type_id: "fastened",
      endpoint_a: { instance_id: "instance-1", connector_definition_id: "connector-1" },
      endpoint_b: { instance_id: "instance-2", connector_definition_id: "connector-2" },
      dofs: [],
      controls: [],
    });

    await controller.addMate(draft);
    expect(mutate).toHaveBeenCalledWith("add_mate", expect.objectContaining({
      expected_revision: "1",
      assembly_id: "assembly-1",
      mate: expect.objectContaining({ name: "Base fixed to arm", type_id: "fastened" }),
    }));
    expect(store.snapshot().selectedEntityIDs).toEqual(new Set(["mate-2"]));
    expect(store.snapshot().data?.inspectorSections[0]).toMatchObject({ id: "mate", badge: "satisfied" });
    expect(statuses).toHaveBeenLastCalledWith(
      "Committed Base fixed to arm to the canonical Assembly.",
      "success",
    );
  });

  it("suppresses, restores, and removes one selected persistent mate", async () => {
    const store = new CADAssemblyWorkspaceStore();
    const statuses = vi.fn();
    const suppressedMate = { ...lifecycleMate, suppressed: true, solve_state: "suppressed" as const };
    const mutate = vi.fn()
      .mockResolvedValueOnce({
        handle: descriptor.handle,
        revision: "2",
        assembly: { ...assemblyWithLifecycleMate, revision: "2", mates: [suppressedMate] },
        solution: { ...solution, revision: "2" },
        bom: { ...bom, revision: "2" },
      })
      .mockResolvedValueOnce({
        handle: descriptor.handle,
        revision: "3",
        assembly: { ...assemblyWithLifecycleMate, revision: "3" },
        solution: { ...solution, revision: "3" },
        bom: { ...bom, revision: "3" },
      })
      .mockResolvedValueOnce({
        handle: descriptor.handle,
        revision: "4",
        assembly: { ...assemblyWithLifecycleMate, revision: "4", mates: [] },
        solution: { ...solution, revision: "4" },
        bom: { ...bom, revision: "4" },
      });
    const controller = new CADAssemblyController({
      client: client({ describeAssembly: vi.fn(async () => assemblyWithLifecycleMate), mutate }),
      store,
      onStatus: statuses,
    });
    await controller.newWorkspace("Drive Module");
    store.dispatch({ type: "select-entities", ids: ["mate-1"], mode: "single" });

    expect(controller.canEditSelectedMate).toBe(true);
    await controller.toggleSelectedMateSuppressed();
    expect(mutate).toHaveBeenNthCalledWith(1, "update_mate", expect.objectContaining({
      expected_revision: "1",
      assembly_id: "assembly-1",
      mate: expect.objectContaining({ id: "mate-1", suppressed: true }),
    }));
    expect(controller.selectedMate?.suppressed).toBe(true);
    expect(store.snapshot().selectedEntityIDs).toEqual(new Set(["mate-1"]));

    await controller.toggleSelectedMateSuppressed();
    expect(mutate).toHaveBeenNthCalledWith(2, "update_mate", expect.objectContaining({
      expected_revision: "2",
      mate: expect.objectContaining({ id: "mate-1", suppressed: false }),
    }));

    await controller.removeSelectedMate();
    expect(mutate).toHaveBeenNthCalledWith(3, "remove_mate", expect.objectContaining({
      expected_revision: "3",
      assembly_id: "assembly-1",
      mate_id: "mate-1",
    }));
    expect(store.snapshot().selectedEntityIDs).toEqual(new Set());
    expect(statuses).toHaveBeenLastCalledWith(
      "Removed Base fixed to arm from the canonical Assembly.",
      "success",
    );

    const failedStore = new CADAssemblyWorkspaceStore();
    const failedStatuses = vi.fn();
    const failedController = new CADAssemblyController({
      client: client({
        describeAssembly: vi.fn(async () => assemblyWithLifecycleMate),
        mutate: vi.fn(async () => { throw new Error("mate DOF is still used by a relation"); }),
      }),
      store: failedStore,
      onStatus: failedStatuses,
    });
    await failedController.newWorkspace("Drive Module");
    failedStore.dispatch({ type: "select-entities", ids: ["mate-1"], mode: "single" });
    await expect(failedController.removeSelectedMate()).rejects.toThrow("still used by a relation");
    expect(failedStore.snapshot().selectedEntityIDs).toEqual(new Set(["mate-1"]));
    expect(failedStatuses).toHaveBeenLastCalledWith(
      "Assembly mate update failed: mate DOF is still used by a relation",
      "error",
    );
  });

  it("sets a selected free mate DOF value and authored limits with explicit units", async () => {
    const store = new CADAssemblyWorkspaceStore();
    const statuses = vi.fn();
    const valueMate = {
      ...revoluteMate,
      dofs: [{ ...revoluteMate.dofs[0], value_rad: Math.PI / 4 }],
    };
    const limitedMate = {
      ...valueMate,
      dofs: [{
        ...valueMate.dofs[0],
        limit_min_rad: -Math.PI / 2,
        limit_max_rad: Math.PI / 2,
      }],
    };
    const mutate = vi.fn()
      .mockResolvedValueOnce({
        handle: descriptor.handle,
        revision: "2",
        assembly: { ...assemblyWithRevoluteMate, revision: "2", mates: [valueMate] },
        solution: {
          ...solution,
          revision: "2",
          dof_values: [{ dof_id: "dof-pivot", value_rad: Math.PI / 4, value_m: null }],
          remaining_free_dof_count: 1,
        },
        bom: { ...bom, revision: "2" },
      })
      .mockResolvedValueOnce({
        handle: descriptor.handle,
        revision: "3",
        assembly: { ...assemblyWithRevoluteMate, revision: "3", mates: [limitedMate] },
        solution: {
          ...solution,
          revision: "3",
          dof_values: [{ dof_id: "dof-pivot", value_rad: Math.PI / 4, value_m: null }],
          remaining_free_dof_count: 1,
        },
        bom: { ...bom, revision: "3" },
      });
    const controller = new CADAssemblyController({
      client: client({ describeAssembly: vi.fn(async () => assemblyWithRevoluteMate), mutate }),
      store,
      onStatus: statuses,
    });
    await controller.newWorkspace("Drive Module");
    store.dispatch({ type: "select-entities", ids: ["mate-pivot"], mode: "single" });

    expect(controller.canEditSelectedMateDOF).toBe(true);
    await controller.setSelectedMateDOFValue({
      dofID: "dof-pivot",
      name: "rotation",
      kind: "rotation",
      value: 45,
      limitsEnabled: false,
      minimum: null,
      maximum: null,
    });
    expect(mutate).toHaveBeenNthCalledWith(1, "set_dof_value", expect.objectContaining({
      expected_revision: "1",
      assembly_id: "assembly-1",
      dof_id: "dof-pivot",
      value_rad: Math.PI / 4,
    }));
    expect(controller.selectedMateDOF?.value_rad).toBe(Math.PI / 4);

    await controller.updateSelectedMateDOFLimits({
      dofID: "dof-pivot",
      name: "rotation",
      kind: "rotation",
      value: 45,
      limitsEnabled: true,
      minimum: -90,
      maximum: 90,
    });
    expect(mutate).toHaveBeenNthCalledWith(2, "update_mate", expect.objectContaining({
      expected_revision: "2",
      assembly_id: "assembly-1",
      mate: expect.objectContaining({
        id: "mate-pivot",
        dofs: [expect.objectContaining({
          value_rad: Math.PI / 4,
          limit_min_rad: -Math.PI / 2,
          limit_max_rad: Math.PI / 2,
        })],
      }),
    }));
    expect(store.snapshot().selectedEntityIDs).toEqual(new Set(["mate-pivot"]));
    expect(statuses).toHaveBeenLastCalledWith("rotation limits are now enabled.", "success");

    const dependentStore = new CADAssemblyWorkspaceStore();
    const dependentController = new CADAssemblyController({
      client: client({
        describeAssembly: vi.fn(async () => ({
          ...assemblyWithRevoluteMate,
          mates: [{
            ...revoluteMate,
            dofs: [{ ...revoluteMate.dofs[0], state: "dependent" as const }],
          }],
        })),
      }),
      store: dependentStore,
    });
    await dependentController.newWorkspace("Drive Module");
    dependentStore.dispatch({ type: "select-entities", ids: ["mate-pivot"], mode: "single" });
    expect(dependentController.canEditSelectedMateDOF).toBe(false);
  });

  it("adds a typed relation and selects only Core's returned stable ID", async () => {
    const store = new CADAssemblyWorkspaceStore();
    const secondMate = {
      ...revoluteMate,
      id: "mate-pivot-2",
      name: "Second pivot",
      dofs: [{ ...revoluteMate.dofs[0], id: "dof-pivot-2" }],
    };
    const readyAssembly = { ...assemblyWithRevoluteMate, mates: [revoluteMate, secondMate] };
    const relation = {
      id: "relation-1",
      kind: "gear",
      driver_dof_id: "dof-pivot",
      driven_dof_id: "dof-pivot-2",
      ratio: -2,
      offset_rad: Math.PI / 12,
      offset_m: null,
      reversed: true,
      suppressed: false,
    };
    const mutate = vi.fn(async () => ({
      handle: descriptor.handle,
      revision: "2",
      assembly: {
        ...readyAssembly,
        revision: "2",
        mates: [revoluteMate, {
          ...secondMate,
          dofs: [{ ...secondMate.dofs[0], state: "dependent" as const }],
        }],
        relations: [relation],
      },
      solution: { ...solution, revision: "2", remaining_free_dof_count: 1 },
      bom: { ...bom, revision: "2" },
    }));
    const statuses = vi.fn();
    const controller = new CADAssemblyController({
      client: client({ describeAssembly: vi.fn(async () => readyAssembly), mutate }),
      store,
      onStatus: statuses,
    });
    await controller.newWorkspace("Drive Module");

    expect(controller.canAddRelation).toBe(true);
    await controller.addRelation({
      kind: "gear",
      driverDOFID: "dof-pivot",
      drivenDOFID: "dof-pivot-2",
      ratio: 2,
      offset: 15,
      reversed: true,
    });
    expect(mutate).toHaveBeenCalledWith("add_relation", expect.objectContaining({
      expected_revision: "1",
      assembly_id: "assembly-1",
      relation: expect.objectContaining({
        kind: "gear",
        driver_dof_id: "dof-pivot",
        driven_dof_id: "dof-pivot-2",
        ratio: -2,
        offset_rad: Math.PI / 12,
      }),
    }));
    expect(store.snapshot().selectedEntityIDs).toEqual(new Set(["relation-1"]));
    expect(store.snapshot().data?.inspectorSections[0]).toMatchObject({ id: "relation", badge: "gear" });
    expect(statuses).toHaveBeenLastCalledWith("Added gear relation to the canonical Assembly.", "success");
  });

  it("keeps the selected instance when Core rejects an edit", async () => {
    const store = new CADAssemblyWorkspaceStore();
    const statuses = vi.fn();
    const controller = new CADAssemblyController({
      client: client({ mutate: vi.fn(async () => { throw new Error("linked workspace is read-only"); }) }),
      store,
      onStatus: statuses,
    });
    await controller.newWorkspace("Drive Module");
    store.dispatch({ type: "select-entities", ids: ["instance-1"], mode: "single" });

    await expect(controller.toggleSelectedInstanceGrounded()).rejects.toThrow("read-only");
    expect(controller.selectedInstance?.id).toBe("instance-1");
    expect(store.snapshot().selectedEntityIDs).toEqual(new Set(["instance-1"]));
    expect(statuses).toHaveBeenLastCalledWith(
      "Assembly component update failed: linked workspace is read-only",
      "error",
    );
  });
});
