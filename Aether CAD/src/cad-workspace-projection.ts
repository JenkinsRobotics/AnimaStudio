import { createElement } from "react";
import { ToolIcon, type ToolIconName } from "@aether/ui";
const treeIcon=(name:ToolIconName)=>createElement(ToolIcon,{name});
import {rollbackPosition,availableBodies} from "@aether/core/document";
import type { ListBoxItem, TreeNode } from "@aether/ui";
import type {
  AppliedMate,
  MateConnector,
  PartDocument,
  SketchPlane,
} from "./aether-core";
import { rectanglePartParameters, sketchDefinitionState } from "./aether-core";
import type { CADInspectorSection } from "./cad-workspace-store";
import { buildAssemblyDocumentTree, type AssemblyPartRow } from "./assembly-tree";
import { buildPartFeatureTree } from "./part-feature-tree";
import {
  referenceGeometry,
  sketchPlaneForReference,
  type ReferenceGeometryId,
} from "./reference-geometry";

export interface CADWorkspaceProjection {
  itemNodes: readonly TreeNode[];
  selectedItemIDs: ReadonlySet<string>;
  expandedItemIDs: ReadonlySet<string>;
  historyItems: readonly ListBoxItem[];
  connectorItems: readonly ListBoxItem[];
  mateItems: readonly ListBoxItem[];
  problemItems: readonly ListBoxItem[];
  inspectorSections: readonly CADInspectorSection[];
  selectedConnectorIDs: ReadonlySet<string>;
  partCount: number;
}

