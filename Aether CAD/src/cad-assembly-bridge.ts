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
  type JsonRecord,
} from "./cad-bridge-decode";

export type StableID = string;

export interface TransformProjection {
  readonly position_m: readonly [number, number, number];
  readonly rotation_quaternion_xyzw: readonly [number, number, number, number];
}

export interface SourceProjection {
  readonly kind: "authored" | "packed" | "linked" | "imported";
  readonly label: string;
  readonly asset_ref: string | null;
  readonly status: "resolved" | "missing" | "stale" | "read_only";
}

export interface AssemblyCapabilities {
  readonly can_edit_instances: boolean;
  readonly can_edit_connectors: boolean;
  readonly supported_mate_type_ids: readonly string[];
  readonly can_edit_relations: boolean;
  readonly can_solve_tree: boolean;
  readonly can_solve_loops: boolean;
  readonly can_edit_nested_assemblies: boolean;
  readonly can_project_bom: boolean;
  readonly can_save_workspace: boolean;
  readonly unavailable_reasons: readonly {
    readonly capability_id: string;
    readonly reason: string;
  }[];
}

export interface PartDefinitionProjection {
  readonly feature_document?: unknown;
  readonly id: StableID;
  readonly name: string;
  readonly part_number: string | null;
  readonly description: string | null;
  readonly material_id: StableID | null;
  readonly mass_kg: number | null;
  readonly source: SourceProjection;
  readonly custom_properties: readonly KeyValueProjection[];
}

export interface AssemblyDefinitionProjection {
  readonly id: StableID;
  readonly name: string;
  readonly description: string | null;
  readonly root_instance_ids: readonly StableID[];
}

export interface AssemblyInstanceProjection {
  readonly id: StableID;
  readonly parent_assembly_id: StableID;
  readonly definition_kind: "part" | "assembly";
  readonly definition_id: StableID;
  readonly name: string;
  readonly parent_instance_id: StableID | null;
  readonly rest_transform: TransformProjection;
  readonly solved_world_transform: TransformProjection;
  readonly grounded: boolean;
  readonly suppressed: boolean;
  readonly visible: boolean;
  readonly source_status: "resolved" | "missing" | "stale" | "read_only";
}

export interface ConnectorFrameProjection {
  readonly origin_m: readonly [number, number, number];
  readonly primary_axis_xyz: readonly [number, number, number];
  readonly secondary_axis_xyz: readonly [number, number, number];
}

export interface ConnectorDefinitionProjection {
  readonly id: StableID;
  readonly part_definition_id: StableID;
  readonly name: string;
  readonly frame_part_local: ConnectorFrameProjection;
  readonly provenance: {
    readonly kind: "face" | "edge" | "vertex" | "datum" | "manual";
    readonly stable_feature_id: StableID | null;
    readonly label: string | null;
  };
  readonly suppressed: boolean;
}

export interface DOFProjection {
  readonly id: StableID;
  readonly name: string;
  readonly kind: "rotation" | "translation";
  readonly value_rad: number | null;
  readonly value_m: number | null;
  readonly neutral_rad: number | null;
  readonly neutral_m: number | null;
  readonly limit_min_rad: number | null;
  readonly limit_max_rad: number | null;
  readonly limit_min_m: number | null;
  readonly limit_max_m: number | null;
  readonly state: "driven" | "dependent" | "free" | "suppressed";
}

export interface MateProjection {
  readonly id: StableID;
  readonly name: string;
  readonly type_id: string;
  readonly endpoint_a: MateEndpointProjection;
  readonly endpoint_b: MateEndpointProjection;
  readonly dofs: readonly DOFProjection[];
  readonly controls: readonly {
    readonly key: string;
    readonly value: boolean | number | string;
  }[];
  readonly suppressed: boolean;
  readonly solve_state: "satisfied" | "warning" | "failed" | "suppressed";
  readonly diagnostic_ids: readonly StableID[];
}

export interface MateEndpointProjection {
  readonly instance_id: StableID;
  readonly connector_definition_id: StableID;
}

export interface RelationProjection {
  readonly id: StableID;
  readonly kind: string;
  readonly driver_dof_id: StableID;
  readonly driven_dof_id: StableID;
  readonly ratio: number;
  readonly offset_rad: number | null;
  readonly offset_m: number | null;
  readonly reversed: boolean;
  readonly suppressed: boolean;
}

