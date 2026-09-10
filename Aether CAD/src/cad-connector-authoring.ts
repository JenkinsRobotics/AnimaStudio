export type ConnectorAxisID = "positive-x" | "negative-x" | "positive-y" | "negative-y" | "positive-z" | "negative-z";

export interface AssemblyConnectorDraft {
  readonly name: string;
  readonly provenanceLabel: string;
  readonly originM: readonly [number, number, number];
  readonly primaryAxis: ConnectorAxisID;
  readonly secondaryAxis: ConnectorAxisID;
}

export interface NormalizedAssemblyConnectorDraft {
  readonly name: string;
  readonly provenanceLabel: string | null;
  readonly originM: readonly [number, number, number];
  readonly primaryAxisXYZ: readonly [number, number, number];
  readonly secondaryAxisXYZ: readonly [number, number, number];
}

export const connectorAxisOptions: readonly { readonly value: ConnectorAxisID; readonly label: string }[] = Object.freeze([
  { value: "positive-x", label: "+X" },
  { value: "negative-x", label: "−X" },
  { value: "positive-y", label: "+Y" },
  { value: "negative-y", label: "−Y" },
  { value: "positive-z", label: "+Z" },
  { value: "negative-z", label: "−Z" },
]);

const axisVectors: Readonly<Record<ConnectorAxisID, readonly [number, number, number]>> = Object.freeze({
  "positive-x": [1, 0, 0] as const,
  "negative-x": [-1, 0, 0] as const,
  "positive-y": [0, 1, 0] as const,
  "negative-y": [0, -1, 0] as const,
  "positive-z": [0, 0, 1] as const,
  "negative-z": [0, 0, -1] as const,
});

export const defaultAssemblyConnectorDraft: AssemblyConnectorDraft = Object.freeze({
  name: "Mate Connector 1",
  provenanceLabel: "Manual Part-local frame",
  originM: Object.freeze([0, 0, 0]) as readonly [number, number, number],
  primaryAxis: "positive-z",
  secondaryAxis: "positive-x",
});

function dot(
  left: readonly [number, number, number],
  right: readonly [number, number, number],
): number {
  return left[0] * right[0] + left[1] * right[1] + left[2] * right[2];
}

export function assemblyConnectorDraftIssues(
  draft: AssemblyConnectorDraft,
): readonly string[] {
  const issues: string[] = [];
  if (!draft.name.trim()) issues.push("Connector name is required.");
  if (draft.originM.some((value) => !Number.isFinite(value))) {
    issues.push("Origin must contain finite values in meters.");
  }
  if (Math.abs(dot(axisVectors[draft.primaryAxis], axisVectors[draft.secondaryAxis])) > 0.5) {
    issues.push("Primary and secondary axes must not be parallel.");
  }
  return issues;
}

export function normalizeAssemblyConnectorDraft(
  draft: AssemblyConnectorDraft,
): NormalizedAssemblyConnectorDraft {
  const issues = assemblyConnectorDraftIssues(draft);
  if (issues.length > 0) throw new Error(issues.join(" "));
  return Object.freeze({
    name: draft.name.trim(),
    provenanceLabel: draft.provenanceLabel.trim() || null,
    originM: Object.freeze([...draft.originM]) as readonly [number, number, number],
    primaryAxisXYZ: axisVectors[draft.primaryAxis],
    secondaryAxisXYZ: axisVectors[draft.secondaryAxis],
  });
}
