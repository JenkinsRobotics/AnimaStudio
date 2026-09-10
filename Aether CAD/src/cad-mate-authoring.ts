import type { DOFProjection, MateProjection } from "./cad-assembly-bridge";

export type AssemblyMateTypeID = "fastened" | "revolute" | "prismatic";

export interface AssemblyMateEndpointDraft {
  readonly instanceID: string;
  readonly connectorDefinitionID: string;
}

export interface AssemblyMateDraft {
  readonly name: string;
  readonly typeID: AssemblyMateTypeID;
  readonly endpointA: AssemblyMateEndpointDraft;
  readonly endpointB: AssemblyMateEndpointDraft;
}

export interface NormalizedAssemblyMateDraft {
  readonly name: string;
  readonly typeID: AssemblyMateTypeID;
  readonly endpointA: AssemblyMateEndpointDraft;
  readonly endpointB: AssemblyMateEndpointDraft;
}

export interface AssemblyMatePreviewGate {
  readonly state: string;
  readonly revision?: string;
  readonly solveStatus?: string;
}

export interface AssemblyMateDOFEditorDraft {
  readonly dofID: string;
  readonly name: string;
  readonly kind: "rotation" | "translation";
  readonly value: number | null;
  readonly limitsEnabled: boolean;
  readonly minimum: number | null;
  readonly maximum: number | null;
}

export const assemblyMateTypeOptions: readonly { readonly value: AssemblyMateTypeID; readonly label: string }[] = Object.freeze([
  { value: "fastened", label: "Fastened" },
  { value: "revolute", label: "Revolute" },
  { value: "prismatic", label: "Prismatic" },
]);

const emptyEndpoint: AssemblyMateEndpointDraft = Object.freeze({
  instanceID: "",
  connectorDefinitionID: "",
});

export const defaultAssemblyMateDraft: AssemblyMateDraft = Object.freeze({
  name: "Fastened 1",
  typeID: "fastened",
  endpointA: emptyEndpoint,
  endpointB: emptyEndpoint,
});

export function assemblyMateDraftIssues(draft: AssemblyMateDraft): readonly string[] {
  const issues: string[] = [];
  if (!draft.name.trim()) issues.push("Mate name is required.");
  if (!draft.endpointA.instanceID || !draft.endpointA.connectorDefinitionID) {
    issues.push("Moving endpoint is required.");
  }
  if (!draft.endpointB.instanceID || !draft.endpointB.connectorDefinitionID) {
    issues.push("Target endpoint is required.");
  }
  if (draft.endpointA.instanceID && draft.endpointA.instanceID === draft.endpointB.instanceID) {
    issues.push("Mate endpoints must use different component instances.");
  }
  return issues;
}

export function canApplyAssemblyMate(
  draft: AssemblyMateDraft,
  currentRevision: string | undefined,
  preview: AssemblyMatePreviewGate | null,
): boolean {
  return assemblyMateDraftIssues(draft).length === 0
    && preview?.state === "ready"
    && preview.revision === currentRevision
    && preview.solveStatus === "solved";
}

export function normalizeAssemblyMateDraft(draft: AssemblyMateDraft): NormalizedAssemblyMateDraft {
  const issues = assemblyMateDraftIssues(draft);
  if (issues.length > 0) throw new Error(issues.join(" "));
  return Object.freeze({
    name: draft.name.trim(),
    typeID: draft.typeID,
    endpointA: Object.freeze({ ...draft.endpointA }),
    endpointB: Object.freeze({ ...draft.endpointB }),
  });
}

export function assemblyMatePayload(draft: AssemblyMateDraft): Readonly<Record<string, unknown>> {
  const normalized = normalizeAssemblyMateDraft(draft);
  return Object.freeze({
    name: normalized.name,
    type_id: normalized.typeID,
    endpoint_a: {
      instance_id: normalized.endpointA.instanceID,
      connector_definition_id: normalized.endpointA.connectorDefinitionID,
    },
    endpoint_b: {
      instance_id: normalized.endpointB.instanceID,
      connector_definition_id: normalized.endpointB.connectorDefinitionID,
    },
    dofs: [],
    controls: [],
  });
}