export interface ConfigurationProjection {
  readonly id: StableID;
  readonly name: string;
  readonly active: boolean;
  readonly suppressed_instance_ids: readonly StableID[];
  readonly overridden_dof_ids: readonly StableID[];
}

export interface DiagnosticProjection {
  readonly id: StableID;
  readonly severity: "info" | "warning" | "error";
  readonly code: string;
  readonly message: string;
  readonly entity_ids: readonly StableID[];
  readonly field_path: string | null;
  readonly recoverable: boolean;
}

export interface AssemblyProjectionV1 {
  readonly schema_version: 1;
  readonly workspace_id: StableID;
  readonly revision: string;
  readonly assembly_id: StableID;
  readonly capabilities: AssemblyCapabilities;
  readonly assemblies: readonly AssemblyDefinitionProjection[];
  readonly part_definitions: readonly PartDefinitionProjection[];
  readonly instances: readonly AssemblyInstanceProjection[];
  readonly connector_definitions: readonly ConnectorDefinitionProjection[];
  readonly mates: readonly MateProjection[];
  readonly relations: readonly RelationProjection[];
  readonly configurations: readonly ConfigurationProjection[];
  readonly issues: readonly DiagnosticProjection[];
}

export interface LimitViolationProjection {
  readonly dof_id: StableID;
  readonly value_rad: number | null;
  readonly value_m: number | null;
  readonly limit_min_rad: number | null;
  readonly limit_max_rad: number | null;
  readonly limit_min_m: number | null;
  readonly limit_max_m: number | null;
}

export interface AssemblySolutionProjection {
  readonly status: "solved" | "unconverged" | "invalid";
  readonly revision: string;
  readonly instance_world_transforms: readonly {
    readonly instance_id: StableID;
    readonly transform: TransformProjection;
  }[];
  readonly dof_values: readonly {
    readonly dof_id: StableID;
    readonly value_rad: number | null;
    readonly value_m: number | null;
  }[];
  readonly remaining_free_dof_count: number;
  readonly residual: number | null;
  readonly iterations: number;
  readonly limit_violations: readonly LimitViolationProjection[];
  readonly diagnostic_ids: readonly StableID[];
}

export interface AssemblyMatePreviewProjection {
  readonly revision: string;
  readonly solution: AssemblySolutionProjection;
  readonly diagnostics: readonly DiagnosticProjection[];
}

export interface KeyValueProjection {
  readonly key: string;
  readonly value: string;
}

export interface BOMRowProjection {
  readonly row_id: string;
  readonly parent_row_id: string | null;
  readonly part_definition_id: StableID;
  readonly quantity: number;
  readonly part_number: string | null;
  readonly name: string;
  readonly description: string | null;
  readonly material_name: string | null;
  readonly unit_mass_kg: number | null;
  readonly extended_mass_kg: number | null;
  readonly source_label: string | null;
  readonly custom_properties: readonly KeyValueProjection[];
}

export interface BOMProjectionV1 {
  readonly schema_version: 1;
  readonly assembly_id: StableID;
  readonly revision: string;
  readonly mode: "hierarchical" | "flattened";
  readonly rows: readonly BOMRowProjection[];
  readonly total_mass_kg: number | null;
  readonly diagnostic_ids: readonly StableID[];
}

export interface AssemblyMutationResult {
  readonly handle: string;
  readonly revision: string;
  readonly assembly: AssemblyProjectionV1;
  readonly solution: AssemblySolutionProjection;
  readonly bom: BOMProjectionV1;
}

export interface AssemblyWorkspaceDescriptor {
  readonly schema_version: 1;
  readonly handle: string;
  readonly workspace_id: StableID;
  readonly name: string;
  readonly revision: string;
  readonly graph_sha256: string;
  readonly root_assembly_id: StableID;
  readonly assembly_ids: readonly StableID[];
}

export interface AssemblyWorkspaceArchive {
  readonly handle: string;
  readonly revision: string;
  readonly graph_sha256: string;
  readonly data_base64: string;
}

export class AssemblyProjectionDecodeError extends ProjectionDecodeError {
  override name = "AssemblyProjectionDecodeError";
}

function validateTransform(value: unknown, path: string): void {
  const item = record(value, path);
  tuple(item.position_m, 3, `${path}.position_m`);
  tuple(item.rotation_quaternion_xyzw, 4, `${path}.rotation_quaternion_xyzw`);
}

