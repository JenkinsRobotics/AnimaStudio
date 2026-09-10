import { describe, expect, it, vi } from "vitest";
import {
  AssemblyBridgeClient,
  AssemblyBridgeError,
  AssemblyProjectionDecodeError,
  decodeAssemblyMutationResult,
  decodeAssemblyMatePreview,
  decodeAssemblyProjection,
  decodeAssemblyWorkspaceDescriptor,
} from "./cad-assembly-bridge";

const transform = {
  position_m: [0, 0, 0],
  rotation_quaternion_xyzw: [0, 0, 0, 1],
};

const assembly = {
  schema_version: 1,
  workspace_id: "workspace-1",
  revision: "revision-7",
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
    unavailable_reasons: [
      { capability_id: "can_solve_loops", reason: "Loop solving is not available." },
    ],
  },
  assemblies: [
    { id: "assembly-1", name: "Drive", description: null, root_instance_ids: ["instance-1"] },
  ],
  part_definitions: [
    {
      id: "part-1",
      name: "Bracket",
      part_number: "BR-100",
      description: null,
      material_id: null,
      mass_kg: 0.12,
      source: { kind: "authored", label: "Bracket", asset_ref: null, status: "resolved" },
      custom_properties: [{ key: "finish", value: "matte" }],
    },
  ],
  instances: [
    {
      id: "instance-1",
      parent_assembly_id: "assembly-1",
      definition_kind: "part",
      definition_id: "part-1",
      name: "Bracket:1",
      parent_instance_id: null,
      rest_transform: transform,
      solved_world_transform: transform,
      grounded: true,
      suppressed: false,
      visible: true,
      source_status: "resolved",
    },
  ],
  connector_definitions: [
    {
      id: "connector-1",
      part_definition_id: "part-1",
      name: "Mount",
      frame_part_local: {
        origin_m: [0, 0, 0],
        primary_axis_xyz: [0, 0, 1],
        secondary_axis_xyz: [1, 0, 0],
      },
      provenance: { kind: "face", stable_feature_id: "face-stable-1", label: "Top face" },
      suppressed: false,
    },
  ],
  mates: [
    {
      id: "mate-1",
      name: "Fastened 1",
      type_id: "fastened",
      endpoint_a: { instance_id: "instance-1", connector_definition_id: "connector-1" },
      endpoint_b: { instance_id: "instance-2", connector_definition_id: "connector-2" },
      dofs: [],
      controls: [{ key: "flip_primary_axis", value: false }],
      suppressed: false,
      solve_state: "satisfied",
      diagnostic_ids: [],
    },
  ],
  relations: [],
  configurations: [
    { id: "configuration-1", name: "Default", active: true, suppressed_instance_ids: [], overridden_dof_ids: [] },
  ],
  issues: [],
};

const solution = {
  status: "solved",
  revision: "revision-7",
  instance_world_transforms: [{ instance_id: "instance-1", transform }],
  dof_values: [],
  remaining_free_dof_count: 0,
  residual: 0,
  iterations: 0,
  limit_violations: [],
  diagnostic_ids: [],
};

const bom = {
  schema_version: 1,
  assembly_id: "assembly-1",
  revision: "revision-7",
  mode: "hierarchical",
  rows: [
    {
      row_id: "row-1",
      parent_row_id: null,
      part_definition_id: "part-1",
      quantity: 1,
      part_number: "BR-100",
      name: "Bracket",
      description: null,
      material_name: null,
      unit_mass_kg: 0.12,
      extended_mass_kg: 0.12,
      source_label: "Bracket",
      custom_properties: [],
    },
  ],
  total_mass_kg: 0.12,
  diagnostic_ids: [],
};

