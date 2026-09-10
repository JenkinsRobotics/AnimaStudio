export interface AssemblyPartRow {
  id: string;
  name: string;
  sourceDocumentId: string;
  sourceName: string;
  constrained: boolean;
  visible: boolean;
  selected: boolean;
}

export interface AssemblyDocumentNode {
  id: string;
  name: string;
  parts: AssemblyPartRow[];
}

/** Groups independently movable Parts beneath their imported STEP document. */
export function buildAssemblyDocumentTree(
  parts: AssemblyPartRow[],
): AssemblyDocumentNode[] {
  const documents = new Map<string, AssemblyDocumentNode>();
  parts.forEach((part) => {
    const document = documents.get(part.sourceDocumentId) ?? {
      id: part.sourceDocumentId,
      name: part.sourceName,
      parts: [],
    };
    document.parts.push(part);
    documents.set(part.sourceDocumentId, document);
  });
  return [...documents.values()];
}