function validateKeyValues(value: unknown, path: string): void {
  array(value, path).forEach((entry, index) => {
    const item = record(entry, `${path}[${index}]`);
    string(item.key, `${path}[${index}].key`);
    text(item.value, `${path}[${index}].value`);
  });
}

function validateCapabilities(value: unknown, path: string): void {
  const item = record(value, path);
  [
    "can_edit_instances",
    "can_edit_connectors",
    "can_edit_relations",
    "can_solve_tree",
    "can_solve_loops",
    "can_edit_nested_assemblies",
    "can_project_bom",
    "can_save_workspace",
  ].forEach((key) => boolean(item[key], `${path}.${key}`));
  stringArray(item.supported_mate_type_ids, `${path}.supported_mate_type_ids`);
  array(item.unavailable_reasons, `${path}.unavailable_reasons`).forEach(
    (entry, index) => {
      const reason = record(entry, `${path}.unavailable_reasons[${index}]`);
      string(reason.capability_id, `${path}.unavailable_reasons[${index}].capability_id`);
      string(reason.reason, `${path}.unavailable_reasons[${index}].reason`);
    },
  );
}

function validateDefinitions(root: JsonRecord, path: string): void {
  array(root.assemblies, `${path}.assemblies`).forEach((entry, index) => {
    const item = record(entry, `${path}.assemblies[${index}]`);
    string(item.id, `${path}.assemblies[${index}].id`);
    string(item.name, `${path}.assemblies[${index}].name`);
    nullableString(item.description, `${path}.assemblies[${index}].description`);
    stringArray(item.root_instance_ids, `${path}.assemblies[${index}].root_instance_ids`);
  });
  array(root.part_definitions, `${path}.part_definitions`).forEach((entry, index) => {
    const itemPath = `${path}.part_definitions[${index}]`;
    const item = record(entry, itemPath);
    string(item.id, `${itemPath}.id`);
    string(item.name, `${itemPath}.name`);
    nullableString(item.part_number, `${itemPath}.part_number`);
    nullableString(item.description, `${itemPath}.description`);
    nullableString(item.material_id, `${itemPath}.material_id`);
    nullableNumber(item.mass_kg, `${itemPath}.mass_kg`);
    const source = record(item.source, `${itemPath}.source`);
    oneOf(source.kind, ["authored", "packed", "linked", "imported"], `${itemPath}.source.kind`);
    string(source.label, `${itemPath}.source.label`);
    nullableString(source.asset_ref, `${itemPath}.source.asset_ref`);
    oneOf(source.status, ["resolved", "missing", "stale", "read_only"], `${itemPath}.source.status`);
    validateKeyValues(item.custom_properties, `${itemPath}.custom_properties`);
  });
}

function validateInstances(value: unknown, path: string): void {
  array(value, path).forEach((entry, index) => {
    const itemPath = `${path}[${index}]`;
    const item = record(entry, itemPath);
    string(item.id, `${itemPath}.id`);
    string(item.parent_assembly_id, `${itemPath}.parent_assembly_id`);
    oneOf(item.definition_kind, ["part", "assembly"], `${itemPath}.definition_kind`);
    string(item.definition_id, `${itemPath}.definition_id`);
    string(item.name, `${itemPath}.name`);
    nullableString(item.parent_instance_id, `${itemPath}.parent_instance_id`);
    validateTransform(item.rest_transform, `${itemPath}.rest_transform`);
    validateTransform(item.solved_world_transform, `${itemPath}.solved_world_transform`);
    boolean(item.grounded, `${itemPath}.grounded`);
    boolean(item.suppressed, `${itemPath}.suppressed`);
    boolean(item.visible, `${itemPath}.visible`);
    oneOf(item.source_status, ["resolved", "missing", "stale", "read_only"], `${itemPath}.source_status`);
  });
}

