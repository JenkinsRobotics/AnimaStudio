import type { ListBoxItem, TreeNode } from "@aether/ui";
import type {
  AssemblyProjectionV1,
  AssemblySolutionProjection,
  BOMProjectionV1,
  BOMRowProjection,
  DiagnosticProjection,
  DOFProjection,
  StableID,
} from "./cad-assembly-bridge";
import type { CADInspectorSection } from "./cad-workspace-store";
import type { AssemblyRelationDOFOption } from "./cad-relation-authoring";

export type AssemblyPresentationCommandID =
  | "insert-instance"
  | "add-connector"
  | "add-mate"
  | "add-relation"
  | "solve-assembly"
  | "project-bom"
  | "save-workspace";

export interface AssemblyCommandAvailability {
  readonly id: AssemblyPresentationCommandID;
  readonly enabled: boolean;
  readonly disabledReason?: string;
}

export interface AssemblyMateEndpointOption {
  readonly id: string;
  readonly label: string;
  readonly description: string;
  readonly instanceID: StableID;
  readonly connectorDefinitionID: StableID;
}

export interface CADAssemblyPresentationProjection {
  readonly revision: string;
  readonly treeNodes: readonly TreeNode[];
  readonly connectorItems: readonly ListBoxItem[];
  readonly mateItems: readonly ListBoxItem[];
  readonly relationItems: readonly ListBoxItem[];
  readonly problemItems: readonly ListBoxItem[];
  readonly mateEndpointOptions: readonly AssemblyMateEndpointOption[];
  readonly selectedMateDOF: DOFProjection | null;
  readonly relationDOFOptions: readonly AssemblyRelationDOFOption[];
  readonly inspectorSections: readonly CADInspectorSection[];
  readonly bomRows: readonly BOMRowProjection[];
  readonly commandAvailability: readonly AssemblyCommandAvailability[];
  readonly summary: {
    readonly instanceCount: number;
    readonly connectorCount: number;
    readonly mateCount: number;
    readonly remainingFreeDOFCount: number | null;
    readonly solveStatus: AssemblySolutionProjection["status"] | "not_solved";
    readonly bomMode: BOMProjectionV1["mode"] | null;
  };
}

function diagnosticItem(issue: DiagnosticProjection): ListBoxItem {
  return {
    id: issue.id,
    label: issue.message,
    description: [issue.code, issue.field_path].filter(Boolean).join(" · "),
    icon: issue.severity === "error" ? "!" : issue.severity === "warning" ? "△" : "i",
    badge: issue.severity === "error" ? "Error" : issue.severity === "warning" ? "Warning" : "Info",
    group: issue.recoverable ? "Recoverable" : "Assembly",
  };
}

function mateEndpointOptions(projection: AssemblyProjectionV1): readonly AssemblyMateEndpointOption[] {
  return projection.instances
    .filter((instance) => !instance.suppressed && instance.definition_kind === "part")
    .flatMap((instance) => projection.connector_definitions
      .filter((connector) => !connector.suppressed && connector.part_definition_id === instance.definition_id)
      .map((connector) => ({
        id: JSON.stringify([instance.id, connector.id]),
        label: `${instance.name} · ${connector.name}`,
        description: connector.provenance.label ?? "Manual Part-local frame",
        instanceID: instance.id,
        connectorDefinitionID: connector.id,
      })));
}

function reasonFor(projection: AssemblyProjectionV1, capabilityID: string, fallback: string): string {
  return projection.capabilities.unavailable_reasons.find(
    (item) => item.capability_id === capabilityID,
  )?.reason ?? fallback;
}

function availability(
  projection: AssemblyProjectionV1,
  id: AssemblyPresentationCommandID,
  enabled: boolean,
  capabilityID: string,
  fallback: string,
): AssemblyCommandAvailability {
  return enabled
    ? { id, enabled: true }
    : { id, enabled: false, disabledReason: reasonFor(projection, capabilityID, fallback) };
}

function instanceBadge(
  instance: AssemblyProjectionV1["instances"][number],
): string | undefined {
  if (instance.source_status !== "resolved") {
    return instance.source_status.replace("_", " ");
  }
  if (instance.suppressed) return "Suppressed";
  if (instance.grounded) return "Grounded";
  return instance.definition_kind === "assembly" ? "Assembly" : undefined;
}

