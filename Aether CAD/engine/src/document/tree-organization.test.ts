import { describe, expect, it } from "vitest";
import {
  assignItems,
  buildFolderedTree,
  canNestFolder,
  createFolder,
  deleteFolder,
  emptyTreeOrganization,
  moveFolder,
  renameFolder,
  validateTreeOrganization,
  type TreeOrganization,
} from "./tree-organization";

type Node = { id: string; label: string; children?: readonly Node[] };
const item = (id: string): Node => ({ id, label: id });
const fold = (folder: { id: string; name: string }, children: readonly Node[]): Node => ({ id: `folder/${folder.id}`, label: folder.name, children });
const shape = (nodes: readonly Node[]): unknown => nodes.map((n) => (n.children ? { [n.id]: shape(n.children) } : n.id));

describe("tree organization", () => {
  it("groups members under a folder at its first member's position, keeps order", () => {
    let org = emptyTreeOrganization();
    org = createFolder(org, { id: "f1", name: "Base" }, ["b", "d"]);
    const nodes = buildFolderedTree([item("a"), item("b"), item("c"), item("d")], org, fold);
    expect(shape(nodes)).toEqual(["a", { "folder/f1": ["b", "d"] }, "c"]);
  });

  it("nests folders, renames, and dissolves a folder into its parent", () => {
    let org = emptyTreeOrganization();
    org = createFolder(org, { id: "outer", name: "Outer" }, ["a"]);
    org = createFolder(org, { id: "inner", name: "Inner", parentID: "outer" }, ["b"]);
    org = renameFolder(org, "inner", "Renamed");
    let nodes = buildFolderedTree([item("a"), item("b")], org, fold);
    expect(shape(nodes)).toEqual([{ "folder/outer": ["a", { "folder/inner": ["b"] }] }]);
    expect(org.folders.find((f) => f.id === "inner")?.name).toBe("Renamed");
    org = deleteFolder(org, "inner");
    nodes = buildFolderedTree([item("a"), item("b")], org, fold);
    expect(shape(nodes)).toEqual([{ "folder/outer": ["a", "b"] }]);
    expect(org.membership.b).toBe("outer");
  });

  it("rejects nesting cycles and unknown targets", () => {
    let org = emptyTreeOrganization();
    org = createFolder(org, { id: "x", name: "X" });
    org = createFolder(org, { id: "y", name: "Y", parentID: "x" });
    expect(canNestFolder(org, "x", "y")).toBe(false);
    expect(canNestFolder(org, "x", "x")).toBe(false);
    expect(() => moveFolder(org, "x", "y")).toThrow();
    expect(() => createFolder(org, { id: "x", name: "Duplicate" })).toThrow();
    expect(() => assignItems(org, ["a"], "missing")).toThrow();
    org = moveFolder(org, "y", null);
    expect(org.folders.find((f) => f.id === "y")?.parentID).toBeNull();
  });

  it("appends empty folders after ordered content and clears membership on un-assignment", () => {
    let org = emptyTreeOrganization();
    org = createFolder(org, { id: "used", name: "Used" }, ["a"]);
    org = createFolder(org, { id: "empty", name: "Empty" });
    let nodes = buildFolderedTree([item("a"), item("b")], org, fold);
    expect(shape(nodes)).toEqual([{ "folder/used": ["a"] }, "b", { "folder/empty": [] }]);
    org = assignItems(org, ["a"], null);
    nodes = buildFolderedTree([item("a"), item("b")], org, fold);
    expect(shape(nodes)).toEqual(["a", "b", { "folder/used": [] }, { "folder/empty": [] }]);
    expect(org.membership.a).toBeUndefined();
  });

  it("validates: unique ids, existing parents, no cycles, memberships to real folders", () => {
    expect(() => validateTreeOrganization(undefined)).not.toThrow();
    const ok: TreeOrganization = { folders: [{ id: "f", name: "F", parentID: null }], membership: { a: "f" } };
    expect(() => validateTreeOrganization(ok)).not.toThrow();
    expect(() => validateTreeOrganization({ folders: [{ id: "f", name: "F", parentID: "ghost" }], membership: {} })).toThrow();
    expect(() => validateTreeOrganization({ folders: [{ id: "f", name: "F", parentID: null }], membership: { a: "ghost" } })).toThrow();
    expect(() => validateTreeOrganization({ folders: [{ id: "a", name: "A", parentID: "b" }, { id: "b", name: "B", parentID: "a" }], membership: {} })).toThrow();
    expect(() => validateTreeOrganization({ folders: [{ id: "f", name: "F", parentID: null }, { id: "f", name: "Dup", parentID: null }], membership: {} })).toThrow();
  });
});

import { parsePartDocument, serializePartDocument } from "./part-serialization";
import { createRectanglePartDocument } from "./part-document";

it("round-trips document organization through save and reopen; rejects corrupt organization", () => {
  const document = createRectanglePartDocument("Bracket", { widthMillimeters: 10, heightMillimeters: 10, depthMillimeters: 5 });
  const sketchID = document.features[0].id;
  let organization = emptyTreeOrganization();
  organization = createFolder(organization, { id: "grp", name: "Base group" }, [sketchID]);
  const reopened = parsePartDocument(serializePartDocument({ ...document, organization }));
  expect(reopened.organization).toEqual(organization);
  expect(() =>
    parsePartDocument(
      serializePartDocument({ ...document, organization }).replace('"grp"', '"ghost"').replace('"ghost"', '"grp"'),
    ),
  ).not.toThrow();
  const corrupt = JSON.parse(serializePartDocument({ ...document, organization }));
  corrupt.organization.membership[sketchID] = "missing-folder";
  expect(() => parsePartDocument(JSON.stringify(corrupt))).toThrow(/unknown folder/i);
});