function validateConnectors(value: unknown, path: string): void {
  array(value, path).forEach((entry, index) => {
    const itemPath = `${path}[${index}]`;
    const item = record(entry, itemPath);
    string(item.id, `${itemPath}.id`);
    string(item.part_definition_id, `${itemPath}.part_definition_id`);
    string(item.name, `${itemPath}.name`);
    const frame = record(item.frame_part_local, `${itemPath}.frame_part_local`);
    tuple(frame.origin_m, 3, `${itemPath}.frame_part_local.origin_m`);
    tuple(frame.primary_axis_xyz, 3, `${itemPath}.frame_part_local.primary_axis_xyz`);
    tuple(frame.secondary_axis_xyz, 3, `${itemPath}.frame_part_local.secondary_axis_xyz`);
    const provenance = record(item.provenance, `${itemPath}.provenance`);
    oneOf(provenance.kind, ["face", "edge", "vertex", "datum", "manual"], `${itemPath}.provenance.kind`);
    nullableString(provenance.stable_feature_id, `${itemPath}.provenance.stable_feature_id`);
    nullableString(provenance.label, `${itemPath}.provenance.label`);
    boolean(item.suppressed, `${itemPath}.suppressed`);
  });
}

function validateDOF(value: unknown, path: string): void {
  const item = record(value, path);
  string(item.id, `${path}.id`);
  string(item.name, `${path}.name`);
  oneOf(item.kind, ["rotation", "translation"], `${path}.kind`);
  [
    "value_rad",
    "value_m",
    "neutral_rad",
    "neutral_m",
    "limit_min_rad",
    "limit_max_rad",
    "limit_min_m",
    "limit_max_m",
  ].forEach((key) => nullableNumber(item[key], `${path}.${key}`));
  oneOf(item.state, ["driven", "dependent", "free", "suppressed"], `${path}.state`);
}

function validateMates(value: unknown, path: string): void {
  array(value, path).forEach((entry, index) => {
    const itemPath = `${path}[${index}]`;
    const item = record(entry, itemPath);
    string(item.id, `${itemPath}.id`);
    string(item.name, `${itemPath}.name`);
    string(item.type_id, `${itemPath}.type_id`);
    ["endpoint_a", "endpoint_b"].forEach((key) => {
      const endpoint = record(item[key], `${itemPath}.${key}`);
      string(endpoint.instance_id, `${itemPath}.${key}.instance_id`);
      string(endpoint.connector_definition_id, `${itemPath}.${key}.connector_definition_id`);
    });
    array(item.dofs, `${itemPath}.dofs`).forEach((dof, dofIndex) =>
      validateDOF(dof, `${itemPath}.dofs[${dofIndex}]`),
    );
    array(item.controls, `${itemPath}.controls`).forEach((control, controlIndex) => {
      const controlPath = `${itemPath}.controls[${controlIndex}]`;
      const pair = record(control, controlPath);
      string(pair.key, `${controlPath}.key`);
      if (!["boolean", "number", "string"].includes(typeof pair.value)) {
        throw new AssemblyProjectionDecodeError(`${controlPath}.value`, "expected scalar control value");
      }
      if (typeof pair.value === "number") number(pair.value, `${controlPath}.value`);
    });
    boolean(item.suppressed, `${itemPath}.suppressed`);
    oneOf(item.solve_state, ["satisfied", "warning", "failed", "suppressed"], `${itemPath}.solve_state`);
    stringArray(item.diagnostic_ids, `${itemPath}.diagnostic_ids`);
  });
}

function validateRelations(value: unknown, path: string): void {
  array(value, path).forEach((entry, index) => {
    const itemPath = `${path}[${index}]`;
    const item = record(entry, itemPath);
    ["id", "kind", "driver_dof_id", "driven_dof_id"].forEach((key) =>
      string(item[key], `${itemPath}.${key}`),
    );
    number(item.ratio, `${itemPath}.ratio`);
    nullableNumber(item.offset_rad, `${itemPath}.offset_rad`);
    nullableNumber(item.offset_m, `${itemPath}.offset_m`);
    boolean(item.reversed, `${itemPath}.reversed`);
    boolean(item.suppressed, `${itemPath}.suppressed`);
  });
}

function validateConfigurations(value: unknown, path: string): void {
  array(value, path).forEach((entry, index) => {
    const itemPath = `${path}[${index}]`;
    const item = record(entry, itemPath);
    string(item.id, `${itemPath}.id`);
    string(item.name, `${itemPath}.name`);
    boolean(item.active, `${itemPath}.active`);
    stringArray(item.suppressed_instance_ids, `${itemPath}.suppressed_instance_ids`);
    stringArray(item.overridden_dof_ids, `${itemPath}.overridden_dof_ids`);
  });
}

