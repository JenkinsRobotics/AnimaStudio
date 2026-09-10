import {
  AssemblyBridgeClient,
  AssemblyBridgeError,
  type AssemblyMutationMethod,
  type AssemblyMutationResult,
  type AssemblyMatePreviewProjection,
  type DOFProjection,
  type AssemblyInstanceProjection,
  type MateProjection,
  type AssemblyProjectionV1,
  type AssemblySolutionProjection,
  type AssemblyWorkspaceArchive,
  type AssemblyWorkspaceDescriptor,
  type BOMProjectionV1,
} from "./cad-assembly-bridge";
import { buildCADAssemblyPresentation } from "./cad-assembly-presentation";
import {
  normalizeAssemblyComponentDraft,
  type AssemblyComponentDraft,
} from "./cad-assembly-authoring";
import {
  normalizeAssemblyConnectorDraft,
  type AssemblyConnectorDraft,
} from "./cad-connector-authoring";
import {
  assemblyMatePayload,
  assemblyMateDOFLimitsPayload,
  assemblyMateDOFValuePayload,
  assemblyMateUpdatePayload,
  normalizeAssemblyMateDraft,
  type AssemblyMateDOFEditorDraft,
  type AssemblyMateDraft,
} from "./cad-mate-authoring";
import {
  assemblyRelationPayload,
  type AssemblyRelationDOFOption,
  type AssemblyRelationDraft,
} from "./cad-relation-authoring";
import {
  CADAssemblyWorkspaceStore,
  cadAssemblyWorkspace,
} from "./cad-assembly-workspace-store";

export interface AssemblyControllerClient {
  newWorkspace(name: string, signal?: AbortSignal): Promise<AssemblyWorkspaceDescriptor>;
  openWorkspace(dataBase64: string, signal?: AbortSignal): Promise<AssemblyWorkspaceDescriptor>;
  saveWorkspace(handle: string, revision: string, signal?: AbortSignal): Promise<AssemblyWorkspaceArchive>;
  describeAssembly(handle: string, assemblyID: string, signal?: AbortSignal): Promise<AssemblyProjectionV1>;
  solveAssembly(handle: string, assemblyID: string, signal?: AbortSignal): Promise<AssemblySolutionProjection>;
  projectBOM(handle: string, assemblyID: string, mode: "hierarchical" | "flattened", signal?: AbortSignal): Promise<BOMProjectionV1>;
  previewMate(
    handle: string,
    assemblyID: string,
    mate: Readonly<Record<string, unknown>>,
    signal?: AbortSignal,
  ): Promise<AssemblyMatePreviewProjection>;
  mutate(
    method: AssemblyMutationMethod,
    params: Readonly<Record<string, unknown>> & { readonly handle: string; readonly expected_revision: string },
    signal?: AbortSignal,
  ): Promise<AssemblyMutationResult>;
  release(handle: string, signal?: AbortSignal): Promise<void>;
}

export interface AssemblyDocumentSummary {
  readonly name: string;
  readonly workspaceID: string;
  readonly assemblyID: string;
  readonly revision: string;
}

export interface CADAssemblyControllerOptions {
  readonly client?: AssemblyControllerClient;
  readonly store?: CADAssemblyWorkspaceStore;
  readonly saveFile?: (fileName: string, bytes: Uint8Array) => void | Promise<void>;
  readonly onDocumentChanged?: (document: AssemblyDocumentSummary | null) => void;
  readonly onStatus?: (message: string, tone: "normal" | "error" | "success") => void;
}

interface CanonicalSnapshot {
  readonly assembly: AssemblyProjectionV1;
  readonly solution: AssemblySolutionProjection;
  readonly bom: BOMProjectionV1;
}

function encodeBase64(bytes: Uint8Array): string {
  let binary = "";
  const chunkSize = 0x8000;
  for (let offset = 0; offset < bytes.length; offset += chunkSize) {
    binary += String.fromCharCode(...bytes.subarray(offset, offset + chunkSize));
  }
  return btoa(binary);
}