function buildInstanceNodes(projection: AssemblyProjectionV1): {
  roots: readonly TreeNode[];
  orphans: readonly TreeNode[];
} {
  const instances = new Map(projection.instances.map((item) => [item.id, item]));
  const children = new Map<StableID, StableID[]>();
  projection.instances.forEach((item) => {
    if (item.parent_instance_id === null) return;
    const siblings = children.get(item.parent_instance_id) ?? [];
    siblings.push(item.id);
    children.set(item.parent_instance_id, siblings);
  });

  const emitted = new Set<StableID>();
  const build = (id: StableID, ancestors: ReadonlySet<StableID>): TreeNode | null => {
    const instance = instances.get(id);
    if (!instance) return null;
    if (ancestors.has(id)) {
      return { id, label: instance.name, badge: "Invalid cycle", disabled: true };
    }
    emitted.add(id);
    const nextAncestors = new Set(ancestors).add(id);
    const childNodes = (children.get(id) ?? [])
      .map((childID) => build(childID, nextAncestors))
      .filter((node): node is TreeNode => node !== null);
    return {
      id,
      label: instance.name,
      icon: instance.definition_kind === "assembly" ? "▱" : "◇",
      badge: instanceBadge(instance),
      dimmed: instance.suppressed || !instance.visible || instance.source_status !== "resolved",
      children: childNodes.length > 0 ? childNodes : undefined,
    };
  };

  const assembly = projection.assemblies.find((item) => item.id === projection.assembly_id);
  const roots = (assembly?.root_instance_ids ?? projection.instances
    .filter((item) => item.parent_instance_id === null)
    .map((item) => item.id))
    .map((id) => build(id, new Set()))
    .filter((node): node is TreeNode => node !== null);
  const orphans = projection.instances
    .filter((item) => !emitted.has(item.id))
    .map((item) => build(item.id, new Set()))
    .filter((node): node is TreeNode => node !== null);
  return { roots, orphans };
}

function buildTree(projection: AssemblyProjectionV1): readonly TreeNode[] {
  const assembly = projection.assemblies.find((item) => item.id === projection.assembly_id);
  const { roots, orphans } = buildInstanceNodes(projection);
  const connectorNodes: TreeNode[] = projection.connector_definitions.map((item) => ({
    id: item.id,
    label: item.name,
    icon: "⌖",
    badge: item.suppressed ? "Suppressed" : undefined,
    dimmed: item.suppressed,
  }));
  const mateNodes: TreeNode[] = projection.mates.map((item) => ({
    id: item.id,
    label: item.name,
    icon: "⛓",
    badge: item.solve_state,
    dimmed: item.suppressed,
  }));
  const relationNodes: TreeNode[] = projection.relations.map((item) => ({
    id: item.id,
    label: item.kind,
    icon: "↔",
    badge: item.suppressed ? "Suppressed" : undefined,
    dimmed: item.suppressed,
  }));
  const configurationNodes: TreeNode[] = projection.configurations.map((item) => ({
    id: item.id,
    label: item.name,
    icon: "◫",
    badge: item.active ? "Active" : undefined,
  }));
  const children: TreeNode[] = [
    { id: "presentation/components", label: "Components", icon: "▱", badge: String(projection.instances.length), children: roots },
    { id: "presentation/connectors", label: "Connectors", icon: "⌖", badge: String(connectorNodes.length), children: connectorNodes },
    { id: "presentation/mates", label: "Mates", icon: "⛓", badge: String(mateNodes.length), children: mateNodes },
    { id: "presentation/relations", label: "Relations", icon: "↔", badge: String(relationNodes.length), children: relationNodes },
    { id: "presentation/configurations", label: "Configurations", icon: "◫", badge: String(configurationNodes.length), children: configurationNodes },
  ];
  if (orphans.length > 0) {
    children.push({ id: "presentation/unplaced", label: "Unplaced", icon: "!", badge: String(orphans.length), children: orphans });
  }
  return [{
    id: projection.assembly_id,
    label: assembly?.name ?? "Assembly",
    icon: "▱",
    badge: projection.revision,
    children,
  }];
}

function connectorItems(projection: AssemblyProjectionV1): readonly ListBoxItem[] {
  const parts = new Map(projection.part_definitions.map((item) => [item.id, item]));
  return projection.connector_definitions.map((item) => ({
    id: item.id,
    label: item.name,
    description: `${parts.get(item.part_definition_id)?.name ?? "Part"} · ${item.provenance.label ?? item.provenance.kind}`,
    icon: "⌖",
    badge: item.suppressed ? "Suppressed" : undefined,
    dimmed: item.suppressed,
  }));
}

function mateItems(projection: AssemblyProjectionV1): readonly ListBoxItem[] {
  const instances = new Map(projection.instances.map((item) => [item.id, item]));
  return projection.mates.map((item) => ({
    id: item.id,
    label: item.name,
    description: `${instances.get(item.endpoint_a.instance_id)?.name ?? "Component"} ↔ ${instances.get(item.endpoint_b.instance_id)?.name ?? "Component"}`,
    icon: "⛓",
    badge: `${item.type_id} · ${item.solve_state}`,
    dimmed: item.suppressed,
  }));
}