function validateDiagnostics(value: unknown, path: string): void {
  array(value, path).forEach((entry, index) => {
    const itemPath = `${path}[${index}]`;
    const item = record(entry, itemPath);
    string(item.id, `${itemPath}.id`);
    oneOf(item.severity, ["info", "warning", "error"], `${itemPath}.severity`);
    string(item.code, `${itemPath}.code`);
    string(item.message, `${itemPath}.message`);
    stringArray(item.entity_ids, `${itemPath}.entity_ids`);
    nullableString(item.field_path, `${itemPath}.field_path`);
    boolean(item.recoverable, `${itemPath}.recoverable`);
  });
}

export function decodeAssemblyProjection(value: unknown): AssemblyProjectionV1 {
  const path = "assembly";
  const root = record(value, path);
  if (root.schema_version !== 1) {
    throw new AssemblyProjectionDecodeError(`${path}.schema_version`, "unsupported schema version");
  }
  string(root.workspace_id, `${path}.workspace_id`);
  string(root.revision, `${path}.revision`);
  string(root.assembly_id, `${path}.assembly_id`);
  validateCapabilities(root.capabilities, `${path}.capabilities`);
  validateDefinitions(root, path);
  validateInstances(root.instances, `${path}.instances`);
  validateConnectors(root.connector_definitions, `${path}.connector_definitions`);
  validateMates(root.mates, `${path}.mates`);
  validateRelations(root.relations, `${path}.relations`);
  validateConfigurations(root.configurations, `${path}.configurations`);
  validateDiagnostics(root.issues, `${path}.issues`);
  return root as unknown as AssemblyProjectionV1;
}

function validateBOMRow(value: unknown, path: string): void {
  const item = record(value, path);
  string(item.row_id, `${path}.row_id`);
  nullableString(item.parent_row_id, `${path}.parent_row_id`);
  string(item.part_definition_id, `${path}.part_definition_id`);
  number(item.quantity, `${path}.quantity`);
  nullableString(item.part_number, `${path}.part_number`);
  string(item.name, `${path}.name`);
  nullableString(item.description, `${path}.description`);
  nullableString(item.material_name, `${path}.material_name`);
  nullableNumber(item.unit_mass_kg, `${path}.unit_mass_kg`);
  nullableNumber(item.extended_mass_kg, `${path}.extended_mass_kg`);
  nullableString(item.source_label, `${path}.source_label`);
  validateKeyValues(item.custom_properties, `${path}.custom_properties`);
}

export function decodeBOMProjection(value: unknown): BOMProjectionV1 {
  const path = "bom";
  const root = record(value, path);
  if (root.schema_version !== 1) {
    throw new AssemblyProjectionDecodeError(`${path}.schema_version`, "unsupported schema version");
  }
  string(root.assembly_id, `${path}.assembly_id`);
  string(root.revision, `${path}.revision`);
  oneOf(root.mode, ["hierarchical", "flattened"], `${path}.mode`);
  array(root.rows, `${path}.rows`).forEach((row, index) =>
    validateBOMRow(row, `${path}.rows[${index}]`),
  );
  nullableNumber(root.total_mass_kg, `${path}.total_mass_kg`);
  stringArray(root.diagnostic_ids, `${path}.diagnostic_ids`);
  return root as unknown as BOMProjectionV1;
}

export function decodeAssemblySolution(value: unknown): AssemblySolutionProjection {
  const path = "solution";
  const root = record(value, path);
  oneOf(root.status, ["solved", "unconverged", "invalid"], `${path}.status`);
  string(root.revision, `${path}.revision`);
  array(root.instance_world_transforms, `${path}.instance_world_transforms`).forEach((entry, index) => {
    const itemPath = `${path}.instance_world_transforms[${index}]`;
    const item = record(entry, itemPath);
    string(item.instance_id, `${itemPath}.instance_id`);
    validateTransform(item.transform, `${itemPath}.transform`);
  });
  array(root.dof_values, `${path}.dof_values`).forEach((entry, index) => {
    const itemPath = `${path}.dof_values[${index}]`;
    const item = record(entry, itemPath);
    string(item.dof_id, `${itemPath}.dof_id`);
    nullableNumber(item.value_rad, `${itemPath}.value_rad`);
    nullableNumber(item.value_m, `${itemPath}.value_m`);
  });
  number(root.remaining_free_dof_count, `${path}.remaining_free_dof_count`);
  nullableNumber(root.residual, `${path}.residual`);
  number(root.iterations, `${path}.iterations`);
  array(root.limit_violations, `${path}.limit_violations`).forEach((entry, index) => {
    const itemPath = `${path}.limit_violations[${index}]`;
    const item = record(entry, itemPath);
    string(item.dof_id, `${itemPath}.dof_id`);
    ["value_rad", "value_m", "limit_min_rad", "limit_max_rad", "limit_min_m", "limit_max_m"].forEach(
      (key) => nullableNumber(item[key], `${itemPath}.${key}`),
    );
  });
  stringArray(root.diagnostic_ids, `${path}.diagnostic_ids`);
  return root as unknown as AssemblySolutionProjection;
}

