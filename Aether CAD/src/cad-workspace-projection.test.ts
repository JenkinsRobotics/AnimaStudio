import { describe, expect, it } from "vitest";
import {
  createRectanglePartDocument,
  type AppliedMate,
  type ConnectorCandidate,
  type MateConnector,
} from "./aether-core";
import { buildCADWorkspaceProjection } from "./cad-workspace-projection";

const visibility = { origin: false, "top-plane": true, "front-plane": false, "right-plane": false } as const;
const candidateA: ConnectorCandidate = {
  id: "candidate-1",
  faceId: 1,
  kind: "face-center",
  label: "Planar face",
  origin: [0, 0, 0],
  xAxis: [1, 0, 0],
  yAxis: [0, 1, 0],
  zAxis: [0, 0, 1],
};
const candidateB: ConnectorCandidate = {
  ...candidateA,
  id: "candidate-2",
  faceId: 2,
  origin: [10, 0, 0],
};
const connectors: MateConnector[] = [
  { id: "connector-1", name: "Connector 1", partId: "import:1", partName: "Bolt", candidate: candidateA },
  { id: "connector-2", name: "Connector 2", partId: "import:2", partName: "Bracket", candidate: candidateB },
];
const mates: AppliedMate[] = [{
  id: "mate-1",
  movingPartId: "import:1",
  targetPartId: "import:2",
  movingConnectorId: "connector-1",
  targetConnectorId: "connector-2",
  movingConnector: candidateA,
  targetConnector: candidateB,
}];

describe("buildCADWorkspaceProjection", () => {
  it("projects reference, authored, imported, selection, and history data", () => {
    const document = createRectanglePartDocument("Bracket", { widthMillimeters: 60, heightMillimeters: 40, depthMillimeters: 20 }, undefined, { plane: "XY", fullyDefinedSketch: false });
    const projection = buildCADWorkspaceProjection(
      document,
      [{ id: "import:1", name: "Bolt", sourceDocumentId: "step:1", sourceName: "hardware.step", constrained: false, visible: true, selected: true }],
      new Set([document.documentId, "step:1"]),
      visibility,
      "XY",
      connectors,
      mates,
      "connector-1",
      { faceCount: 6, candidateCount: 54 },
      new Set([`${document.documentId}:body-1`]),
    );
    expect(projection.itemNodes.map((node) => node.label)).toEqual(["Reference Geometry", "Bracket", "Bodies (1)", "hardware.step"]);
    expect(projection.selectedItemIDs.has("reference/top-plane")).toBe(true);
    expect(projection.selectedItemIDs.has("part/import:1")).toBe(true);
    expect([...projection.selectedItemIDs].some((id) => id.startsWith("feature/body/"))).toBe(true);
    expect(projection.expandedItemIDs.has(`document/${document.documentId}`)).toBe(true);
    expect(projection.historyItems.map((item) => item.group)).toContain("Assembly");
    expect(projection.connectorItems[0].label).toBe("Connector 1");
    expect(projection.selectedConnectorIDs.has("connector/connector-1")).toBe(true);
    expect(projection.mateItems[0]).toMatchObject({
      label: "Fastened Mate 1",
      description: "Connector 1 → Connector 2",
    });
    expect(projection.inspectorSections.find((section) => section.id === "topology")?.properties).toContainEqual({ id: "faces", label: "Faces", value: "6" });
    expect(projection.problemItems[0]).toMatchObject({ label: "Sketch 1 is under-defined", badge: "Warning" });
  });

  it("does not invent authored or history rows for an empty workspace", () => {
    const projection = buildCADWorkspaceProjection(null, [], new Set(), visibility, null, [], [], null, { faceCount: 0, candidateCount: 0 });
    expect(projection.itemNodes).toHaveLength(1);
    expect(projection.historyItems).toEqual([]);
    expect(projection.partCount).toBe(0);
    expect(projection.selectedItemIDs.size).toBe(0);
    expect(projection.problemItems).toEqual([]);
    expect(projection.inspectorSections).toEqual([]);
  });

  it("projects 1,200 imported Parts into grouped roots for virtualized Tree consumption", () => {
    const importedParts = Array.from({ length: 1_200 }, (_, index) => {
      const documentIndex = Math.floor(index / 100);
      return {
        id: `part:${index}`,
        name: `Part ${index + 1}`,
        sourceDocumentId: `step:${documentIndex}`,
        sourceName: `assembly-${documentIndex + 1}.step`,
        constrained: index % 3 === 0,
        visible: index % 7 !== 0,
        selected: index === 1_199,
      };
    });
    const projection = buildCADWorkspaceProjection(
      null,
      importedParts,
      new Set(importedParts.map((part) => part.sourceDocumentId)),
      visibility,
      null,
      [],
      [],
      null,
      { faceCount: 7_200, candidateCount: 64_800 },
    );
    expect(projection.partCount).toBe(1_200);
    expect(projection.itemNodes).toHaveLength(13);
    expect(projection.itemNodes.slice(1).reduce((sum, node) => sum + (node.children?.length ?? 0), 0)).toBe(1_200);
    expect(projection.historyItems).toHaveLength(12);
    expect(projection.selectedItemIDs.has("part/part:1199")).toBe(true);
  });
});