export function assemblyMateUpdatePayload(
  mate: MateProjection,
  changes: { readonly suppressed?: boolean } = {},
): Readonly<Record<string, unknown>> {
  return Object.freeze({
    id: mate.id,
    name: mate.name,
    type_id: mate.type_id,
    endpoint_a: { ...mate.endpoint_a },
    endpoint_b: { ...mate.endpoint_b },
    dofs: mate.dofs.map((dof) => dof.kind === "rotation"
      ? {
          name: dof.name,
          value_rad: dof.value_rad,
          neutral_rad: dof.neutral_rad,
          limit_min_rad: dof.limit_min_rad,
          limit_max_rad: dof.limit_max_rad,
        }
      : {
          name: dof.name,
          value_m: dof.value_m,
          neutral_m: dof.neutral_m,
          limit_min_m: dof.limit_min_m,
          limit_max_m: dof.limit_max_m,
        }),
    controls: mate.controls.map(({ key, value }) => ({ key, value })),
    suppressed: changes.suppressed ?? mate.suppressed,
  });
}

const degreesPerRadian = 180 / Math.PI;

function displayValue(dof: DOFProjection, field: "value" | "minimum" | "maximum"): number | null {
  const native = dof.kind === "rotation"
    ? field === "value" ? dof.value_rad : field === "minimum" ? dof.limit_min_rad : dof.limit_max_rad
    : field === "value" ? dof.value_m : field === "minimum" ? dof.limit_min_m : dof.limit_max_m;
  return native === null || dof.kind === "translation" ? native : native * degreesPerRadian;
}

/** Presentation-only degree/meter draft derived from one canonical Core DOF. */
export function assemblyMateDOFEditorDraft(dof: DOFProjection): AssemblyMateDOFEditorDraft {
  const minimum = displayValue(dof, "minimum");
  const maximum = displayValue(dof, "maximum");
  return Object.freeze({
    dofID: dof.id,
    name: dof.name,
    kind: dof.kind,
    value: displayValue(dof, "value"),
    limitsEnabled: minimum !== null && maximum !== null,
    minimum,
    maximum,
  });
}

export function assemblyMateDOFEditorIssues(
  draft: AssemblyMateDOFEditorDraft,
  mode: "value" | "limits",
): readonly string[] {
  if (!draft.dofID) return ["A persistent mate DOF is required."];
  if (mode === "value") {
    return draft.value === null || !Number.isFinite(draft.value)
      ? ["A finite DOF value is required."]
      : [];
  }
  if (!draft.limitsEnabled) return [];
  if (draft.minimum === null || draft.maximum === null
      || !Number.isFinite(draft.minimum) || !Number.isFinite(draft.maximum)) {
    return ["Both finite limits are required."];
  }
  return draft.minimum < draft.maximum ? [] : ["Minimum must be less than maximum."];
}

function nativeValue(kind: DOFProjection["kind"], value: number): number {
  return kind === "rotation" ? value / degreesPerRadian : value;
}

export function assemblyMateDOFValuePayload(
  draft: AssemblyMateDOFEditorDraft,
): Readonly<Record<string, unknown>> {
  const issues = assemblyMateDOFEditorIssues(draft, "value");
  if (issues.length > 0) throw new Error(issues.join(" "));
  const value = nativeValue(draft.kind, draft.value!);
  return Object.freeze(draft.kind === "rotation"
    ? { dof_id: draft.dofID, value_rad: value }
    : { dof_id: draft.dofID, value_m: value });
}

export function assemblyMateDOFLimitsPayload(
  mate: MateProjection,
  draft: AssemblyMateDOFEditorDraft,
): Readonly<Record<string, unknown>> {
  const issues = assemblyMateDOFEditorIssues(draft, "limits");
  if (issues.length > 0) throw new Error(issues.join(" "));
  const target = mate.dofs.find(({ id }) => id === draft.dofID);
  if (!target || target.kind !== draft.kind) throw new Error("The selected mate DOF changed.");
  const minimum = draft.limitsEnabled ? nativeValue(draft.kind, draft.minimum!) : null;
  const maximum = draft.limitsEnabled ? nativeValue(draft.kind, draft.maximum!) : null;
  const dofs = mate.dofs.map((dof) => dof.id !== target.id ? dof : dof.kind === "rotation"
    ? { ...dof, limit_min_rad: minimum, limit_max_rad: maximum }
    : { ...dof, limit_min_m: minimum, limit_max_m: maximum });
  return assemblyMateUpdatePayload({ ...mate, dofs });
}