describe("assembly projection decoder", () => {
  it("decodes the canonical workspace handle and root Assembly", () => {
    expect(decodeAssemblyWorkspaceDescriptor({
      schema_version: 1,
      handle: "handle-1",
      workspace_id: "workspace-1",
      name: "Drive",
      revision: "7",
      graph_sha256: "abc",
      root_assembly_id: "assembly-1",
      assembly_ids: ["assembly-1"],
    })).toMatchObject({ handle: "handle-1", root_assembly_id: "assembly-1" });
  });

  it("accepts the frozen explicit-unit projection", () => {
    const decoded = decodeAssemblyProjection(assembly);
    expect(decoded.workspace_id).toBe("workspace-1");
    expect(decoded.instances[0].solved_world_transform.rotation_quaternion_xyzw).toEqual([0, 0, 0, 1]);
    expect(decoded.connector_definitions[0].frame_part_local.primary_axis_xyz).toEqual([0, 0, 1]);
  });

  it("rejects unknown required schema versions before publishing state", () => {
    expect(() => decodeAssemblyProjection({ ...assembly, schema_version: 2 })).toThrowError(
      new AssemblyProjectionDecodeError("assembly.schema_version", "unsupported schema version"),
    );
  });

  it("reports the exact path of a malformed transform", () => {
    const malformed = structuredClone(assembly);
    malformed.instances[0].solved_world_transform = {
      ...malformed.instances[0].solved_world_transform,
      rotation_quaternion_xyzw: [0, 1, 0],
    };
    expect(() => decodeAssemblyProjection(malformed)).toThrow(
      "assembly.instances[0].solved_world_transform.rotation_quaternion_xyzw: expected 4 numbers",
    );
  });

  it("rejects a mutation refresh whose revisions disagree", () => {
    expect(() => decodeAssemblyMutationResult({
      handle: "workspace-1",
      revision: "revision-8",
      assembly,
      solution,
      bom,
    })).toThrow("result.assembly.revision: must match result.revision");
  });

  it("decodes a revision-coherent non-mutating mate preview", () => {
    expect(decodeAssemblyMatePreview({
      revision: "revision-7",
      solution,
      diagnostics: [],
    })).toMatchObject({
      revision: "revision-7",
      solution: { status: "solved", remaining_free_dof_count: 0 },
      diagnostics: [],
    });
    expect(() => decodeAssemblyMatePreview({
      revision: "revision-8",
      solution,
      diagnostics: [],
    })).toThrow("preview.solution.revision: must match preview.revision");
  });
});

describe("AssemblyBridgeClient", () => {
  it("requests browser-safe Core workspace open and save without interpreting the archive", async () => {
    const results = [
      {
        schema_version: 1, handle: "handle-1", workspace_id: "workspace-1",
        name: "Drive", revision: "7", graph_sha256: "abc",
        root_assembly_id: "assembly-1", assembly_ids: ["assembly-1"],
      },
      { handle: "handle-1", revision: "7", graph_sha256: "abc", data_base64: "UEs=" },
    ];
    const fetch = vi.fn<typeof globalThis.fetch>(async () => new Response(JSON.stringify({
      ok: true,
      result: results.shift(),
    }), { status: 200 }));
    const client = new AssemblyBridgeClient({ baseURL: "", fetch });

    await client.openWorkspace("UEsDBA==");
    await client.saveWorkspace("handle-1", "7");
    expect(fetch.mock.calls.map(([, init]) => JSON.parse(String(init?.body)))).toEqual([
      { id: 1, method: "load_workspace", params: { data_base64: "UEsDBA==" } },
      { id: 2, method: "save_workspace", params: { handle: "handle-1", expected_revision: "7", return_data: true } },
    ]);
  });

  it("uses the existing rpc envelope and forwards abort signals", async () => {
    const signal = new AbortController().signal;
    const fetch = vi.fn<typeof globalThis.fetch>(async () => new Response(JSON.stringify({ ok: true, result: assembly }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    }));
    const client = new AssemblyBridgeClient({
      baseURL: "http://127.0.0.1:8787/",
      fetch,
      nextRequestID: () => "request-1",
    });

    const result = await client.describeAssembly("handle-1", "assembly-1", signal);
    expect(result.revision).toBe("revision-7");
    expect(fetch).toHaveBeenCalledOnce();
    const [url, init] = fetch.mock.calls[0];
    expect(url).toBe("http://127.0.0.1:8787/rpc");
    expect(init?.signal).toBe(signal);
    expect(JSON.parse(String(init?.body))).toEqual({
      id: "request-1",
      method: "describe_assembly",
      params: { handle: "handle-1", assembly_id: "assembly-1" },
    });
  });

  it("routes mate preview without an expected revision or mutation envelope", async () => {
    const fetch = vi.fn<typeof globalThis.fetch>(async () => new Response(JSON.stringify({
      ok: true,
      result: { revision: "revision-7", solution, diagnostics: [] },
    }), { status: 200 }));
    const client = new AssemblyBridgeClient({ baseURL: "", fetch });
    const mate = { name: "Fixed", type_id: "fastened" };

    await client.previewMate("handle-1", "assembly-1", mate);
    expect(JSON.parse(String(fetch.mock.calls[0][1]?.body))).toEqual({
      id: 1,
      method: "preview_mate",
      params: { handle: "handle-1", assembly_id: "assembly-1", mate },
    });
  });

  it("preserves typed Core error codes and paths", async () => {
    const fetch = vi.fn<typeof globalThis.fetch>(async () => new Response(JSON.stringify({
      ok: false,
      error: { code: "revision_conflict", message: "Workspace changed", path: "expected_revision" },
    }), { status: 200 }));
    const client = new AssemblyBridgeClient({ baseURL: "http://core", fetch });

    const error: unknown = await client.mutate("add_mate", {
      handle: "handle-1",
      expected_revision: "revision-6",
      mate: {},
    }).catch((reason: unknown) => reason);
    expect(error).toBeInstanceOf(AssemblyBridgeError);
    expect(error).toMatchObject({
      code: "revision_conflict",
      path: "expected_revision",
      message: "Workspace changed",
    });
  });
});