export function decodeAssemblyMatePreview(value: unknown): AssemblyMatePreviewProjection {
  const root = record(value, "preview");
  const revision = string(root.revision, "preview.revision");
  const solution = decodeAssemblySolution(root.solution);
  validateDiagnostics(root.diagnostics, "preview.diagnostics");
  if (solution.revision !== revision) {
    throw new AssemblyProjectionDecodeError("preview.solution.revision", "must match preview.revision");
  }
  return {
    revision,
    solution,
    diagnostics: root.diagnostics as readonly DiagnosticProjection[],
  };
}

export function decodeAssemblyMutationResult(value: unknown): AssemblyMutationResult {
  const root = record(value, "result");
  const handle = string(root.handle, "result.handle");
  const revision = string(root.revision, "result.revision");
  const assembly = decodeAssemblyProjection(root.assembly);
  const solution = decodeAssemblySolution(root.solution);
  const bom = decodeBOMProjection(root.bom);
  [assembly.revision, solution.revision, bom.revision].forEach((candidate, index) => {
    if (candidate !== revision) {
      throw new AssemblyProjectionDecodeError(
        ["result.assembly.revision", "result.solution.revision", "result.bom.revision"][index],
        "must match result.revision",
      );
    }
  });
  return { handle, revision, assembly, solution, bom };
}

export function decodeAssemblyWorkspaceDescriptor(value: unknown): AssemblyWorkspaceDescriptor {
  const root = record(value, "workspace");
  if (root.schema_version !== 1) {
    throw new AssemblyProjectionDecodeError("workspace.schema_version", "unsupported schema version");
  }
  string(root.handle, "workspace.handle");
  string(root.workspace_id, "workspace.workspace_id");
  string(root.name, "workspace.name");
  string(root.revision, "workspace.revision");
  string(root.graph_sha256, "workspace.graph_sha256");
  string(root.root_assembly_id, "workspace.root_assembly_id");
  stringArray(root.assembly_ids, "workspace.assembly_ids");
  return root as unknown as AssemblyWorkspaceDescriptor;
}

function decodeAssemblyWorkspaceArchive(value: unknown): AssemblyWorkspaceArchive {
  const root = record(value, "archive");
  string(root.handle, "archive.handle");
  string(root.revision, "archive.revision");
  string(root.graph_sha256, "archive.graph_sha256");
  string(root.data_base64, "archive.data_base64");
  return root as unknown as AssemblyWorkspaceArchive;
}

interface BridgeEnvelope {
  readonly ok: boolean;
  readonly result?: unknown;
  readonly error?: {
    readonly code: string;
    readonly message: string;
    readonly path: string | null;
  };
}

export class AssemblyBridgeError extends Error {
  constructor(
    readonly code: string,
    message: string,
    readonly path: string | null,
  ) {
    super(message);
    this.name = "AssemblyBridgeError";
  }
}

export type AssemblyMutationMethod =
  | "add_part_definition"
  | "update_part_definition"
  | "remove_part_definition"
  | "add_instance"
  | "update_instance"
  | "remove_instance"
  | "move_instance"
  | "set_instance_grounded"
  | "set_instance_suppressed"
  | "add_connector"
  | "update_connector"
  | "remove_connector"
  | "add_mate"
  | "update_mate"
  | "remove_mate"
  | "add_relation"
  | "update_relation"
  | "remove_relation"
  | "set_dof_value";

export interface AssemblyBridgeClientOptions {
  readonly baseURL: string;
  readonly fetch?: typeof globalThis.fetch;
  readonly nextRequestID?: () => string | number;
}

