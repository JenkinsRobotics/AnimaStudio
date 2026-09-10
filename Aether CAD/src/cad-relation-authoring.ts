import type { DOFProjection } from "./cad-assembly-bridge";

export type AssemblyRelationKind = "gear" | "rack_pinion" | "screw" | "linear";

export interface AssemblyRelationDOFOption {
  readonly id: string;
  readonly label: string;
  readonly kind: DOFProjection["kind"];
}

export interface AssemblyRelationDraft {
  readonly kind: AssemblyRelationKind;
  readonly driverDOFID: string;
  readonly drivenDOFID: string;
  readonly ratio: number | null;
  readonly offset: number | null;
  readonly reversed: boolean;
}

export const assemblyRelationKindOptions = Object.freeze([
  { value: "gear" as const, label: "Gear", driverKind: "rotation" as const, drivenKind: "rotation" as const },
  { value: "rack_pinion" as const, label: "Rack and Pinion", driverKind: "rotation" as const, drivenKind: "translation" as const },
  { value: "screw" as const, label: "Screw", driverKind: "rotation" as const, drivenKind: "translation" as const },
  { value: "linear" as const, label: "Linear", driverKind: "translation" as const, drivenKind: "translation" as const },
]);

export const defaultAssemblyRelationDraft: AssemblyRelationDraft = Object.freeze({
  kind: "gear",
  driverDOFID: "",
  drivenDOFID: "",
  ratio: 1,
  offset: 0,
  reversed: false,
});

export function relationKinds(kind: AssemblyRelationKind): {
  readonly driverKind: DOFProjection["kind"];
  readonly drivenKind: DOFProjection["kind"];
} {
  return assemblyRelationKindOptions.find(({ value }) => value === kind)!;
}

export function assemblyRelationDraftIssues(
  draft: AssemblyRelationDraft,
  options: readonly AssemblyRelationDOFOption[],
): readonly string[] {
  const issues: string[] = [];
  const expected = relationKinds(draft.kind);
  const driver = options.find(({ id }) => id === draft.driverDOFID);
  const driven = options.find(({ id }) => id === draft.drivenDOFID);
  if (!driver) issues.push("A driver DOF is required.");
  else if (driver.kind !== expected.driverKind) issues.push("The driver DOF unit family does not match the relation type.");
  if (!driven) issues.push("A driven DOF is required.");
  else if (driven.kind !== expected.drivenKind) issues.push("The driven DOF unit family does not match the relation type.");
  if (draft.driverDOFID && draft.driverDOFID === draft.drivenDOFID) issues.push("A relation cannot drive the same DOF.");
  if (draft.ratio === null || !Number.isFinite(draft.ratio) || draft.ratio <= 0) {
    issues.push("A positive finite ratio is required.");
  }
  if (draft.offset === null || !Number.isFinite(draft.offset)) issues.push("A finite offset is required.");
  return issues;
}

export function assemblyRelationPayload(
  draft: AssemblyRelationDraft,
  options: readonly AssemblyRelationDOFOption[],
): Readonly<Record<string, unknown>> {
  const issues = assemblyRelationDraftIssues(draft, options);
  if (issues.length > 0) throw new Error(issues.join(" "));
  const driven = options.find(({ id }) => id === draft.drivenDOFID)!;
  const ratio = (draft.reversed ? -1 : 1) * draft.ratio!;
  const offset = driven.kind === "rotation" ? draft.offset! * Math.PI / 180 : draft.offset!;
  return Object.freeze({
    kind: draft.kind,
    driver_dof_id: draft.driverDOFID,
    driven_dof_id: draft.drivenDOFID,
    ratio,
    offset_rad: driven.kind === "rotation" ? offset : null,
    offset_m: driven.kind === "translation" ? offset : null,
    reversed: draft.reversed,
    suppressed: false,
  });
}