function decodeBase64(value: string): Uint8Array {
  const binary = atob(value);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

function archiveFileName(name: string): string {
  const stem = name.trim().replace(/[\\/:*?"<>|]+/g, "-") || "Untitled Assembly";
  return /\.(acad|acasm)$/i.test(stem) ? stem : `${stem.replace(/\.aether$/i, "")}.acasm`;
}

function downloadFile(fileName: string, bytes: Uint8Array): void {
  const ownedBytes = new Uint8Array(bytes.byteLength);
  ownedBytes.set(bytes);
  const url = URL.createObjectURL(new Blob([ownedBytes.buffer], { type: "application/vnd.aether.workspace+zip" }));
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = fileName;
  anchor.click();
  URL.revokeObjectURL(url);
}

function messageFor(error: unknown): string {
  if (error instanceof AssemblyBridgeError) return `${error.message}${error.path ? ` (${error.path})` : ""}`;
  if (error instanceof Error) return error.message;
  return String(error);
}

export class CADAssemblyController {
  private readonly client: AssemblyControllerClient;
  private readonly store: CADAssemblyWorkspaceStore;
  private readonly saveFile: (fileName: string, bytes: Uint8Array) => void | Promise<void>;
  private readonly onDocumentChanged: (document: AssemblyDocumentSummary | null) => void;
  private readonly onStatus: (message: string, tone: "normal" | "error" | "success") => void;
  private descriptor: AssemblyWorkspaceDescriptor | null = null;
  private canonical: CanonicalSnapshot | null = null;
  private operation = 0;
  private readonly unsubscribeActions: () => void;

  constructor(options: CADAssemblyControllerOptions = {}) {
    this.client = options.client ?? new AssemblyBridgeClient({ baseURL: "" });
    this.store = options.store ?? cadAssemblyWorkspace;
    this.saveFile = options.saveFile ?? downloadFile;
    this.onDocumentChanged = options.onDocumentChanged ?? (() => undefined);
    this.onStatus = options.onStatus ?? (() => undefined);
    this.unsubscribeActions = this.store.subscribeActions((action) => {
      if (action.type === "select-entities") this.publishCanonical();
      if (action.type === "select-bom-mode") void this.selectBOMMode(action.mode);
    });
  }

  get document(): AssemblyDocumentSummary | null {
    const descriptor = this.descriptor;
    return descriptor ? {
      name: descriptor.name,
      workspaceID: descriptor.workspace_id,
      assemblyID: descriptor.root_assembly_id,
      revision: this.canonical?.assembly.revision ?? descriptor.revision,
    } : null;
  }

  get selectedInstance(): AssemblyInstanceProjection | null {
    const canonical = this.canonical;
    const selectedIDs = [...this.store.snapshot().selectedEntityIDs];
    if (!canonical || selectedIDs.length !== 1) return null;
    return canonical.assembly.instances.find(({ id }) => id === selectedIDs[0]) ?? null;
  }

  get canEditSelectedInstance(): boolean {
    return Boolean(
      this.selectedInstance &&
      this.canonical?.assembly.capabilities.can_edit_instances,
    );
  }

  get canEditInstances(): boolean {
    return Boolean(
      this.descriptor &&
      this.canonical?.assembly.capabilities.can_edit_instances,
    );
  }

  get canAddConnector(): boolean {
    return Boolean(
      this.selectedInstance &&
      this.canonical?.assembly.capabilities.can_edit_connectors,
    );
  }

  get canAddMate(): boolean {
    const assembly = this.canonical?.assembly;
    if (!assembly || assembly.capabilities.supported_mate_type_ids.length === 0) return false;
    const eligibleInstanceIDs = new Set(
      assembly.instances
        .filter((instance) => !instance.suppressed && assembly.connector_definitions.some(
          (connector) => !connector.suppressed && connector.part_definition_id === instance.definition_id,
        ))
        .map(({ id }) => id),
    );
    return eligibleInstanceIDs.size >= 2;
  }

  get selectedMate(): MateProjection | null {
    const canonical = this.canonical;
    const selectedIDs = [...this.store.snapshot().selectedEntityIDs];
    if (!canonical || selectedIDs.length !== 1) return null;
    return canonical.assembly.mates.find(({ id }) => id === selectedIDs[0]) ?? null;
  }

  get canEditSelectedMate(): boolean {
    const mate = this.selectedMate;
    return Boolean(
      mate && this.canonical?.assembly.capabilities.supported_mate_type_ids.includes(mate.type_id),
    );
  }

  get selectedMateDOF(): DOFProjection | null {
    const mate = this.selectedMate;
    return mate?.dofs.length === 1 ? mate.dofs[0] : null;
  }

  get canEditSelectedMateDOF(): boolean {
    return Boolean(
      this.canEditSelectedMate &&
      !this.selectedMate?.suppressed &&
      this.selectedMateDOF?.state === "free",
    );
  }

  get canAddRelation(): boolean {
    if (!this.canonical?.assembly.capabilities.can_edit_relations) return false;
    const options = this.relationDOFOptions();
    const rotations = options.filter(({ kind }) => kind === "rotation").length;
    const translations = options.length - rotations;
    return rotations >= 2 || translations >= 2 || (rotations >= 1 && translations >= 1);
  }

  async newWorkspace(name: string): Promise<void> {
    await this.load("Creating the canonical Assembly workspace…", (signal) =>
      this.client.newWorkspace(name, signal));
  }

  get geometryProjection(): AssemblyProjectionV1 | null { return this.canonical?.assembly ?? null; }

  async selectProjectAssembly(id: string): Promise<void> {
    if (!this.descriptor) throw new Error("Open a project first.");
    this.descriptor = {...this.descriptor, root_assembly_id:id};
    await this.activate(this.descriptor, ++this.operation);
  }

  async openFile(file: Blob & { readonly name?: string }): Promise<void> {
    const bytes = new Uint8Array(await file.arrayBuffer());
    if (bytes.length === 0) throw new Error("The selected .aether workspace is empty.");
    await this.load(`Opening ${file.name ?? "Assembly workspace"}…`, (signal) =>
      this.client.openWorkspace(encodeBase64(bytes), signal));
  }

  async save(): Promise<void> {
    const descriptor = this.descriptor;
    const revision = this.canonical?.assembly.revision;
    if (!descriptor || !revision) throw new Error("No canonical Assembly workspace is open.");
    this.onStatus("Serializing the canonical Assembly workspace…", "normal");
    try {
      const archive = await this.client.saveWorkspace(descriptor.handle, revision);
      if (archive.revision !== revision) throw new Error("Core returned an incoherent workspace revision.");
      const fileName = archiveFileName(descriptor.name);
      await this.saveFile(fileName, decodeBase64(archive.data_base64));
      this.onStatus(`Saved ${fileName} through Aether Core.`, "success");
    } catch (error) {
      this.onStatus(`Assembly save failed: ${messageFor(error)}`, "error");
      throw error;
    }
  }

  async refresh(): Promise<void> {
    if (!this.descriptor) throw new Error("No canonical Assembly workspace is open.");
    await this.activate(this.descriptor, ++this.operation);
  }

  async mutate(method: AssemblyMutationMethod, params: Readonly<Record<string, unknown>>): Promise<void> {
    const descriptor = this.descriptor;
    const revision = this.canonical?.assembly.revision;
    const requestedBOMMode = this.canonical?.bom.mode ?? "hierarchical";
    if (!descriptor || !revision) throw new Error("No canonical Assembly workspace is open.");
    const result = await this.client.mutate(method, {
      ...params,
      handle: descriptor.handle,
      expected_revision: revision,
    });
    let bom = result.bom;
    if (requestedBOMMode !== result.bom.mode) {
      try {
        bom = await this.client.projectBOM(
          descriptor.handle,
          result.assembly.assembly_id,
          requestedBOMMode,
        );
      } catch {
        // The mutation committed in Core; publish its coherent fallback BOM.
      }
    }
    this.assertRevision(result.revision, result.assembly, result.solution, bom);
    this.canonical = { assembly: result.assembly, solution: result.solution, bom };
    this.publishCanonical();
    this.publishDocument();
  }

  async selectBOMMode(mode: "hierarchical" | "flattened"): Promise<void> {
    const descriptor = this.descriptor;
    const canonical = this.canonical;
    if (!descriptor || !canonical || canonical.bom.mode === mode) return;
    this.onStatus(`Loading ${mode} bill of materials…`, "normal");
    try {
      const bom = await this.client.projectBOM(
        descriptor.handle,
        canonical.assembly.assembly_id,
        mode,
      );
      if (this.canonical !== canonical) return;
      this.assertRevision(
        canonical.assembly.revision,
        canonical.assembly,
        canonical.solution,
        bom,
      );
      this.canonical = { ...canonical, bom };
      this.publishCanonical();
      this.onStatus(`BOM view: ${mode}.`, "success");
    } catch (error) {
      this.onStatus(`BOM projection failed: ${messageFor(error)}`, "error");
    }
  }

  async toggleSelectedInstanceGrounded(): Promise<void> {
    const instance = this.requireEditableSelectedInstance();
    await this.mutateSelectedInstance(
      "set_instance_grounded",
      { instance_id: instance.id, grounded: !instance.grounded },
      `${instance.name} is now ${instance.grounded ? "free" : "grounded"}.`,
    );
  }

  async toggleSelectedInstanceSuppressed(): Promise<void> {
    const instance = this.requireEditableSelectedInstance();
    await this.mutateSelectedInstance(
      "set_instance_suppressed",
      { instance_id: instance.id, suppressed: !instance.suppressed },
      `${instance.name} is now ${instance.suppressed ? "restored" : "suppressed"}.`,
    );
  }

  async removeSelectedInstance(): Promise<void> {
    const instance = this.requireEditableSelectedInstance();
    await this.mutateSelectedInstance(
      "remove_instance",
      { instance_id: instance.id },
      `Removed ${instance.name} from the canonical Assembly.`,
    );
  }

  async insertComponent(draft: AssemblyComponentDraft): Promise<void> {
    const normalized = normalizeAssemblyComponentDraft(draft);
    const assemblyID = this.canonical?.assembly.assembly_id;
    if (!assemblyID || !this.canEditInstances) {
      throw new Error("The current Assembly workspace does not permit component insertion.");
    }
    const existingDefinitionIDs = new Set(
      this.canonical?.assembly.part_definitions.map(({ id }) => id) ?? [],
    );

    try {
      await this.mutate("add_part_definition", {
        assembly_id: assemblyID,
        part_definition: {
          name: normalized.partName,
          part_number: normalized.partNumber,
          mass_kg: normalized.massKg,
          source: {
            kind: "authored",
            label: normalized.sourceLabel,
          },
          custom_properties: [],
        },
      });
    } catch (error) {
      this.onStatus(`Component insertion failed: ${messageFor(error)}`, "error");
      throw error;
    }

    const newDefinitionIDs = this.canonical?.assembly.part_definitions
      .map(({ id }) => id)
      .filter((id) => !existingDefinitionIDs.has(id)) ?? [];
    if (newDefinitionIDs.length !== 1) {
      const error = new Error("Core did not return exactly one new Part definition ID.");
      this.onStatus(`Component insertion failed: ${error.message}`, "error");
      throw error;
    }
    const partDefinitionID = newDefinitionIDs[0];

    try {
      await this.mutate("add_instance", {
        assembly_id: assemblyID,
        instance: {
          parent_assembly_id: assemblyID,
          definition_kind: "part",
          definition_id: partDefinitionID,
          name: normalized.instanceName,
          rest_transform: {
            position_m: [...normalized.positionM],
            rotation_quaternion_xyzw: [0, 0, 0, 1],
          },
          grounded: normalized.grounded,
        },
      });
      this.onStatus(`Inserted ${normalized.instanceName} into the canonical Assembly.`, "success");
    } catch (error) {
      try {
        await this.mutate("remove_part_definition", {
          assembly_id: assemblyID,
          part_definition_id: partDefinitionID,
        });
        this.onStatus(
          `Component insertion failed: ${messageFor(error)} The unused Part definition was removed.`,
          "error",
        );
      } catch (rollbackError) {
        this.onStatus(
          `Component insertion failed: ${messageFor(error)} The Part definition remains because cleanup failed: ${messageFor(rollbackError)}`,
          "error",
        );
      }
      throw error;
    }
  }

  async addConnector(draft: AssemblyConnectorDraft): Promise<void> {
    const normalized = normalizeAssemblyConnectorDraft(draft);
    const instance = this.selectedInstance;
    const assemblyID = this.canonical?.assembly.assembly_id;
    if (!instance || !assemblyID || !this.canAddConnector) {
      throw new Error("Select exactly one component in an editable canonical Assembly.");
    }
    const existingConnectorIDs = new Set(
      this.canonical?.assembly.connector_definitions.map(({ id }) => id) ?? [],
    );
    try {
      await this.mutate("add_connector", {
        assembly_id: assemblyID,
        connector: {
          part_definition_id: instance.definition_id,
          name: normalized.name,
          frame_part_local: {
            origin_m: [...normalized.originM],
            primary_axis_xyz: [...normalized.primaryAxisXYZ],
            secondary_axis_xyz: [...normalized.secondaryAxisXYZ],
          },
          provenance: {
            kind: "manual",
            stable_feature_id: null,
            label: normalized.provenanceLabel,
          },
        },
      });
    } catch (error) {
      this.onStatus(`Mate connector creation failed: ${messageFor(error)}`, "error");
      throw error;
    }
    const newConnectorIDs = this.canonical?.assembly.connector_definitions
      .map(({ id }) => id)
      .filter((id) => !existingConnectorIDs.has(id)) ?? [];
    if (newConnectorIDs.length !== 1) {
      const error = new Error("Core committed the connector but did not return exactly one new stable ID.");
      this.onStatus(error.message, "error");
      throw error;
    }
    this.store.dispatch({ type: "select-entities", ids: [newConnectorIDs[0]], mode: "single" });
    this.onStatus(`Added ${normalized.name} to ${instance.name}.`, "success");
  }

  async previewMate(draft: AssemblyMateDraft): Promise<AssemblyMatePreviewProjection> {
    const { descriptor, canonical, payload, normalized } = this.requireMateContext(draft);
    this.onStatus(`Previewing ${normalized.name} through Aether Core…`, "normal");
    try {
      const preview = await this.client.previewMate(
        descriptor.handle,
        canonical.assembly.assembly_id,
        payload,
      );
      if (this.canonical !== canonical || preview.revision !== canonical.assembly.revision) {
        throw new Error("Assembly changed while the mate preview was running.");
      }
      this.onStatus(
        `${normalized.name} preview: ${preview.solution.status}, ${preview.solution.remaining_free_dof_count} free DOF.`,
        preview.solution.status === "solved" ? "success" : "error",
      );
      return preview;
    } catch (error) {
      this.onStatus(`Mate preview failed: ${messageFor(error)}`, "error");
      throw error;
    }
  }

  async addMate(draft: AssemblyMateDraft): Promise<void> {
    const { canonical, payload, normalized } = this.requireMateContext(draft);
    const existingMateIDs = new Set(canonical.assembly.mates.map(({ id }) => id));
    try {
      await this.mutate("add_mate", {
        assembly_id: canonical.assembly.assembly_id,
        mate: payload,
      });
    } catch (error) {
      this.onStatus(`Mate commit failed: ${messageFor(error)}`, "error");
      throw error;
    }
    const newMateIDs = this.canonical?.assembly.mates
      .map(({ id }) => id)
      .filter((id) => !existingMateIDs.has(id)) ?? [];
    if (newMateIDs.length !== 1) {
      const error = new Error("Core committed the mate but did not return exactly one new stable ID.");
      this.onStatus(error.message, "error");
      throw error;
    }
    this.store.dispatch({ type: "select-entities", ids: [newMateIDs[0]], mode: "single" });
    this.onStatus(`Committed ${normalized.name} to the canonical Assembly.`, "success");
  }

  async toggleSelectedMateSuppressed(): Promise<void> {
    const mate = this.requireEditableSelectedMate();
    await this.mutateSelectedMate(
      "update_mate",
      { mate: assemblyMateUpdatePayload(mate, { suppressed: !mate.suppressed }) },
      `${mate.name} is now ${mate.suppressed ? "restored" : "suppressed"}.`,
    );
  }

  async removeSelectedMate(): Promise<void> {
    const mate = this.requireEditableSelectedMate();
    await this.mutateSelectedMate(
      "remove_mate",
      { mate_id: mate.id },
      `Removed ${mate.name} from the canonical Assembly.`,
    );
    this.store.dispatch({ type: "select-entities", ids: [], mode: "single" });
  }

  async setSelectedMateDOFValue(draft: AssemblyMateDOFEditorDraft): Promise<void> {
    const { dof } = this.requireEditableSelectedMateDOF(draft);
    await this.mutateSelectedMate(
      "set_dof_value",
      assemblyMateDOFValuePayload(draft),
      `Set ${dof.name} to ${draft.value}${dof.kind === "rotation" ? "°" : " m"}.`,
    );
  }

  async updateSelectedMateDOFLimits(draft: AssemblyMateDOFEditorDraft): Promise<void> {
    const { mate, dof } = this.requireEditableSelectedMateDOF(draft);
    await this.mutateSelectedMate(
      "update_mate",
      { mate: assemblyMateDOFLimitsPayload(mate, draft) },
      `${dof.name} limits are now ${draft.limitsEnabled ? "enabled" : "unbounded"}.`,
    );
  }

  async addRelation(draft: AssemblyRelationDraft): Promise<void> {
    const canonical = this.canonical;
    if (!canonical || !this.canAddRelation) {
      throw new Error("The current Assembly does not expose compatible free DOFs for a relation.");
    }
    const payload = assemblyRelationPayload(draft, this.relationDOFOptions());
    const existingIDs = new Set(canonical.assembly.relations.map(({ id }) => id));
    try {
      await this.mutate("add_relation", {
        assembly_id: canonical.assembly.assembly_id,
        relation: payload,
      });
    } catch (error) {
      this.onStatus(`Relation creation failed: ${messageFor(error)}`, "error");
      throw error;
    }
    const newIDs = this.canonical?.assembly.relations
      .map(({ id }) => id)
      .filter((id) => !existingIDs.has(id)) ?? [];
    if (newIDs.length !== 1) {
      const error = new Error("Core committed the relation but did not return exactly one new stable ID.");
      this.onStatus(error.message, "error");
      throw error;
    }
    this.store.dispatch({ type: "select-entities", ids: [newIDs[0]], mode: "single" });
    this.onStatus(`Added ${draft.kind.replace("_", " ")} relation to the canonical Assembly.`, "success");
  }

  async close(): Promise<void> {
    const descriptor = this.descriptor;
    this.operation += 1;
    this.descriptor = null;
    this.canonical = null;
    this.store.setUnavailable();
    this.onDocumentChanged(null);
    if (descriptor) await this.client.release(descriptor.handle).catch(() => undefined);
  }

  dispose(): void {
    this.unsubscribeActions();
  }

  private async load(
    message: string,
    create: (signal: AbortSignal) => Promise<AssemblyWorkspaceDescriptor>,
  ): Promise<void> {
    const operation = ++this.operation;
    const previous = this.descriptor;
    const abort = new AbortController();
    this.store.setLoading(message);
    try {
      const descriptor = await create(abort.signal);
      if (operation !== this.operation) {
        await this.client.release(descriptor.handle).catch(() => undefined);
        return;
      }
      await this.activate(descriptor, operation);
      if (previous && previous.handle !== descriptor.handle) {
        await this.client.release(previous.handle).catch(() => undefined);
      }
      this.onStatus(`Opened canonical Assembly ${descriptor.name}.`, "success");
    } catch (error) {
      if (operation !== this.operation) return;
      const message = messageFor(error);
      this.store.setError(message);
      this.onStatus(`Assembly workspace failed: ${message}`, "error");
      throw error;
    }
  }

  private async activate(descriptor: AssemblyWorkspaceDescriptor, operation: number): Promise<void> {
    const [assembly, solution, bom] = await Promise.all([
      this.client.describeAssembly(descriptor.handle, descriptor.root_assembly_id),
      this.client.solveAssembly(descriptor.handle, descriptor.root_assembly_id),
      this.client.projectBOM(descriptor.handle, descriptor.root_assembly_id, "hierarchical"),
    ]);
    if (operation !== this.operation) return;
    this.assertRevision(descriptor.revision, assembly, solution, bom);
    this.descriptor = descriptor;
    this.canonical = { assembly, solution, bom };
    this.publishCanonical();
    this.publishDocument();
  }

  private assertRevision(
    revision: string,
    assembly: AssemblyProjectionV1,
    solution: AssemblySolutionProjection,
    bom: BOMProjectionV1,
  ): void {
    if ([assembly.revision, solution.revision, bom.revision].some((candidate) => candidate !== revision)) {
      throw new Error("Core returned mixed Assembly revisions; presentation was not updated.");
    }
  }

  private requireEditableSelectedInstance(): AssemblyInstanceProjection {
    const instance = this.selectedInstance;
    if (!instance) throw new Error("Select exactly one Assembly component instance.");
    if (!this.canonical?.assembly.capabilities.can_edit_instances) {
      throw new Error("The current Assembly workspace does not permit instance edits.");
    }
    return instance;
  }

  private requireEditableSelectedMate(): MateProjection {
    const mate = this.selectedMate;
    if (!mate) throw new Error("Select exactly one persistent Assembly mate.");
    if (!this.canonical?.assembly.capabilities.supported_mate_type_ids.includes(mate.type_id)) {
      throw new Error("The selected mate type is not editable in this Assembly.");
    }
    return mate;
  }

  private requireEditableSelectedMateDOF(
    draft: AssemblyMateDOFEditorDraft,
  ): { readonly mate: MateProjection; readonly dof: DOFProjection } {
    const mate = this.requireEditableSelectedMate();
    const dof = mate.dofs.length === 1 ? mate.dofs[0] : null;
    if (mate.suppressed || !dof || dof.state !== "free") {
      throw new Error("Select one active revolute or prismatic mate with a free DOF.");
    }
    if (dof.id !== draft.dofID || dof.kind !== draft.kind) {
      throw new Error("The selected mate DOF changed.");
    }
    return { mate, dof };
  }

  private relationDOFOptions(): readonly AssemblyRelationDOFOption[] {
    return this.canonical?.assembly.mates.flatMap((mate) => mate.suppressed ? [] : mate.dofs
      .filter(({ state }) => state === "free")
      .map((dof) => ({ id: dof.id, label: `${mate.name} · ${dof.name}`, kind: dof.kind }))) ?? [];
  }

  private requireMateContext(draft: AssemblyMateDraft): {
    readonly descriptor: AssemblyWorkspaceDescriptor;
    readonly canonical: CanonicalSnapshot;
    readonly normalized: ReturnType<typeof normalizeAssemblyMateDraft>;
    readonly payload: Readonly<Record<string, unknown>>;
  } {
    const descriptor = this.descriptor;
    const canonical = this.canonical;
    const normalized = normalizeAssemblyMateDraft(draft);
    if (!descriptor || !canonical || !this.canAddMate) {
      throw new Error("The current Assembly does not have two editable connector endpoints.");
    }
    if (!canonical.assembly.capabilities.supported_mate_type_ids.includes(normalized.typeID)) {
      throw new Error(`Core does not support the ${normalized.typeID} mate type in this Assembly.`);
    }
    for (const [label, endpoint] of [["Moving", normalized.endpointA], ["Target", normalized.endpointB]] as const) {
      const instance = canonical.assembly.instances.find(({ id }) => id === endpoint.instanceID);
      const connector = canonical.assembly.connector_definitions.find(
        ({ id }) => id === endpoint.connectorDefinitionID,
      );
      if (!instance || instance.suppressed || !connector || connector.suppressed || connector.part_definition_id !== instance.definition_id) {
        throw new Error(`${label} endpoint is no longer available in the canonical Assembly.`);
      }
    }
    return { descriptor, canonical, normalized, payload: assemblyMatePayload(normalized) };
  }

  private async mutateSelectedInstance(
    method: "set_instance_grounded" | "set_instance_suppressed" | "remove_instance",
    params: Readonly<Record<string, unknown>>,
    successMessage: string,
  ): Promise<void> {
    const assemblyID = this.canonical?.assembly.assembly_id;
    if (!assemblyID) throw new Error("No canonical Assembly workspace is open.");
    try {
      await this.mutate(method, { assembly_id: assemblyID, ...params });
      this.onStatus(successMessage, "success");
    } catch (error) {
      this.onStatus(`Assembly component update failed: ${messageFor(error)}`, "error");
      throw error;
    }
  }

  private async mutateSelectedMate(
    method: "update_mate" | "remove_mate" | "set_dof_value",
    params: Readonly<Record<string, unknown>>,
    successMessage: string,
  ): Promise<void> {
    const assemblyID = this.canonical?.assembly.assembly_id;
    if (!assemblyID) throw new Error("No canonical Assembly workspace is open.");
    try {
      await this.mutate(method, { assembly_id: assemblyID, ...params });
      this.onStatus(successMessage, "success");
    } catch (error) {
      this.onStatus(`Assembly mate update failed: ${messageFor(error)}`, "error");
      throw error;
    }
  }

  private publishCanonical(): void {
    if (!this.canonical) return;
    const selectedID = [...this.store.snapshot().selectedEntityIDs][0] ?? null;
    this.store.setReady(buildCADAssemblyPresentation(
      this.canonical.assembly,
      this.canonical.solution,
      this.canonical.bom,
      selectedID,
    ));
  }

  private publishDocument(): void {
    const document = this.document;
    if (document) this.onDocumentChanged(document);
  }
}