function relationItems(projection: AssemblyProjectionV1): readonly ListBoxItem[] {
  const dofs = new Map(
    projection.mates.flatMap((mate) => mate.dofs.map((dof) => [dof.id, dof] as const)),
  );
  return projection.relations.map((item) => ({
    id: item.id,
    label: item.kind,
    description: `${dofs.get(item.driver_dof_id)?.name ?? item.driver_dof_id} → ${dofs.get(item.driven_dof_id)?.name ?? item.driven_dof_id}`,
    icon: "↔",
    badge: `${item.ratio}:1`,
    dimmed: item.suppressed,
  }));
}

function vector(values: readonly number[]): string {
  return values.map((value) => value.toLocaleString(undefined, { maximumFractionDigits: 6 })).join(", ");
}

function displayNumber(value: number): string {
  return value.toLocaleString(undefined, { maximumFractionDigits: 6 });
}

function dofDisplayValue(
  dof: DOFProjection,
  solved?: AssemblySolutionProjection["dof_values"][number],
): string {
  return dof.kind === "rotation"
    ? `${displayNumber((solved?.value_rad ?? dof.value_rad ?? 0) * 180 / Math.PI)}°`
    : `${displayNumber(solved?.value_m ?? dof.value_m ?? 0)} m`;
}

function dofDisplayLimits(dof: DOFProjection): string {
  if (dof.kind === "rotation") {
    if (dof.limit_min_rad === null || dof.limit_max_rad === null) return "Unbounded";
    return `${displayNumber(dof.limit_min_rad * 180 / Math.PI)}° to ${displayNumber(dof.limit_max_rad * 180 / Math.PI)}°`;
  }
  if (dof.limit_min_m === null || dof.limit_max_m === null) return "Unbounded";
  return `${displayNumber(dof.limit_min_m)} m to ${displayNumber(dof.limit_max_m)} m`;
}

function inspector(
  projection: AssemblyProjectionV1,
  solution: AssemblySolutionProjection | null,
  selectedID: StableID | null,
): readonly CADInspectorSection[] {
  const instance = projection.instances.find((item) => item.id === selectedID);
  if (instance) {
    return [{
      id: "instance",
      label: "Assembly instance",
      badge: instance.definition_kind,
      properties: [
        { id: "name", label: "Name", value: instance.name },
        { id: "definition", label: "Definition ID", value: instance.definition_id },
        { id: "position", label: "Rest position", value: `${vector(instance.rest_transform.position_m)} m` },
        { id: "rotation", label: "Rest quaternion", value: vector(instance.rest_transform.rotation_quaternion_xyzw) },
        { id: "grounded", label: "Grounded", value: instance.grounded ? "Yes" : "No" },
        { id: "suppressed", label: "Suppressed", value: instance.suppressed ? "Yes" : "No" },
        { id: "source", label: "Source", value: instance.source_status },
      ],
    }];
  }
  const connector = projection.connector_definitions.find((item) => item.id === selectedID);
  if (connector) {
    return [{
      id: "connector",
      label: "Mate connector",
      badge: connector.provenance.kind,
      properties: [
        { id: "name", label: "Name", value: connector.name },
        { id: "part", label: "Part definition ID", value: connector.part_definition_id },
        { id: "origin", label: "Part-local origin", value: `${vector(connector.frame_part_local.origin_m)} m` },
        { id: "primary", label: "Primary axis", value: vector(connector.frame_part_local.primary_axis_xyz) },
        { id: "secondary", label: "Secondary axis", value: vector(connector.frame_part_local.secondary_axis_xyz) },
        { id: "feature", label: "Feature", value: connector.provenance.label ?? connector.provenance.stable_feature_id ?? "Manual" },
      ],
    }];
  }
  const mate = projection.mates.find((item) => item.id === selectedID);
  if (mate) {
    const dof = mate.dofs.length === 1 ? mate.dofs[0] : null;
    const solvedDOF = dof ? solution?.dof_values.find(({ dof_id }) => dof_id === dof.id) : undefined;
    return [{
      id: "mate",
      label: "Mate",
      badge: mate.solve_state,
      properties: [
        { id: "name", label: "Name", value: mate.name },
        { id: "type", label: "Type", value: mate.type_id },
        { id: "endpoint-a", label: "Endpoint A", value: mate.endpoint_a.instance_id },
        { id: "endpoint-b", label: "Endpoint B", value: mate.endpoint_b.instance_id },
        { id: "dof", label: "DOF", value: String(mate.dofs.length) },
        ...(dof ? [
          { id: "dof-name", label: "DOF name", value: dof.name },
          { id: "dof-state", label: "DOF state", value: dof.state },
          { id: "dof-value", label: dof.kind === "rotation" ? "Angle" : "Distance", value: dofDisplayValue(dof, solvedDOF) },
          { id: "dof-limits", label: "Limits", value: dofDisplayLimits(dof) },
        ] : []),
        { id: "suppressed", label: "Suppressed", value: mate.suppressed ? "Yes" : "No" },
      ],
    }];
  }
  const relation = projection.relations.find((item) => item.id === selectedID);
  if (relation) {
    const dofs = new Map(projection.mates.flatMap((mate) => mate.dofs.map((dof) => [dof.id, `${mate.name} · ${dof.name}`] as const)));
    return [{
      id: "relation",
      label: "Relation",
      badge: relation.kind,
      properties: [
        { id: "driver", label: "Driver DOF", value: dofs.get(relation.driver_dof_id) ?? relation.driver_dof_id },
        { id: "driven", label: "Driven DOF", value: dofs.get(relation.driven_dof_id) ?? relation.driven_dof_id },
        { id: "ratio", label: "Ratio", value: String(relation.ratio) },
        { id: "offset", label: "Offset", value: relation.offset_rad !== null ? `${displayNumber(relation.offset_rad * 180 / Math.PI)}°` : relation.offset_m !== null ? `${displayNumber(relation.offset_m)} m` : "0" },
      ],
    }];
  }
  return [{
    id: "assembly",
    label: "Assembly",
    badge: solution?.status ?? "not solved",
    properties: [
      { id: "revision", label: "Revision", value: projection.revision },
      { id: "instances", label: "Instances", value: String(projection.instances.length) },
      { id: "connectors", label: "Connectors", value: String(projection.connector_definitions.length) },
      { id: "mates", label: "Mates", value: String(projection.mates.length) },
      { id: "relations", label: "Relations", value: String(projection.relations.length) },
      { id: "remaining-dof", label: "Remaining free DOF", value: solution ? String(solution.remaining_free_dof_count) : "Not solved" },
    ],
  }];
}

