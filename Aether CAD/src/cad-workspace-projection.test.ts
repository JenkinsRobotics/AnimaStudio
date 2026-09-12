import { createFolder, createEmptyPartDocument, emptyTreeOrganization } from "@aether/core/document";
import { describe, expect, it } from "vitest";
import {
  createRectanglePartDocument,
  type AppliedMate,
  type ConnectorCandidate,
  type MateConnector,
} from "./aether-core";
import { buildCADWorkspaceProjection } from "./cad-workspace-projection";

const visibility = { origin: false, axes: false, "top-plane": true, "front-plane": false, "right-plane": false } as const;
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
    expect(projection.itemNodes.map((node) => node.label)).toEqual(["Reference Geometry", "Sketch 1", "Extrude 1", "Rollback · 2 / 2", "hardware.step"]);
    expect(projection.selectedItemIDs.has("reference/top-plane")).toBe(true);
    expect(projection.selectedItemIDs.has("part/import:1")).toBe(true);
    expect([...projection.selectedItemIDs].some((id) => id.startsWith("feature/body/"))).toBe(true);
    const rollbackRow = projection.itemNodes.find((node) => node.id === "rollback-bar");
    expect(rollbackRow?.variant).toBe("divider");
    expect(rollbackRow?.actions).toBeUndefined();
    const sketchRow = projection.itemNodes.find((node) => node.id.startsWith("feature/sketch/"));
    expect(sketchRow?.tone).toBe("error");
    const hiddenPlane = projection.itemNodes[0].children?.find((node) => node.id === "reference/front-plane");
    expect(hiddenPlane?.badge).toBeUndefined();
    expect(hiddenPlane?.actions?.[0]).toMatchObject({ id: "toggle-visibility", pinned: true });
    const visiblePlane = projection.itemNodes[0].children?.find((node) => node.id === "reference/top-plane");
    expect(visiblePlane?.actions?.[0].pinned).toBe(false);
    expect(projection.historyItems.map((item) => item.group)).toContain("Assembly");
    expect(projection.rollbackIndex).toBe(2);
    expect(projection.connectorItems[0].label).toBe("Connector 1");
    expect(projection.selectedConnectorIDs.has("connector/connector-1")).toBe(true);
    expect(projection.mateItems[0]).toMatchObject({
      label: "Fastened Mate 1",
      description: "Connector 1 → Connector 2",
    });
    expect(projection.inspectorSections.find((section) => section.id === "topology")?.properties).toContainEqual({ id: "faces", label: "Faces", value: "6" });
    expect(projection.problemItems[0]).toMatchObject({ label: "Sketch 1 is under-defined", badge: "Warning" });
  });

  it("nests foldered features, keeps the rollback line top-level, exposes folder actions", () => {
    const document = createRectanglePartDocument("Bracket", { widthMillimeters: 60, heightMillimeters: 40, depthMillimeters: 20 });
    const organization = createFolder(emptyTreeOrganization(), { id: "grp", name: "Base group" }, [document.features[0].id]);
    const args = [[], new Set([document.documentId]), visibility, null, [], [], null, { faceCount: 0, candidateCount: 0 }] as const;
    const projection = buildCADWorkspaceProjection({ ...document, organization }, ...args);
    expect(projection.itemNodes.map((node) => node.label)).toEqual(["Reference Geometry", "Base group", "Extrude 1", "Rollback · 2 / 2"]);
    const folder = projection.itemNodes.find((node) => node.id === "folder/grp");
    expect(folder?.children?.map((child) => child.label)).toEqual(["Sketch 1"]);
    expect(folder?.actions?.map((action) => action.id)).toEqual(["folder-rename", "folder-delete"]);
    expect(projection.expandedItemIDs.has("folder/grp")).toBe(true);
    const collapsed = buildCADWorkspaceProjection({ ...document, organization }, ...args, new Set(), new Set(), new Set(["folder/grp"]));
    expect(collapsed.expandedItemIDs.has("folder/grp")).toBe(false);
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

it("collapses Reference Geometry and Bodies, and divides Bodies from history", () => {
  const document = createRectanglePartDocument("Bracket", { widthMillimeters: 60, heightMillimeters: 40, depthMillimeters: 20 }, undefined, { plane: "XY", fullyDefinedSketch: false });
  const open = buildCADWorkspaceProjection(
    document, [], new Set(), visibility, null, [], [], null,
    { faceCount: 0, candidateCount: 0 }, new Set(), new Set(), new Set(),
  );
  expect(open.expandedItemIDs.has("reference-folder")).toBe(true);
  expect([...open.expandedItemIDs].some((id) => id.startsWith("bodies/"))).toBe(true);
  expect(open.bodyNodes.some((node) => node.id.startsWith("bodies/"))).toBe(true);
  expect(open.itemNodes.some((node) => node.id.startsWith("bodies/"))).toBe(false);

  const bodiesID = open.bodyNodes.find((node) => node.id.startsWith("bodies/"))!.id;
  const collapsed = buildCADWorkspaceProjection(
    document, [], new Set(), visibility, null, [], [], null,
    { faceCount: 0, candidateCount: 0 }, new Set(), new Set(),
    new Set(["reference-folder", bodiesID]),
  );
  expect(collapsed.expandedItemIDs.has("reference-folder")).toBe(false);
  expect(collapsed.expandedItemIDs.has(bodiesID)).toBe(false);
});

it("marks every selected feature row, not just one", () => {
  const document = createRectanglePartDocument("Bracket", { widthMillimeters: 60, heightMillimeters: 40, depthMillimeters: 20 });
  const projection = buildCADWorkspaceProjection(
    document, [], new Set(), visibility, null, [], [], null,
    { faceCount: 0, candidateCount: 0 }, new Set(),
    new Set(document.features.map((feature) => feature.id)),
  );
  const featureRows = projection.itemNodes.filter((node) => node.id.startsWith("feature/"));
  expect(featureRows).toHaveLength(2);
  expect(featureRows.every((node) => projection.selectedItemIDs.has(node.id))).toBe(true);
});

// Onshape badges a sketch in the tree while it still has free degrees of
// freedom. The badge is an overlay on the shared sketch icon, so the base glyph
// stays single-sourced.
describe("under-defined sketch badge", () => {
  const partWith = (profile: unknown) => ({
    ...createEmptyPartDocument("Part"),
    features: [
      {
        id: "s1", type: "profile", name: "Sketch 1", plane: "XY",
        offsetMillimeters: 0, suppressed: false, profile,
      },
    ],
  });
  const sketchRow = (document: unknown) =>
    buildCADWorkspaceProjection(
      document as never, [], new Set(), visibility, null, [], [], null, { faceCount: 0, candidateCount: 0 }, new Set(),
    ).historyItems.find((item) => item.id === "history/feature/s1");

  const iconOf = (row: { icon?: unknown } | undefined) => row?.icon as { props?: { className?: string } } | undefined;

  it("badges a sketch whose geometry is not fully constrained", () => {
    const free = partWith({
      type: "drawing",
      contours: [
        { type: "path", start: [0, 0], segments: [{ type: "line", end: [10, 3] }] },
      ],
      constraints: [],
    });
    expect(iconOf(sketchRow(free))?.props?.className).toContain("under-defined");
  });

  it("leaves legacy circle profiles unbadged rather than guessing", () => {
    const circle = partWith({ type: "circle", radiusMillimeters: 5, centerMillimeters: [0, 0] });
    expect(iconOf(sketchRow(circle))?.props?.className ?? "").not.toContain("under-defined");
  });
});