export class AssemblyBridgeClient {
  private readonly baseURL: string;
  private readonly fetchImplementation: typeof globalThis.fetch;
  private readonly nextRequestID: () => string | number;

  constructor(options: AssemblyBridgeClientOptions) {
    this.baseURL = (options.baseURL || (typeof window !== "undefined" && window.location.pathname.startsWith("/cad/") ? "/cad" : "")).replace(/\/$/, "");
    this.fetchImplementation = options.fetch ?? globalThis.fetch.bind(globalThis);
    let requestID = 0;
    this.nextRequestID = options.nextRequestID ?? (() => ++requestID);
  }

  async newWorkspace(name: string, signal?: AbortSignal): Promise<AssemblyWorkspaceDescriptor> {
    return decodeAssemblyWorkspaceDescriptor(await this.rpc("new_workspace", { name }, signal));
  }

  async openWorkspace(dataBase64: string, signal?: AbortSignal): Promise<AssemblyWorkspaceDescriptor> {
    return decodeAssemblyWorkspaceDescriptor(
      await this.rpc("load_workspace", { data_base64: dataBase64 }, signal),
    );
  }

  async saveWorkspace(
    handle: string,
    expectedRevision: string,
    signal?: AbortSignal,
  ): Promise<AssemblyWorkspaceArchive> {
    return decodeAssemblyWorkspaceArchive(await this.rpc("save_workspace", {
      handle,
      expected_revision: expectedRevision,
      return_data: true,
    }, signal));
  }

  async describeAssembly(
    handle: string,
    assemblyID: StableID,
    signal?: AbortSignal,
  ): Promise<AssemblyProjectionV1> {
    return decodeAssemblyProjection(
      await this.rpc("describe_assembly", { handle, assembly_id: assemblyID }, signal),
    );
  }

  async projectBOM(
    handle: string,
    assemblyID: StableID,
    mode: "hierarchical" | "flattened",
    signal?: AbortSignal,
  ): Promise<BOMProjectionV1> {
    return decodeBOMProjection(
      await this.rpc("project_bom", { handle, assembly_id: assemblyID, mode }, signal),
    );
  }

  async solveAssembly(
    handle: string,
    assemblyID: StableID,
    signal?: AbortSignal,
  ): Promise<AssemblySolutionProjection> {
    return decodeAssemblySolution(
      await this.rpc("solve_assembly", { handle, assembly_id: assemblyID }, signal),
    );
  }

  async previewMate(
    handle: string,
    assemblyID: StableID,
    mate: Readonly<Record<string, unknown>>,
    signal?: AbortSignal,
  ): Promise<AssemblyMatePreviewProjection> {
    return decodeAssemblyMatePreview(
      await this.rpc("preview_mate", { handle, assembly_id: assemblyID, mate }, signal),
    );
  }

  async release(handle: string, signal?: AbortSignal): Promise<void> {
    await this.rpc("release", { handle }, signal);
  }

  async mutate(
    method: AssemblyMutationMethod,
    params: Readonly<Record<string, unknown>> & {
      readonly handle: string;
      readonly expected_revision: string;
    },
    signal?: AbortSignal,
  ): Promise<AssemblyMutationResult> {
    return decodeAssemblyMutationResult(await this.rpc(method, params, signal));
  }

  private async rpc(
    method: string,
    params: Readonly<Record<string, unknown>>,
    signal?: AbortSignal,
  ): Promise<unknown> {
    const response = await this.fetchImplementation(`${this.baseURL}/rpc`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ id: this.nextRequestID(), method, params }),
      signal,
    });
    if (!response.ok) {
      throw new AssemblyBridgeError("transport_error", `Core bridge returned HTTP ${response.status}`, null);
    }
    const envelope = record(await response.json(), "response") as unknown as BridgeEnvelope;
    if (typeof envelope.ok !== "boolean") {
      throw new AssemblyProjectionDecodeError("response.ok", "expected boolean");
    }
    if (!envelope.ok) {
      const error = record(envelope.error, "response.error");
      throw new AssemblyBridgeError(
        string(error.code, "response.error.code"),
        string(error.message, "response.error.message"),
        nullableString(error.path, "response.error.path"),
      );
    }
    if (envelope.result === undefined) {
      throw new AssemblyProjectionDecodeError("response.result", "missing successful result");
    }
    return envelope.result;
  }
}