export function buildCADAssemblyPresentation(
  projection: AssemblyProjectionV1,
  solution: AssemblySolutionProjection | null,
  bom: BOMProjectionV1 | null,
  selectedID: StableID | null = null,
): CADAssemblyPresentationProjection {
  const canMate = projection.capabilities.supported_mate_type_ids.length > 0;
  const endpoints = mateEndpointOptions(projection);
  const canConnectTwoInstances = new Set(endpoints.map(({ instanceID }) => instanceID)).size >= 2;
  const selectedMate = projection.mates.find(({ id }) => id === selectedID);
  const relationDOFOptions = projection.mates.flatMap((mate) => mate.suppressed ? [] : mate.dofs
    .filter(({ state }) => state === "free")
    .map((dof) => ({
      id: dof.id,
      label: `${mate.name} · ${dof.name}`,
      kind: dof.kind,
    })));
  return {
    revision: projection.revision,
    treeNodes: buildTree(projection),
    connectorItems: connectorItems(projection),
    mateItems: mateItems(projection),
    relationItems: relationItems(projection),
    problemItems: projection.issues.map(diagnosticItem),
    mateEndpointOptions: endpoints,
    selectedMateDOF: selectedMate?.dofs.length === 1 ? selectedMate.dofs[0] : null,
    relationDOFOptions,
    inspectorSections: inspector(projection, solution, selectedID),
    bomRows: bom?.rows ?? [],
    commandAvailability: [
      availability(projection, "insert-instance", projection.capabilities.can_edit_instances, "can_edit_instances", "Core does not expose instance editing."),
      availability(projection, "add-connector", projection.capabilities.can_edit_connectors, "can_edit_connectors", "Core does not expose connector editing."),
      availability(
        projection,
        "add-mate",
        canMate && canConnectTwoInstances,
        "supported_mate_type_ids",
        canMate ? "Add connectors to at least two active component instances." : "Core does not expose any mate types.",
      ),
      availability(projection, "add-relation", projection.capabilities.can_edit_relations, "can_edit_relations", "Core does not expose relation editing."),
      availability(projection, "solve-assembly", projection.capabilities.can_solve_tree, "can_solve_tree", "Core does not expose assembly solving."),
      availability(projection, "project-bom", projection.capabilities.can_project_bom, "can_project_bom", "Core does not expose BOM projection."),
      availability(projection, "save-workspace", projection.capabilities.can_save_workspace, "can_save_workspace", "Core does not expose workspace persistence."),
    ],
    summary: {
      instanceCount: projection.instances.length,
      connectorCount: projection.connector_definitions.length,
      mateCount: projection.mates.length,
      remainingFreeDOFCount: solution?.remaining_free_dof_count ?? null,
      solveStatus: solution?.status ?? "not_solved",
      bomMode: bom?.mode ?? null,
    },
  };
}