export function buildCADWorkspaceProjection(
  partDocument: PartDocument | null,
  importedParts: readonly AssemblyPartRow[],
  expandedDocuments: ReadonlySet<string>,
  referenceVisibility: Readonly<Record<ReferenceGeometryId, boolean>>,
  selectedPlane: SketchPlane | null,
  connectors: readonly MateConnector[],
  mates: readonly AppliedMate[],
  selectedConnectorID: string | null,
  topology: { faceCount: number; candidateCount: number },
  selectedPartIDs: ReadonlySet<string> = new Set(),
  selectedFeatureID: string | null = null,
): CADWorkspaceProjection {
  const selected = new Set<string>();
  const expanded = new Set<string>(["reference-folder"]);
  const references: TreeNode = {
    id: "reference-folder",
    label: "Reference Geometry",
    icon: treeIcon("plane"),
    badge: "4",
    children: referenceGeometry.map((item) => {
      const id = `reference/${item.id}`;
      if (
        selectedPlane !== null &&
        sketchPlaneForReference(item.id) === selectedPlane
      ) selected.add(id);
      return {
        id,
        label: item.label,
        icon: treeIcon(item.id === "origin" ? "point" : "plane"),
        badge: referenceVisibility[item.id] ? "Visible" : undefined,
        dimmed: !referenceVisibility[item.id],
        actions: [
          {
            id: "toggle-visibility",
            label: `${referenceVisibility[item.id] ? "Hide" : "Show"} ${item.label}`,
            icon: referenceVisibility[item.id] ? "◉" : "○",
          },
        ],
      };
    }),
  };

  const authored: TreeNode[] = [];
  if (partDocument) {
    const root = buildPartFeatureTree(partDocument);
    const rootID = `document/${partDocument.documentId}`;
    if (expandedDocuments.has(partDocument.documentId)) expanded.add(rootID);
    authored.push({
      id: rootID,
      label: root.name,
      icon: treeIcon("plane"),
      badge: String(root.children.length),
      children: root.children.filter(f=>f.kind!=="body").map((feature) => {
        const id = `feature/${feature.kind}/${feature.id}`;
        if(feature.id===selectedFeatureID)selected.add(id);
        if (
          feature.kind === "body" &&
          selectedPartIDs.has(`${partDocument.documentId}:body-1`)
        ) selected.add(id);
        return {
          id,
          label: feature.name,
          badge: feature.detail,
          dimmed: feature.detail === "Suppressed" || feature.detail === "Rolled back",
          actions:[{id:"edit-feature",label:`Edit ${feature.name}`,icon:"✎"},{id:"suppress-feature",label:`${feature.detail === "Suppressed"?"Unsuppress":"Suppress"} ${feature.name}`,icon:feature.detail === "Suppressed"?"▶":"Ⅱ"},{id:"rollback-before",label:`Roll back before ${feature.name}`,icon:"↥"}],
          icon: treeIcon(feature.kind === "sketch" || feature.kind === "profile" ? "sketch" : feature.kind === "plane" ? "plane" : feature.kind === "extrude" ? "extrude" : feature.kind === "revolve" ? "revolve" : feature.kind === "mirror" ? "mirror" : feature.kind === "fillet" ? "fillet" : feature.kind === "chamfer" ? "chamfer" : "part"),
        };
      }),
    } as TreeNode);
    const children=[...(authored[0].children??[])];children.splice(rollbackPosition(partDocument),0,{id:"rollback-bar",label:`Rollback · ${rollbackPosition(partDocument)} / ${partDocument.features.length}`,icon:"━━━━",actions:[{id:"rollback-start",label:"Roll back to start",icon:"⇡"},{id:"rollback-end",label:"Roll forward to end",icon:"⇣"}]});authored[0]={...authored[0],children};
    const bodies=availableBodies(partDocument);for(const body of bodies)if(selectedPartIDs.has(body.id))selected.add(`feature/body/${body.id}`);const bodiesID=`bodies/${partDocument.documentId}`;expanded.add(bodiesID);
    authored.push({id:bodiesID,label:`Bodies (${bodies.length})`,icon:treeIcon("part"),children:bodies.map(body=>({id:`feature/body/${body.id}`,label:body.name,dimmed:!body.visible,actions:[{id:"body-visibility",label:`${body.visible?"Hide":"Show"} ${body.name}`,icon:body.visible?"◉":"○"},{id:"body-rename",label:`Rename ${body.name}`,icon:"✎"}]}))});
  }

  const imported = buildAssemblyDocumentTree([...importedParts]).map<TreeNode>((document) => {
    const rootID = `document/${document.id}`;
    if (expandedDocuments.has(document.id)) expanded.add(rootID);
    return {
      id: rootID,
      label: document.name,
      icon: treeIcon("plane"),
      badge: String(document.parts.length),
      children: document.parts.map((part) => {
        const id = `part/${part.id}`;
        if (part.selected) selected.add(id);
        return {
          id,
          label: part.name,
          icon: "◇",
          badge: part.constrained ? "Fastened" : "Free",
          dimmed: !part.visible,
          actions: [
            {
              id: "toggle-visibility",
              label: `${part.visible ? "Hide" : "Show"} ${part.name}`,
              icon: part.visible ? "◉" : "○",
            },
          ],
        };
      }),
    };
  });

  const featureHistory: ListBoxItem[] = (partDocument?.features ?? []).map((feature) => ({
    id: `history/feature/${feature.id}`,
    label: feature.name,
    description: feature.suppressed?"Suppressed":partDocument!.features.indexOf(feature)>=rollbackPosition(partDocument!)?"Rolled back":["sketch","profile"].includes(feature.type)?"Sketch feature":"Solid feature",
    icon: treeIcon(feature.type === "sketch" || feature.type === "profile" ? "sketch" : feature.type === "plane" ? "plane" : "extrude"),
    group: "Part history",
  }));
  const importedHistory: ListBoxItem[] = [
    ...new Map(importedParts.map((part) => [part.sourceDocumentId, part.sourceName] as const)),
  ].map(([id, name]) => ({
    id: `history/document/${id}`,
    label: `Import ${name}`,
    icon: "⬡",
    group: "Imports",
  }));
  const mateHistory: ListBoxItem[] = Array.from({ length: mates.length }, (_, index) => ({
    id: `history/mate/${index}`,
    label: `Fastened Mate ${index + 1}`,
    icon: "⛓",
    group: "Assembly",
  }));

  const connectorItems: ListBoxItem[] = connectors.map((connector) => ({
    id: `connector/${connector.id}`,
    label: connector.name,
    description: `${connector.partName} · ${connector.candidate.label}`,
    icon: "⌖",
    actions: [
      { id: "pick", label: "Use in mate", icon: "Pick" },
      { id: "delete", label: "Delete connector", icon: "×" },
    ],
  }));
  const mateItems: ListBoxItem[] = mates.map((mate, index) => {
    const moving = connectors.find((item) => item.id === mate.movingConnectorId);
    const target = connectors.find((item) => item.id === mate.targetConnectorId);
    return {
      id: `mate/${index}`,
      label: `Fastened Mate ${index + 1}`,
      description: `${moving?.name ?? "Connector"} → ${target?.name ?? "Connector"}`,
      icon: "⛓",
    };
  });
  const sketch = partDocument?.features.find((feature) => feature.type === "sketch");
  const definition = sketch ? sketchDefinitionState(sketch) : null;
  const parameters = partDocument && sketch ? rectanglePartParameters(partDocument) : null;
  const problemItems: ListBoxItem[] = definition && !definition.fullyDefined
    ? [{
        id: "problem/sketch-under-defined",
        label: `${sketch?.name ?? "Sketch"} is under-defined`,
        description: `${definition.remainingDegreesOfFreedom} remaining degrees of freedom`,
        icon: "!",
        badge: "Warning",
        group: "Definition",
      }]
    : [];
  const inspectorSections: CADInspectorSection[] = partDocument && parameters
    ? [
        {
          id: "document",
          label: "Part document",
          badge: ".acpart",
          properties: [
            { id: "name", label: "Name", value: partDocument.name },
            { id: "units", label: "Units", value: "Millimeters" },
            { id: "features", label: "Features", value: String(partDocument.features.length) },
          ],
        },
        {
          id: "parameters",
          label: "Feature parameters",
          properties: [
            { id: "width", label: "Width", value: `${parameters.widthMillimeters} mm` },
            { id: "height", label: "Height", value: `${parameters.heightMillimeters} mm` },
            { id: "depth", label: "Extrude", value: `${parameters.depthMillimeters} mm` },
          ],
        },
        {
          id: "definition",
          label: "Sketch definition",
          badge: definition?.label,
          properties: [
            { id: "plane", label: "Plane", value: sketch?.plane ?? "—" },
            { id: "dof", label: "Remaining DOF", value: String(definition?.remainingDegreesOfFreedom ?? 0) },
          ],
        },
        {
          id: "topology",
          label: "Exact topology",
          badge: "OCCT",
          properties: [
            { id: "faces", label: "Faces", value: String(topology.faceCount) },
            { id: "snaps", label: "Exact snaps", value: String(topology.candidateCount) },
            { id: "connectors", label: "Connectors", value: String(connectors.length) },
            { id: "mates", label: "Mates", value: String(mates.length) },
          ],
        },
      ]
    : partDocument ? [{id:"document",label:"Part document",badge:".acpart",properties:[{id:"name",label:"Name",value:partDocument.name},{id:"features",label:"Features",value:String(partDocument.features.length)},{id:"units",label:"Units",value:"Millimeters"}]}] : [];

  return {
    itemNodes: [references, ...authored, ...imported],
    selectedItemIDs: selected,
    expandedItemIDs: expanded,
    historyItems: [...featureHistory, ...importedHistory, ...mateHistory],
    connectorItems,
    mateItems,
    problemItems,
    inspectorSections,
    selectedConnectorIDs: new Set(
      selectedConnectorID ? [`connector/${selectedConnectorID}`] : [],
    ),
    partCount: (partDocument ? availableBodies(partDocument).length : 0) + importedParts.length,
  };
}
