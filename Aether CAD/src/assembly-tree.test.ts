import { describe, expect, it } from "vitest";
import { buildAssemblyDocumentTree, type AssemblyPartRow } from "./assembly-tree";

function part(id: string, sourceName: string): AssemblyPartRow {
  return {
    id,
    name: id,
    sourceDocumentId: `document-${sourceName}`,
    sourceName,
    constrained: false,
    visible: true,
    selected: false,
  };
}

describe("buildAssemblyDocumentTree", () => {
  it("groups imported Parts by source STEP document", () => {
    const tree = buildAssemblyDocumentTree([
      part("body-a", "assembly.step"),
      part("body-b", "assembly.step"),
      part("shaft", "shaft.step"),
    ]);
    expect(tree.map((document) => document.name)).toEqual([
      "assembly.step",
      "shaft.step",
    ]);
    expect(tree[0].parts.map((row) => row.id)).toEqual(["body-a", "body-b"]);
  });

  it("keeps two imports with the same filename as separate documents", () => {
    const first = part("first", "part.step");
    const second = {
      ...part("second", "part.step"),
      sourceDocumentId: "second-import",
    };
    expect(buildAssemblyDocumentTree([first, second])).toHaveLength(2);
  });
});
