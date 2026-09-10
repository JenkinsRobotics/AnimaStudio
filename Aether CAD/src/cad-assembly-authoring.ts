export interface AssemblyComponentDraft {
  readonly partName: string;
  readonly partNumber: string;
  readonly sourceLabel: string;
  readonly instanceName: string;
  readonly massKg: number | null;
  readonly positionM: readonly [number, number, number];
  readonly grounded: boolean;
}

export interface NormalizedAssemblyComponentDraft {
  readonly partName: string;
  readonly partNumber: string | null;
  readonly sourceLabel: string;
  readonly instanceName: string;
  readonly massKg: number | null;
  readonly positionM: readonly [number, number, number];
  readonly grounded: boolean;
}

export const defaultAssemblyComponentDraft: AssemblyComponentDraft = Object.freeze({
  partName: "Component",
  partNumber: "",
  sourceLabel: "Local authored Part",
  instanceName: "Component:1",
  massKg: 1,
  positionM: Object.freeze([0, 0, 0]) as readonly [number, number, number],
  grounded: false,
});

export function assemblyComponentDraftIssues(
  draft: AssemblyComponentDraft,
): readonly string[] {
  const issues: string[] = [];
  if (!draft.partName.trim()) issues.push("Part name is required.");
  if (!draft.instanceName.trim()) issues.push("Instance name is required.");
  if (!draft.sourceLabel.trim()) issues.push("Source label is required.");
  if (draft.massKg !== null && (!Number.isFinite(draft.massKg) || draft.massKg < 0)) {
    issues.push("Mass must be a non-negative value in kilograms.");
  }
  if (draft.positionM.some((value) => !Number.isFinite(value))) {
    issues.push("Position must contain finite values in meters.");
  }
  return issues;
}

export function normalizeAssemblyComponentDraft(
  draft: AssemblyComponentDraft,
): NormalizedAssemblyComponentDraft {
  const issues = assemblyComponentDraftIssues(draft);
  if (issues.length > 0) throw new Error(issues.join(" "));
  return Object.freeze({
    partName: draft.partName.trim(),
    partNumber: draft.partNumber.trim() || null,
    sourceLabel: draft.sourceLabel.trim(),
    instanceName: draft.instanceName.trim(),
    massKg: draft.massKg,
    positionM: Object.freeze([...draft.positionM]) as readonly [number, number, number],
    grounded: draft.grounded,
  });
}
